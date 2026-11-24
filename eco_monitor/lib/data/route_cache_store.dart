import "dart:convert";

import "../utils/geo.dart";
import "local_store.dart";


// Constants ---------------------------------------------------------------- //


/// Chave de persistência das rotas em cache no [LocalStore].
const String kRouteCacheKey = "route_cache_entries_v1";

/// Tempo de vida padrão das rotas viárias em cache (24 horas).
const Duration kRouteCacheDefaultTtl = Duration(hours: 24);

/// Limite padrão de entradas mantidas no cache LRU.
const int kRouteCacheDefaultMaxEntries = 50;


// Classes ----------------------------------------------------------------- //


/// Entrada individual de rota viária persistida em cache.
class CachedRoute {
  const CachedRoute({
    required this.distanceMeters,
    required this.estimatedMinutes,
    required this.travelMode,
    required this.routeCoordinates,
    required this.cachedAt,
    required this.lastAccessedAt,
    this.originLat,
    this.originLon,
    this.destLat,
    this.destLon,
  });

  final double distanceMeters;
  final int estimatedMinutes;
  final TravelMode travelMode;
  final List<List<double>> routeCoordinates;
  final DateTime cachedAt;
  final DateTime lastAccessedAt;
  final double? originLat;
  final double? originLon;
  final double? destLat;
  final double? destLon;

  double get effectiveOriginLat =>
      originLat ?? (routeCoordinates.isNotEmpty ? routeCoordinates.first[1] : 0.0);
  double get effectiveOriginLon =>
      originLon ?? (routeCoordinates.isNotEmpty ? routeCoordinates.first[0] : 0.0);
  double get effectiveDestLat =>
      destLat ?? (routeCoordinates.isNotEmpty ? routeCoordinates.last[1] : 0.0);
  double get effectiveDestLon =>
      destLon ?? (routeCoordinates.isNotEmpty ? routeCoordinates.last[0] : 0.0);

  /// Verifica se a rota expirou com base no tempo de vida ([ttl]) estipulado.
  bool isExpired({
    Duration ttl = kRouteCacheDefaultTtl,
    DateTime Function()? clock,
  }) {
    final DateTime now = (clock ?? DateTime.now)().toUtc();
    return now.difference(cachedAt.toUtc()) > ttl;
  }

  CachedRoute copyWith({
    DateTime? lastAccessedAt,
    List<List<double>>? routeCoordinates,
  }) {
    return CachedRoute(
      distanceMeters: distanceMeters,
      estimatedMinutes: estimatedMinutes,
      travelMode: travelMode,
      routeCoordinates: routeCoordinates ?? this.routeCoordinates,
      cachedAt: cachedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      originLat: originLat,
      originLon: originLon,
      destLat: destLat,
      destLon: destLon,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "distanceMeters": distanceMeters,
      "estimatedMinutes": estimatedMinutes,
      "travelMode": travelMode.name,
      "routeCoordinates": routeCoordinates,
      "cachedAt": cachedAt.toUtc().toIso8601String(),
      "lastAccessedAt": lastAccessedAt.toUtc().toIso8601String(),
      "originLat": effectiveOriginLat,
      "originLon": effectiveOriginLon,
      "destLat": effectiveDestLat,
      "destLon": effectiveDestLon,
    };
  }

  factory CachedRoute.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawCoords = json["routeCoordinates"] as List<dynamic>?;
    final List<List<double>> coords = rawCoords != null
        ? rawCoords.map((dynamic pair) {
            final List<dynamic> p = pair as List<dynamic>;
            return <double>[
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ];
          }).toList()
        : const <List<double>>[];

    final String modeName = (json["travelMode"] as String?) ?? TravelMode.walking.name;
    final TravelMode mode = TravelMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => TravelMode.walking,
    );

    return CachedRoute(
      distanceMeters: (json["distanceMeters"] as num).toDouble(),
      estimatedMinutes: (json["estimatedMinutes"] as num).toInt(),
      travelMode: mode,
      routeCoordinates: coords,
      cachedAt: DateTime.tryParse(json["cachedAt"] as String? ?? "")?.toUtc() ??
          DateTime.now().toUtc(),
      lastAccessedAt:
          DateTime.tryParse(json["lastAccessedAt"] as String? ?? "")?.toUtc() ??
              DateTime.now().toUtc(),
      originLat: (json["originLat"] as num?)?.toDouble(),
      originLon: (json["originLon"] as num?)?.toDouble(),
      destLat: (json["destLat"] as num?)?.toDouble(),
      destLon: (json["destLon"] as num?)?.toDouble(),
    );
  }
}


/// Armazenamento em cache de rotas viárias com política de substituição LRU (T11.3).
///
/// Permite que trajetos consultados anteriormente sejam recuperados instantaneamente
/// e de forma offline, sem onerar a quota de requisições do Mapbox.
class RouteCacheStore {
  RouteCacheStore({
    LocalStore? localStore,
    this.maxEntries = kRouteCacheDefaultMaxEntries,
    this.ttl = kRouteCacheDefaultTtl,
    DateTime Function()? clock,
  })  : _store = localStore ?? SharedPreferencesLocalStore(),
        _clock = clock ?? DateTime.now;

  final LocalStore _store;
  final int maxEntries;
  final Duration ttl;
  final DateTime Function() _clock;

  Map<String, CachedRoute>? _memoryCache;

  /// Gera a chave geoespacial aproximada de uma coordenada com tolerância de ~20-30 metros.
  static String formatCoordinateKey(double lat, double lon) {
    final double roundedLat = (lat * 3000.0).round() / 3000.0;
    final double roundedLon = (lon * 3000.0).round() / 3000.0;
    return "$roundedLat,$roundedLon";
  }

  /// Constrói a chave identificadora de cache para a rota.
  static String buildCacheKey({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required TravelMode travelMode,
  }) {
    final String originKey = formatCoordinateKey(originLat, originLon);
    final String destKey = formatCoordinateKey(destLat, destLon);
    return "$originKey->$destKey:${travelMode.name}";
  }


  // Methods --------------------------------------------------------------- //


  /// Recupera uma rota do cache pelo par de coordenadas e modo de transporte.
  ///
  /// Atualiza o timestamp de último acesso (LRU). Suporta busca exata por chave de
  /// grade (~20-30m) e busca por proximidade espacial (caso o GPS oscile ~50-100m).
  /// Retorna `null` se não encontrada ou se tiver expirado pelo TTL de 24 horas.
  Future<CachedRoute?> getRoute({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required TravelMode travelMode,
    double originToleranceMeters = 100.0,
    double destToleranceMeters = 50.0,
  }) async {
    final Map<String, CachedRoute> cache = await _loadCache();
    final String key = buildCacheKey(
      originLat: originLat,
      originLon: originLon,
      destLat: destLat,
      destLon: destLon,
      travelMode: travelMode,
    );

    CachedRoute? route = cache[key];

    // Se a chave direta não encontrou (ex.: oscilação de GPS cruzou a borda do bucket),
    // realiza busca por tolerância espacial entre as rotas em cache.
    if (route == null) {
      double bestDistance = double.infinity;
      CachedRoute? bestRoute;

      for (final CachedRoute candidate in cache.values) {
        if (candidate.travelMode != travelMode) {
          continue;
        }

        final double destDist = distanceInMeters(
          destLat,
          destLon,
          candidate.effectiveDestLat,
          candidate.effectiveDestLon,
        );
        if (destDist > destToleranceMeters) {
          continue;
        }

        final double originDist = distanceInMeters(
          originLat,
          originLon,
          candidate.effectiveOriginLat,
          candidate.effectiveOriginLon,
        );
        if (originDist <= originToleranceMeters && originDist < bestDistance) {
          bestDistance = originDist;
          bestRoute = candidate;
        }
      }

      if (bestRoute != null) {
        route = bestRoute;
      }
    }

    if (route == null) {
      return null;
    }

    // Verifica se expirou pelo TTL
    if (route.isExpired(ttl: ttl, clock: _clock)) {
      cache.remove(key);
      await _persistCache(cache);
      return null;
    }

    // Atualiza o acesso para a política LRU
    final CachedRoute updated = route.copyWith(
      lastAccessedAt: _clock().toUtc(),
    );
    cache[key] = updated;
    await _persistCache(cache);

    return updated;
  }

  /// Insere ou atualiza uma rota no cache, aplicando descarte LRU caso atinja a capacidade máxima.
  Future<void> putRoute({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required TravelMode travelMode,
    required double distanceMeters,
    required int estimatedMinutes,
    required List<List<double>> routeCoordinates,
  }) async {
    final Map<String, CachedRoute> cache = await _loadCache();
    final String key = buildCacheKey(
      originLat: originLat,
      originLon: originLon,
      destLat: destLat,
      destLon: destLon,
      travelMode: travelMode,
    );

    final DateTime now = _clock().toUtc();
    final CachedRoute newRoute = CachedRoute(
      distanceMeters: distanceMeters,
      estimatedMinutes: estimatedMinutes,
      travelMode: travelMode,
      routeCoordinates: routeCoordinates,
      cachedAt: now,
      lastAccessedAt: now,
      originLat: originLat,
      originLon: originLon,
      destLat: destLat,
      destLon: destLon,
    );

    // Se a chave não existia e atingiu o limite, remove a rota menos recentemente acessada (LRU)
    if (!cache.containsKey(key) && cache.length >= maxEntries) {
      _evictLru(cache);
    }

    cache[key] = newRoute;
    await _persistCache(cache);
  }

  /// Retorna o número de rotas atualmente armazenadas em cache.
  Future<int> count() async {
    final Map<String, CachedRoute> cache = await _loadCache();
    return cache.length;
  }

  /// Remove todas as rotas do cache local e em memória.
  Future<void> clear() async {
    _memoryCache = <String, CachedRoute>{};
    await _store.remove(kRouteCacheKey);
  }

  void _evictLru(Map<String, CachedRoute> cache) {
    if (cache.isEmpty) {
      return;
    }

    String? oldestKey;
    DateTime? oldestAccess;

    for (final MapEntry<String, CachedRoute> entry in cache.entries) {
      if (oldestAccess == null || entry.value.lastAccessedAt.isBefore(oldestAccess)) {
        oldestAccess = entry.value.lastAccessedAt;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      cache.remove(oldestKey);
    }
  }

  Future<Map<String, CachedRoute>> _loadCache() async {
    if (_memoryCache != null) {
      return _memoryCache!;
    }

    try {
      final String? raw = await _store
          .getString(kRouteCacheKey)
          .timeout(const Duration(milliseconds: 200));
      if (raw == null || raw.isEmpty) {
        _memoryCache = <String, CachedRoute>{};
        return _memoryCache!;
      }

      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final Map<String, CachedRoute> map = <String, CachedRoute>{};
        for (final MapEntry<String, dynamic> entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            map[entry.key] = CachedRoute.fromJson(
              entry.value as Map<String, dynamic>,
            );
          }
        }
        _memoryCache = map;
        return map;
      }
    } catch (_) {
      // Ignora timeout em testes sem mock de SharedPreferences ou payload corrompido
    }

    _memoryCache = <String, CachedRoute>{};
    return _memoryCache!;
  }

  Future<void> _persistCache(Map<String, CachedRoute> cache) async {
    _memoryCache = cache;
    try {
      final Map<String, dynamic> raw = <String, dynamic>{
        for (final MapEntry<String, CachedRoute> entry in cache.entries)
          entry.key: entry.value.toJson(),
      };
      await _store
          .setString(kRouteCacheKey, jsonEncode(raw))
          .timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Ignora falha de persistência se store falhar ou em ambiente desacoplado
    }
  }
}
