import "dart:convert";

import "package:flutter/services.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../domain/repositories/collect_points_repository_contract.dart";
import "../domain/entities/collection_point.dart";
import "local_store.dart";


// Constants ---------------------------------------------------------------- //


/// Arquivo empacotado no app, disponível sem conexão de rede.
const String kCollectPointsAsset = "assets/data/collect_points.json";

/// Versão do documento único de cache local.
const int kCollectPointsCacheVersion = 1;

const String _cacheJsonKey = "collect_points_json";
const String _cacheLastUpdatedKey = "collect_points_last_updated";

/// Idade máxima antes que os dados locais sejam considerados desatualizados.
const Duration kCollectPointsMaxAge = Duration(days: 7);


// Enums -------------------------------------------------------------------- //


/// Origem do conjunto de dados atualmente mantido por um repositório (RNF10, RNF17).
enum DataSourceOrigin { bundledAsset, localCache, remoteServer }


// Types -------------------------------------------------------------------- //


/// Conjunto de dados retornado por uma atualização remota, com o timestamp da origem.
///
/// O timestamp deve vir do servidor (no caso do Firebase, um `Timestamp` do
/// Firestore) para que a interface nunca apresente dados desatualizados como novos (RNF17).
class CollectPointsRemoteSnapshot {
  const CollectPointsRemoteSnapshot({
    required this.points,
    required this.updatedAt,
    this.isDelta = false,
    this.deletedIds = const <String>[],
  });

  final List<CollectionPoint> points;
  final DateTime updatedAt;
  final bool isDelta;
  final List<String> deletedIds;
}

/// Função usada por [CollectPointsRepository.refresh] para buscar dados mais recentes.
///
/// Quando nula, o repositório sempre recorre ao cache local ou ao arquivo
/// empacotado em vez de simular uma atualização.
typedef CollectPointsFetcher = Future<CollectPointsRemoteSnapshot> Function();

/// Função que suporta sincronização incremental a partir de um timestamp de referência (T11.4).
typedef CollectPointsDeltaFetcher = Future<CollectPointsRemoteSnapshot> Function(
  DateTime? since,
);


// Classes ------------------------------------------------------------------ //


/// Fonte dos pontos de coleta exibidos no mapa da tela inicial.
///
/// [loadOffline] lê o cache baixado (ou recorre ao arquivo empacotado)
/// e [refresh] atualiza o cache quando um [CollectPointsFetcher] é fornecido.
class CollectPointsRepository implements ICollectPointsRepository {
  CollectPointsRepository({
    AssetBundle? assetBundle,
    this.fetcher,
    this.deltaFetcher,
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

  /// Fonte remota opcional para carga completa; nula quando em modo exclusivamente offline.
  final CollectPointsFetcher? fetcher;

  /// Fonte remota com suporte a consultas delta incrementais (T11.4).
  final CollectPointsDeltaFetcher? deltaFetcher;

  final LocalStore _store;
  final DateTime Function() _clock;

  DateTime? _lastUpdated;
  DataSourceOrigin? _sourceOrigin;

  /// Timestamp do conjunto de dados atualmente carregado, ou nulo antes do primeiro carregamento.
  @override
  DateTime? get lastUpdated => _lastUpdated;

  /// Origem do conjunto de dados carregado mais recentemente.
  DataSourceOrigin? get sourceOrigin => _sourceOrigin;

  @override
  bool get hasRemoteSource => fetcher != null || deltaFetcher != null;

  @override
  bool get isStale {
    final DateTime? lastUpdated = _lastUpdated;
    if (lastUpdated == null) {
      return true;
    }

    return _clock().difference(lastUpdated) > kCollectPointsMaxAge;
  }


// Methods ------------------------------------------------------------------ //


  /// Carrega os pontos sem rede, priorizando o cache local baixado.
  @override
  Future<List<CollectionPoint>> loadOffline() async {
    final String? cachedRaw = await _store.getString(_cacheJsonKey);

    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(cachedRaw);
        if (decoded is Map<String, dynamic>) {
          final Object? versionObj = decoded["version"];

          if (versionObj != null) {
            // Formato de documento único versionado: {version, updatedAt, points}.
            if (versionObj == kCollectPointsCacheVersion) {
              final String? updatedAtStr = decoded["updatedAt"] as String?;
              final Object? rawPoints = decoded["points"];
              final List<dynamic> pointsList =
                  rawPoints is List<dynamic> ? rawPoints : const <dynamic>[];
              final List<CollectionPoint> parsed = _parsePointsList(pointsList);

              if (parsed.isNotEmpty) {
                _lastUpdated = updatedAtStr == null
                    ? null
                    : DateTime.tryParse(updatedAtStr)?.toUtc();
                _sourceOrigin = DataSourceOrigin.localCache;
                return parsed;
              }
            } else {
              // Versão desconhecida de esquema: fallback seguro para o asset embarcado.
            }
          } else {
            // Formato legado com chaves separadas (collect_points_json + collect_points_last_updated).
            final _ParsedCollectPoints legacy = _parsePointsJson(cachedRaw);
            if (legacy.points.isNotEmpty) {
              final int? cachedTimestamp =
                  await _store.getInt(_cacheLastUpdatedKey);
              final DateTime updatedAt = cachedTimestamp == null
                  ? (legacy.updatedAt ?? DateTime.now().toUtc())
                  : DateTime.fromMillisecondsSinceEpoch(
                      cachedTimestamp,
                      isUtc: true,
                    );

              // Migração na primeira leitura para documento único versionado.
              await _writeCache(legacy.points, updatedAt);
              await _store.remove(_cacheLastUpdatedKey);

              _lastUpdated = updatedAt;
              _sourceOrigin = DataSourceOrigin.localCache;
              return legacy.points;
            }
          }
        } else if (decoded is List<dynamic>) {
          // Formato legado com lista simples de pontos.
          final List<CollectionPoint> parsed = _parsePointsList(decoded);
          if (parsed.isNotEmpty) {
            final int? cachedTimestamp =
                await _store.getInt(_cacheLastUpdatedKey);
            final DateTime updatedAt = cachedTimestamp == null
                ? DateTime.now().toUtc()
                : DateTime.fromMillisecondsSinceEpoch(
                    cachedTimestamp,
                    isUtc: true,
                  );

            await _writeCache(parsed, updatedAt);
            await _store.remove(_cacheLastUpdatedKey);

            _lastUpdated = updatedAt;
            _sourceOrigin = DataSourceOrigin.localCache;
            return parsed;
          }
        }
      } catch (_) {
        // Cache corrompido: descarta silenciosamente e recorre ao fallback dos assets.
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
  /// Suporta sincronização incremental inteligente (merge de deltas e remoção lógica)
  /// quando um [deltaFetcher] estiver configurado (T11.4).
  @override
  Future<List<CollectionPoint>> refresh() async {
    return _refreshInternal(forceFull: false);
  }

  /// Força a atualização completa descartando dados delta (T11.4).
  Future<List<CollectionPoint>> refreshFull() async {
    return _refreshInternal(forceFull: true);
  }

  Future<List<CollectionPoint>> _refreshInternal({bool forceFull = false}) async {
    final CollectPointsDeltaFetcher? deltaFetcher = this.deltaFetcher;
    final CollectPointsFetcher? fetcher = this.fetcher;

    if (deltaFetcher == null && fetcher == null) {
      return await loadOffline();
    }

    try {
      final CollectPointsRemoteSnapshot remote;
      if (deltaFetcher != null && !forceFull && _lastUpdated != null) {
        remote = await deltaFetcher(_lastUpdated);
      } else if (fetcher != null) {
        remote = await fetcher();
      } else if (deltaFetcher != null) {
        remote = await deltaFetcher(null);
      } else {
        return await loadOffline();
      }

      final DateTime updatedAt = remote.updatedAt.toUtc();

      if (remote.isDelta) {
        // Merge inteligente incremental (T11.4)
        final List<CollectionPoint> current = await loadOffline();
        final Map<String, CollectionPoint> map = <String, CollectionPoint>{
          for (final CollectionPoint p in current) p.id: p,
        };

        // Remove pontos por tombstones recebidos
        for (final String deletedId in remote.deletedIds) {
          map.remove(deletedId);
        }

        // Atualiza ou remove pontos recebidos no delta
        for (final CollectionPoint point in remote.points) {
          if (!point.isActive) {
            map.remove(point.id);
          } else {
            map[point.id] = point;
          }
        }

        final List<CollectionPoint> merged = _sorted(map.values.toList());
        await _writeCache(merged, updatedAt);
        _lastUpdated = updatedAt;
        _sourceOrigin = DataSourceOrigin.remoteServer;
        return merged;
      }

      // Sincronização completa
      if (remote.points.isEmpty) {
        return await loadOffline();
      }

      final List<CollectionPoint> activePoints = _sorted(
        remote.points.where((CollectionPoint p) => p.isActive).toList(),
      );

      await _writeCache(activePoints, updatedAt);
      _lastUpdated = updatedAt;
      _sourceOrigin = DataSourceOrigin.remoteServer;

      return activePoints;
    } catch (_) {
      return await loadOffline();
    }
  }

  /// Remove o cache local baixado, mantendo disponível o conjunto empacotado.
  Future<void> clearCache() async {
    await _store.remove(_cacheJsonKey);
    await _store.remove(_cacheLastUpdatedKey);
    _lastUpdated = null;
    _sourceOrigin = null;
  }

  /// Insere ou atualiza pontos no armazenamento local de forma idempotente (upsert).
  @override
  Future<List<CollectionPoint>> upsertLocalPoints(
    List<CollectionPoint> newPoints, {
    DateTime? updatedAt,
  }) async {
    final List<CollectionPoint> current = await loadOffline();
    final Map<String, CollectionPoint> map = <String, CollectionPoint>{
      for (final CollectionPoint point in current) point.id: point,
    };

    for (final CollectionPoint point in newPoints) {
      map[point.id] = point;
    }

    final List<CollectionPoint> sorted = _sorted(map.values.toList());
    final DateTime timestamp = (updatedAt ?? _clock()).toUtc();

    await _writeCache(sorted, timestamp);
    _lastUpdated = timestamp;
    _sourceOrigin = DataSourceOrigin.localCache;

    return sorted;
  }

  Future<void> _writeCache(
    List<CollectionPoint> points,
    DateTime updatedAt,
  ) async {
    final Map<String, dynamic> document = <String, dynamic>{
      "version": kCollectPointsCacheVersion,
      "updatedAt": updatedAt.toUtc().toIso8601String(),
      "points": points
          .map((CollectionPoint point) => point.toJson())
          .toList(),
    };

    await _store.setString(_cacheJsonKey, jsonEncode(document));
    // Remove chave legada caso ainda exista.
    await _store.remove(_cacheLastUpdatedKey);
  }
}


// Classes ------------------------------------------------------------------ //


class _ParsedCollectPoints {
  const _ParsedCollectPoints({required this.points, required this.updatedAt});

  final List<CollectionPoint> points;
  final DateTime? updatedAt;
}


// Methods ------------------------------------------------------------------ //


List<CollectionPoint> _parsePointsList(List<dynamic> rawPoints) {
  return _sorted(
    rawPoints
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> json) =>
              CollectionPoint.fromJson(json.cast<String, dynamic>()),
        )
        .toList(),
  );
}

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

  final List<CollectionPoint> points = _parsePointsList(rawPoints);

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
