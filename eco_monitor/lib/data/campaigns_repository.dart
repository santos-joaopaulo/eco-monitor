import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/campaign.dart";
import "collect_points_repository.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";

// Constants ---------------------------------------------------------------- //

/// Bundled fallback dataset of campaigns, available without network.
const String kCampaignsAsset = "assets/data/campaigns.json";

/// Firestore collection name for collection campaigns.
const String kCampaignsCollection = "campaigns";

const String _cacheJsonKey = "campaigns_json";
const String _cacheLastUpdatedKey = "campaigns_last_updated";

/// Maximum age before local campaign data is considered out of date.
const Duration kCampaignsMaxAge = Duration(days: 1);

// Types ------------------------------------------------------------------- //

/// Dataset returned by a remote campaign refresh, with its server timestamp.
class CampaignsRemoteSnapshot {
  const CampaignsRemoteSnapshot({
    required this.campaigns,
    required this.updatedAt,
  });

  final List<Campaign> campaigns;
  final DateTime updatedAt;
}

/// Hook used by [CampaignsRepository.refresh] to fetch remote campaigns.
typedef CampaignsFetcher = Future<CampaignsRemoteSnapshot> Function();

// Methods ----------------------------------------------------------------- //

/// Creates a [CampaignsFetcher] backed by the Firestore `campaigns` collection.
CampaignsFetcher createFirestoreCampaignsFetcher({
  FirebaseFirestore? firestore,
}) {
  return () async {
    if (firestore == null && !isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }

    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final QuerySnapshot<Map<String, dynamic>> snapshot = await db
        .collection(kCampaignsCollection)
        .get();

    DateTime? mostRecent = await readCollectionMetadataUpdatedAt(
      db,
      kCampaignsCollection,
    );

    final List<Campaign> campaigns = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> raw = doc.data();
      final DateTime? docUpdatedAt = extractFirestoreTimestamp(
        raw["updatedAt"],
      );
      if (docUpdatedAt != null &&
          (mostRecent == null || docUpdatedAt.isAfter(mostRecent!))) {
        mostRecent = docUpdatedAt;
      }

      final Map<String, dynamic> normalized = normalizeFirestoreData(
        raw,
        documentId: doc.id,
      );
      return Campaign.fromJson(normalized);
    }).toList();

    return CampaignsRemoteSnapshot(
      campaigns: campaigns,
      updatedAt:
          mostRecent ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  };
}

// Classes ----------------------------------------------------------------- //

/// Source of collection campaigns shown to users (RF08, RF09, RNF11).
///
/// Follows the offline-first pattern: [loadOffline] prefers the downloaded
/// [SharedPreferences] cache and falls back to the bundled [kCampaignsAsset];
/// [refresh] fetches fresh data from [fetcher] and updates the cache.
class CampaignsRepository {
  CampaignsRepository({
    AssetBundle? assetBundle,
    this.fetcher,
    Future<SharedPreferences> Function()? preferencesFactory,
    DateTime Function()? clock,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now;

  final AssetBundle _assetBundle;
  final CampaignsFetcher? fetcher;
  final Future<SharedPreferences> Function() _preferencesFactory;
  final DateTime Function() _clock;

  DateTime? _lastUpdated;
  DataSourceOrigin? _sourceOrigin;

  /// Timestamp of the dataset currently loaded, or null before the first load.
  DateTime? get lastUpdated => _lastUpdated;

  /// Where the most recently loaded dataset came from.
  DataSourceOrigin? get sourceOrigin => _sourceOrigin;

  bool get hasRemoteSource => fetcher != null;

  bool get isStale {
    final DateTime? lastUpdated = _lastUpdated;
    if (lastUpdated == null) {
      return true;
    }

    return _clock().difference(lastUpdated) > kCampaignsMaxAge;
  }

  // Methods --------------------------------------------------------------- //

  /// Loads campaigns without network, preferring the downloaded cache and
  /// falling back to the bundled asset when no cache exists.
  Future<List<Campaign>> loadOffline() async {
    final SharedPreferences preferences = await _preferencesFactory();
    final String? cachedJson = preferences.getString(_cacheJsonKey);
    final int? cachedTimestamp = preferences.getInt(_cacheLastUpdatedKey);

    if (cachedJson != null) {
      final _ParsedCampaigns cached = _parseCampaignsJson(cachedJson);
      if (cached.campaigns.isNotEmpty) {
        _lastUpdated = cachedTimestamp == null
            ? cached.updatedAt
            : DateTime.fromMillisecondsSinceEpoch(cachedTimestamp, isUtc: true);
        _sourceOrigin = DataSourceOrigin.localCache;
        return cached.campaigns;
      }
    }

    try {
      final String assetJson = await _assetBundle.loadString(kCampaignsAsset);
      final _ParsedCampaigns local = _parseCampaignsJson(assetJson);
      _lastUpdated = local.updatedAt;
      _sourceOrigin = DataSourceOrigin.bundledAsset;
      return local.campaigns;
    } catch (_) {
      return const <Campaign>[];
    }
  }

  /// Fetches campaigns from [fetcher] and updates the local cache.
  ///
  /// Without a [fetcher] or on network errors, falls back to [loadOffline].
  Future<List<Campaign>> refresh() async {
    final CampaignsFetcher? fetcher = this.fetcher;
    if (fetcher == null) {
      return loadOffline();
    }

    try {
      final CampaignsRemoteSnapshot remote = await fetcher();
      final List<Campaign> sorted = _sorted(remote.campaigns);
      final DateTime updatedAt = remote.updatedAt.toUtc();

      await _writeCache(sorted, updatedAt);
      _lastUpdated = updatedAt;
      _sourceOrigin = DataSourceOrigin.remoteServer;

      return sorted;
    } catch (_) {
      return loadOffline();
    }
  }

  /// Removes the downloaded cache, keeping the bundled dataset available.
  Future<void> clearCache() async {
    final SharedPreferences preferences = await _preferencesFactory();
    await preferences.remove(_cacheJsonKey);
    await preferences.remove(_cacheLastUpdatedKey);
  }

  Future<void> _writeCache(List<Campaign> campaigns, DateTime updatedAt) async {
    final SharedPreferences preferences = await _preferencesFactory();

    await preferences.setString(
      _cacheJsonKey,
      jsonEncode(<String, dynamic>{
        "updatedAt": updatedAt.toIso8601String(),
        "campaigns": campaigns
            .map((Campaign campaign) => campaign.toJson())
            .toList(),
      }),
    );
    await preferences.setInt(
      _cacheLastUpdatedKey,
      updatedAt.millisecondsSinceEpoch,
    );
  }
}

// Classes ----------------------------------------------------------------- //

class _ParsedCampaigns {
  const _ParsedCampaigns({required this.campaigns, required this.updatedAt});

  final List<Campaign> campaigns;
  final DateTime? updatedAt;
}

// Methods ----------------------------------------------------------------- //

_ParsedCampaigns _parseCampaignsJson(String source) {
  final Object? decoded = jsonDecode(source);

  final List<dynamic> rawCampaigns;
  String? rawUpdatedAt;

  if (decoded is Map<String, dynamic>) {
    final Object? campaigns = decoded["campaigns"];
    rawCampaigns = campaigns is List<dynamic> ? campaigns : const <dynamic>[];
    rawUpdatedAt = decoded["updatedAt"] is String
        ? decoded["updatedAt"] as String
        : null;
  } else if (decoded is List<dynamic>) {
    rawCampaigns = decoded;
  } else {
    rawCampaigns = const <dynamic>[];
  }

  final List<Campaign> campaigns = _sorted(
    rawCampaigns
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> json) =>
              Campaign.fromJson(json.cast<String, dynamic>()),
        )
        .toList(),
  );

  return _ParsedCampaigns(
    campaigns: campaigns,
    updatedAt: rawUpdatedAt == null ? null : DateTime.tryParse(rawUpdatedAt),
  );
}

int _statusRank(CampaignStatus status) {
  return switch (status) {
    CampaignStatus.active => 0,
    CampaignStatus.upcoming => 1,
    CampaignStatus.finished => 2,
  };
}

List<Campaign> _sorted(List<Campaign> campaigns) {
  return List<Campaign>.of(campaigns)..sort((Campaign first, Campaign second) {
    final int statusOrder = _statusRank(first.status)
        .compareTo(_statusRank(second.status));
    if (statusOrder != 0) {
      return statusOrder;
    }

    final int dateOrder = first.startDate.compareTo(second.startDate);
    if (dateOrder != 0) {
      return dateOrder;
    }

    return first.title.toLowerCase().compareTo(second.title.toLowerCase());
  });
}
