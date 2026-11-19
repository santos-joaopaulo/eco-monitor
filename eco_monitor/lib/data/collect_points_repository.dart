import "dart:convert";

import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/collection_point.dart";


// Constants ---------------------------------------------------------------- //


/// Arquivo empacotado no app, disponível sem conexão de rede.
const String kCollectPointsAsset = "assets/data/collect_points.json";

const String _cacheJsonKey = "collect_points_json";
const String _cacheLastUpdatedKey = "collect_points_last_updated";

/// Idade máxima antes que os dados locais sejam considerados desatualizados.
const Duration kCollectPointsMaxAge = Duration(days: 7);


// Enums ------------------------------------------------------------------- //


/// Origem do conjunto de dados atualmente mantido por um repositório (RNF10, RNF17).
enum DataSourceOrigin { bundledAsset, localCache, remoteServer }


// Types ------------------------------------------------------------------- //


/// Conjunto de dados retornado por uma atualização remota, com o timestamp da origem.
///
/// O timestamp deve vir do servidor (no caso do Firebase, um `Timestamp` do
/// Firestore) para que a interface nunca apresente dados desatualizados como novos (RNF17).
class CollectPointsRemoteSnapshot {
  const CollectPointsRemoteSnapshot({
    required this.points,
    required this.updatedAt,
  });

  final List<CollectionPoint> points;
  final DateTime updatedAt;
}

/// Função usada por [CollectPointsRepository.refresh] para buscar dados mais recentes.
///
/// Quando nula, o repositório sempre recorre ao cache local ou ao arquivo
/// empacotado em vez de simular uma atualização.
typedef CollectPointsFetcher = Future<CollectPointsRemoteSnapshot> Function();


// Classes ----------------------------------------------------------------- //


/// Fonte dos pontos de coleta exibidos no mapa da tela inicial.
///
/// [loadOffline] lê o cache baixado (ou recorre ao arquivo empacotado)
/// e [refresh] atualiza o cache quando um [CollectPointsFetcher] é fornecido.
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

  /// Fonte remota opcional; nula quando em modo exclusivamente offline.
  final CollectPointsFetcher? fetcher;

  final Future<SharedPreferences> Function() _preferencesFactory;
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

    return _clock().difference(lastUpdated) > kCollectPointsMaxAge;
  }


  // Methods --------------------------------------------------------------- //


  /// Carrega os pontos sem rede, priorizando o cache local baixado.
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
        _sourceOrigin = DataSourceOrigin.localCache;
        return cached.points;
      }
    }

    final String assetJson = await _assetBundle.loadString(kCollectPointsAsset);
    final _ParsedCollectPoints local = _parsePointsJson(assetJson);
    _lastUpdated = local.updatedAt;
    _sourceOrigin = DataSourceOrigin.bundledAsset;

    return local.points;
  }

  /// Tenta atualizar o cache local e retorna o conjunto de dados mais recente conhecido.
  ///
  /// Sem um [CollectPointsFetcher], retorna [loadOffline] sem alterações, garantindo
  /// que o timestamp da última atualização nunca seja forjado.
  Future<List<CollectionPoint>> refresh() async {
    final CollectPointsFetcher? fetcher = this.fetcher;
    if (fetcher == null) {
      return loadOffline();
    }

    try {
      final CollectPointsRemoteSnapshot remote = await fetcher();
      if (remote.points.isEmpty) {
        return await loadOffline();
      }

      final List<CollectionPoint> points = _sorted(remote.points);
      final DateTime updatedAt = remote.updatedAt.toUtc();

      await _writeCache(points, updatedAt);
      _lastUpdated = updatedAt;
      _sourceOrigin = DataSourceOrigin.remoteServer;

      return points;
    } catch (_) {
      return loadOffline();
    }
  }

  /// Remove o cache local baixado, mantendo disponível o conjunto empacotado.
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
      jsonEncode(<String, dynamic>{
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
