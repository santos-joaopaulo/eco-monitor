import "dart:convert";

import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/collection_point.dart";

// Constants ---------------------------------------------------------------- //

/// Asset shipped with the app, available without network.
const String kCollectPointsAsset = "assets/data/collect_points.json";

const String _cacheJsonKey = "collect_points_json";
const String _cacheLastUpdatedKey = "collect_points_last_updated";

/// Maximum age before local data is considered out of date.
const Duration kCollectPointsMaxAge = Duration(days: 7);

// Types ------------------------------------------------------------------- //

/// Dataset returned by a remote refresh, with the timestamp from the source.
///
/// The timestamp must come from the server (for Firebase, a Firestore
/// `Timestamp`) so the UI never presents stale data as fresh (RNF17).
class CollectPointsRemoteSnapshot {
  const CollectPointsRemoteSnapshot({
    required this.points,
    required this.updatedAt,
  });

  final List<CollectionPoint> points;
  final DateTime updatedAt;
}

/// Hook used by [CollectPointsRepository.refresh] to fetch a newer dataset.
///
/// There is no backend yet, so production keeps it null and always falls back
/// to the local data instead of faking an update. The future Firebase data
/// source will implement this contract.
typedef CollectPointsFetcher = Future<CollectPointsRemoteSnapshot> Function();

// Classes ----------------------------------------------------------------- //

/// Source of the collection points shown on the home map.
///
/// [loadOffline] reads the bundled asset (or the last downloaded cache) and
/// [refresh] only updates the cache when a [CollectPointsFetcher] is provided.
class CollectPointsRepository {
  CollectPointsRepository({
    AssetBundle? assetBundle,
    this.fetcher,
    Future<SharedPreferences> Function()? preferencesFactory,
    DateTime Function()? clock,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now;

  final AssetBundle _assetBundle;

  /// Optional remote source; null while there is no backend.
  final CollectPointsFetcher? fetcher;

  final Future<SharedPreferences> Function() _preferencesFactory;
  final DateTime Function() _clock;

  DateTime? _lastUpdated;

  /// Timestamp of the dataset currently loaded, or null before the first load.
  DateTime? get lastUpdated => _lastUpdated;

  bool get hasRemoteSource => fetcher != null;

  bool get isStale {
    final DateTime? lastUpdated = _lastUpdated;
    if (lastUpdated == null) {
      return true;
    }

    return _clock().difference(lastUpdated) > kCollectPointsMaxAge;
  }

  // Methods --------------------------------------------------------------- //

  /// Loads the points without network, preferring the downloaded cache.
  Future<List<CollectionPoint>> loadOffline() async {
    final SharedPreferences preferences = await _preferencesFactory();
    final String? cachedJson = preferences.getString(_cacheJsonKey);
    final int? cachedTimestamp = preferences.getInt(_cacheLastUpdatedKey);

    if (cachedJson != null) {
      final _ParsedCollectPoints cached = _parsePointsJson(cachedJson);
      if (cached.points.isNotEmpty) {
        _lastUpdated = cachedTimestamp == null
            ? cached.updatedAt
            : DateTime.fromMillisecondsSinceEpoch(cachedTimestamp, isUtc: true);
        return cached.points;
      }
    }

    final String assetJson = await _assetBundle.loadString(kCollectPointsAsset);
    final _ParsedCollectPoints local = _parsePointsJson(assetJson);
    _lastUpdated = local.updatedAt;

    return local.points;
  }

  /// Tries to update the local cache and returns the freshest known dataset.
  ///
  /// Without a [CollectPointsFetcher] it returns [loadOffline] unchanged, so
  /// the last update timestamp is never faked.
  Future<List<CollectionPoint>> refresh() async {
    final CollectPointsFetcher? fetcher = this.fetcher;
    if (fetcher == null) {
      return loadOffline();
    }

    try {
      final CollectPointsRemoteSnapshot remote = await fetcher();
      final List<CollectionPoint> points = _sorted(remote.points);
      final DateTime updatedAt = remote.updatedAt.toUtc();

      await _writeCache(points, updatedAt);
      _lastUpdated = updatedAt;

      return points;
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

  Future<void> _writeCache(
    List<CollectionPoint> points,
    DateTime updatedAt,
  ) async {
    final SharedPreferences preferences = await _preferencesFactory();

    await preferences.setString(
      _cacheJsonKey,
      jsonEncode({
        "updatedAt": updatedAt.toIso8601String(),
        "points": points
            .map((CollectionPoint point) => point.toJson())
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

class _ParsedCollectPoints {
  const _ParsedCollectPoints({required this.points, required this.updatedAt});

  final List<CollectionPoint> points;
  final DateTime? updatedAt;
}

// Methods ----------------------------------------------------------------- //

_ParsedCollectPoints _parsePointsJson(String source) {
  final Object? decoded = jsonDecode(source);

  final List<dynamic> rawPoints;
  String? rawUpdatedAt;

  if (decoded is Map<String, dynamic>) {
    final Object? points = decoded["points"];
    rawPoints = points is List<dynamic> ? points : const <dynamic>[];
    rawUpdatedAt = decoded["updatedAt"] is String
        ? decoded["updatedAt"] as String
        : null;
  } else if (decoded is List<dynamic>) {
    rawPoints = decoded;
  } else {
    rawPoints = const <dynamic>[];
  }

  final List<CollectionPoint> points = _sorted(
    rawPoints
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> json) =>
              CollectionPoint.fromJson(json.cast<String, dynamic>()),
        )
        .toList(),
  );

  return _ParsedCollectPoints(
    points: points,
    updatedAt: rawUpdatedAt == null ? null : DateTime.tryParse(rawUpdatedAt),
  );
}

List<CollectionPoint> _sorted(List<CollectionPoint> points) {
  return List<CollectionPoint>.of(points)..sort(
    (CollectionPoint first, CollectionPoint second) =>
        first.name.toLowerCase().compareTo(second.name.toLowerCase()),
  );
}
