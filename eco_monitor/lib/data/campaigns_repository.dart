import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/campaign.dart";
import "collect_points_repository.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";
import "local_store.dart";


// Constants ---------------------------------------------------------------- //


/// Conjunto de dados padrão de campanhas empacotado no app, disponível sem rede.
const String kCampaignsAsset = "assets/data/campaigns.json";

/// Nome da coleção no Firestore para campanhas de coleta.
const String kCampaignsCollection = "campaigns";

const String _cacheJsonKey = "campaigns_json";
const String _cacheLastUpdatedKey = "campaigns_last_updated";

/// Idade máxima antes que os dados locais de campanhas sejam considerados desatualizados.
const Duration kCampaignsMaxAge = Duration(days: 1);


// Types ------------------------------------------------------------------- //


/// Conjunto de dados retornado por uma atualização remota de campanhas, com o timestamp do servidor.
class CampaignsRemoteSnapshot {
  const CampaignsRemoteSnapshot({
    required this.campaigns,
    required this.updatedAt,
  });

  final List<Campaign> campaigns;
  final DateTime updatedAt;
}

/// Função usada por [CampaignsRepository.refresh] para buscar campanhas remotas.
typedef CampaignsFetcher = Future<CampaignsRemoteSnapshot> Function();


// Methods ----------------------------------------------------------------- //


/// Cria um [CampaignsFetcher] baseado na coleção `campaigns` do Firestore.
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


/// Fonte de campanhas de coleta exibidas aos usuários (RF08, RF09, RNF11).
///
/// Segue o padrão offline-first: [loadOffline] prioriza o cache salvo no
/// [SharedPreferences] e recorre ao arquivo empacotado [kCampaignsAsset];
/// [refresh] busca dados atualizados de [fetcher] e atualiza o cache.
class CampaignsRepository {
  CampaignsRepository({
    AssetBundle? assetBundle,
    this.fetcher,
    LocalStore? localStore,
    Future<SharedPreferences> Function()? preferencesFactory,
    DateTime Function()? clock,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _store = localStore ??
           SharedPreferencesLocalStore(
             preferencesFactory: preferencesFactory,
           ),
       _clock = clock ?? DateTime.now;

  final AssetBundle _assetBundle;
  final CampaignsFetcher? fetcher;
  final LocalStore _store;
  final DateTime Function() _clock;

  DateTime? _lastUpdated;
  DataSourceOrigin? _sourceOrigin;

  /// Timestamp do conjunto de dados atualmente carregado, ou nulo antes do primeiro carregamento.
  DateTime? get lastUpdated => _lastUpdated;

  /// Origem do conjunto de dados carregado mais recentemente.
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


  /// Carrega campanhas sem rede, priorizando o cache local e recorrendo
  /// ao arquivo empacotado quando nenhum cache existir.
  Future<List<Campaign>> loadOffline() async {
    final String? cachedJson = await _store.getString(_cacheJsonKey);
    final int? cachedTimestamp = await _store.getInt(_cacheLastUpdatedKey);

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

  /// Busca campanhas a partir de [fetcher] e atualiza o cache local.
  ///
  /// Sem um [fetcher] ou em falhas de rede, recorre a [loadOffline].
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

  /// Remove o cache local baixado, mantendo disponível o conjunto de dados empacotado.
  Future<void> clearCache() async {
    await _store.remove(_cacheJsonKey);
    await _store.remove(_cacheLastUpdatedKey);
  }

  Future<void> _writeCache(List<Campaign> campaigns, DateTime updatedAt) async {
    await _store.setString(
      _cacheJsonKey,
      jsonEncode(<String, dynamic>{
        "updatedAt": updatedAt.toIso8601String(),
        "campaigns": campaigns
            .map((Campaign campaign) => campaign.toJson())
            .toList(),
      }),
    );
    await _store.setInt(
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
