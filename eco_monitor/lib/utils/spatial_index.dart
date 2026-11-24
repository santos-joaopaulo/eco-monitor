import "dart:math" as math;

import "../models/collection_point.dart";
import "geo.dart";


// Enums ------------------------------------------------------------------- //


/// Opções de raio de proximidade configuráveis para filtragem espacial.
enum ProximityRadius {
  twoKm(2000, "2 km"),
  fiveKm(5000, "5 km (padrão)"),
  tenKm(10000, "10 km"),
  unlimited(null, "Sem limite");

  const ProximityRadius(this.meters, this.label);

  /// Distância máxima em metros, ou `null` quando não houver restrição de distância.
  final double? meters;

  /// Rótulo em português exibido na interface do usuário.
  final String label;

  /// Retorna o próximo raio maior na sequência, útil para expansão de busca em 1 toque.
  ProximityRadius get expandNext => switch (this) {
    ProximityRadius.twoKm => ProximityRadius.fiveKm,
    ProximityRadius.fiveKm => ProximityRadius.tenKm,
    ProximityRadius.tenKm => ProximityRadius.unlimited,
    ProximityRadius.unlimited => ProximityRadius.unlimited,
  };
}


// Classes ----------------------------------------------------------------- //


/// Caixa delimitadora geográfica definida por latitudes e longitudes mínimas e máximas.
class SpatialBounds {
  const SpatialBounds({
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });

  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;

  /// Cria uma caixa delimitadora que engloba um círculo geográfico de raio em metros.
  factory SpatialBounds.fromCircle({
    required double centerLat,
    required double centerLon,
    required double radiusMeters,
  }) {
    // 1 grau de latitude equivale a aproximadamente 111.139 metros na Terra.
    final double latDelta = radiusMeters / 111139.0;

    // Ajuste longitudinal pela curvatura do paralelo de latitude central.
    final double radLat = centerLat * math.pi / 180.0;
    final double cosLat = math.cos(radLat).abs();
    final double lonDelta = cosLat > 0.0001
        ? radiusMeters / (111139.0 * cosLat)
        : latDelta;

    return SpatialBounds(
      minLat: (centerLat - latDelta).clamp(-90.0, 90.0),
      minLon: (centerLon - lonDelta).clamp(-180.0, 180.0),
      maxLat: (centerLat + latDelta).clamp(-90.0, 90.0),
      maxLon: (centerLon + lonDelta).clamp(-180.0, 180.0),
    );
  }

  /// Verifica se um ponto geográfico está contido dentro desta caixa delimitadora.
  bool contains(double lat, double lon) {
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  /// Verifica se esta caixa delimitadora intersecta outra caixa delimitadora.
  bool intersects(SpatialBounds other) {
    return !(other.maxLat < minLat ||
        other.minLat > maxLat ||
        other.maxLon < minLon ||
        other.minLon > maxLon);
  }
}


/// Item com coordenadas espaciais indexável pelo [SpatialIndex].
class SpatialEntry<T> {
  const SpatialEntry({
    required this.item,
    required this.latitude,
    required this.longitude,
  });

  final T item;
  final double latitude;
  final double longitude;
}


/// Nó interno de uma Quadtree espacial 2D em memória.
class _QuadTreeNode<T> {
  _QuadTreeNode(this.bounds, {this.capacity = 8});

  final SpatialBounds bounds;
  final int capacity;

  final List<SpatialEntry<T>> _entries = <SpatialEntry<T>>[];
  bool _isSubdivided = false;

  _QuadTreeNode<T>? _northWest;
  _QuadTreeNode<T>? _northEast;
  _QuadTreeNode<T>? _southWest;
  _QuadTreeNode<T>? _southEast;

  bool insert(SpatialEntry<T> entry) {
    if (!bounds.contains(entry.latitude, entry.longitude)) {
      return false;
    }

    if (_entries.length < capacity && !_isSubdivided) {
      _entries.add(entry);
      return true;
    }

    if (!_isSubdivided) {
      _subdivide();
    }

    if (_northWest!.insert(entry)) return true;
    if (_northEast!.insert(entry)) return true;
    if (_southWest!.insert(entry)) return true;
    if (_southEast!.insert(entry)) return true;

    // Em casos raros de sobreposição na borda, preserva no nó atual.
    _entries.add(entry);
    return true;
  }

  void _subdivide() {
    final double midLat = (bounds.minLat + bounds.maxLat) / 2.0;
    final double midLon = (bounds.minLon + bounds.maxLon) / 2.0;

    _northWest = _QuadTreeNode<T>(
      SpatialBounds(
        minLat: midLat,
        minLon: bounds.minLon,
        maxLat: bounds.maxLat,
        maxLon: midLon,
      ),
      capacity: capacity,
    );

    _northEast = _QuadTreeNode<T>(
      SpatialBounds(
        minLat: midLat,
        minLon: midLon,
        maxLat: bounds.maxLat,
        maxLon: bounds.maxLon,
      ),
      capacity: capacity,
    );

    _southWest = _QuadTreeNode<T>(
      SpatialBounds(
        minLat: bounds.minLat,
        minLon: bounds.minLon,
        maxLat: midLat,
        maxLon: midLon,
      ),
      capacity: capacity,
    );

    _southEast = _QuadTreeNode<T>(
      SpatialBounds(
        minLat: bounds.minLat,
        minLon: midLon,
        maxLat: midLat,
        maxLon: bounds.maxLon,
      ),
      capacity: capacity,
    );

    _isSubdivided = true;

    // Redistribui as entradas existentes para os novos quadrantes filhos.
    final List<SpatialEntry<T>> remaining = <SpatialEntry<T>>[];
    for (final SpatialEntry<T> entry in _entries) {
      final bool placed =
          _northWest!.insert(entry) ||
          _northEast!.insert(entry) ||
          _southWest!.insert(entry) ||
          _southEast!.insert(entry);
      if (!placed) {
        remaining.add(entry);
      }
    }
    _entries
      ..clear()
      ..addAll(remaining);
  }

  void queryBounds(SpatialBounds searchBounds, List<SpatialEntry<T>> results) {
    if (!bounds.intersects(searchBounds)) {
      return;
    }

    for (final SpatialEntry<T> entry in _entries) {
      if (searchBounds.contains(entry.latitude, entry.longitude)) {
        results.add(entry);
      }
    }

    if (_isSubdivided) {
      _northWest!.queryBounds(searchBounds, results);
      _northEast!.queryBounds(searchBounds, results);
      _southWest!.queryBounds(searchBounds, results);
      _southEast!.queryBounds(searchBounds, results);
    }
  }

  int count() {
    int total = _entries.length;
    if (_isSubdivided) {
      total += _northWest!.count();
      total += _northEast!.count();
      total += _southWest!.count();
      total += _southEast!.count();
    }
    return total;
  }
}


/// Índice espacial em memória baseado em Quadtree geográfica (T11.1).
///
/// Provê buscas espaciais por Bounding Box e raio de proximidade em complexidade
/// logarítmica sublinear O(log n), otimizando consultas em centenas de pontos.
class SpatialIndex<T> {
  SpatialIndex({
    SpatialBounds? worldBounds,
    this.nodeCapacity = 8,
    required this.getLatitude,
    required this.getLongitude,
  })  : _worldBounds =
            worldBounds ??
            const SpatialBounds(
              minLat: -90.0,
              minLon: -180.0,
              maxLat: 90.0,
              maxLon: 180.0,
            ) {
    _root = _QuadTreeNode<T>(_worldBounds, capacity: nodeCapacity);
  }

  final double Function(T) getLatitude;
  final double Function(T) getLongitude;
  final int nodeCapacity;
  final SpatialBounds _worldBounds;

  late _QuadTreeNode<T> _root;
  int _size = 0;

  /// Quantidade total de itens atualmente indexados.
  int get size => _size;

  /// Limpa todas as entradas e recria o nó raiz da árvore.
  void clear() {
    _root = _QuadTreeNode<T>(_worldBounds, capacity: nodeCapacity);
    _size = 0;
  }

  /// Insere um novo item no índice espacial.
  void insert(T item) {
    final double lat = getLatitude(item);
    final double lon = getLongitude(item);
    final SpatialEntry<T> entry = SpatialEntry<T>(
      item: item,
      latitude: lat,
      longitude: lon,
    );

    if (_root.insert(entry)) {
      _size++;
    }
  }

  /// Insere múltiplos itens de forma sequencial no índice.
  void insertAll(Iterable<T> items) {
    for (final T item in items) {
      insert(item);
    }
  }

  /// Constrói o índice a partir de uma coleção inicial de itens.
  void load(Iterable<T> items) {
    clear();
    insertAll(items);
  }

  /// Consulta todos os itens contidos dentro de uma caixa delimitadora geográfica.
  List<T> queryBoundingBox(SpatialBounds bounds) {
    final List<SpatialEntry<T>> entries = <SpatialEntry<T>>[];
    _root.queryBounds(bounds, entries);
    return entries.map((SpatialEntry<T> e) => e.item).toList();
  }

  /// Consulta itens localizados dentro de um raio de proximidade em metros.
  ///
  /// Utiliza a caixa delimitadora do círculo para filtragem em O(log n) e valida
  /// a distância ortodrômica precisa via fórmula de Haversine.
  List<T> queryRadius({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) {
    if (radiusMeters <= 0) {
      return const [];
    }

    final SpatialBounds boundingBox = SpatialBounds.fromCircle(
      centerLat: latitude,
      centerLon: longitude,
      radiusMeters: radiusMeters,
    );

    final List<SpatialEntry<T>> candidates = <SpatialEntry<T>>[];
    _root.queryBounds(boundingBox, candidates);

    final List<T> matches = <T>[];
    for (final SpatialEntry<T> entry in candidates) {
      final double distance = distanceInMeters(
        latitude,
        longitude,
        entry.latitude,
        entry.longitude,
      );

      if (distance <= radiusMeters) {
        matches.add(entry.item);
      }
    }

    return matches;
  }

  /// Localiza os [k] vizinhos mais próximos em relação à coordenada especificada.
  ///
  /// Opcionalmente restringe a busca a uma distância máxima [maxRadiusMeters].
  List<T> nearestNeighbors({
    required double latitude,
    required double longitude,
    int k = 1,
    double? maxRadiusMeters,
  }) {
    if (k <= 0 || _size == 0) {
      return const [];
    }

    // Se houver restrição de raio, busca inicialmente nessa caixa delimitadora.
    // Caso contrário, busca candidatos em caixas expansivas concêntricas.
    List<SpatialEntry<T>> candidates = <SpatialEntry<T>>[];

    if (maxRadiusMeters != null) {
      final SpatialBounds bounds = SpatialBounds.fromCircle(
        centerLat: latitude,
        centerLon: longitude,
        radiusMeters: maxRadiusMeters,
      );
      _root.queryBounds(bounds, candidates);
    } else {
      // Começa com raio de 5 km, expandindo progressivamente até encontrar k pontos ou cobrir o mapa.
      double searchRadius = 5000.0;
      while (candidates.length < k && searchRadius <= 2000000.0) {
        candidates.clear();
        final SpatialBounds bounds = SpatialBounds.fromCircle(
          centerLat: latitude,
          centerLon: longitude,
          radiusMeters: searchRadius,
        );
        _root.queryBounds(bounds, candidates);
        searchRadius *= 3.0;
      }

      // Se ainda não encontrou k pontos, consulta o espaço global completo.
      if (candidates.length < k) {
        candidates.clear();
        _root.queryBounds(_worldBounds, candidates);
      }
    }

    // Ordena os candidatos por distância exata de Haversine.
    final List<_DistancePair<T>> pairs = <_DistancePair<T>>[];
    for (final SpatialEntry<T> entry in candidates) {
      final double dist = distanceInMeters(
        latitude,
        longitude,
        entry.latitude,
        entry.longitude,
      );
      if (maxRadiusMeters == null || dist <= maxRadiusMeters) {
        pairs.add(_DistancePair<T>(entry.item, dist));
      }
    }

    pairs.sort((a, b) => a.distance.compareTo(b.distance));
    return pairs.take(k).map((p) => p.item).toList();
  }
}


class _DistancePair<T> {
  const _DistancePair(this.item, this.distance);
  final T item;
  final double distance;
}


/// Índice espacial especializado para instâncias de [CollectionPoint].
class CollectionPointSpatialIndex {
  CollectionPointSpatialIndex({Iterable<CollectionPoint>? initialPoints})
    : _index = SpatialIndex<CollectionPoint>(
        getLatitude: (CollectionPoint p) => p.latitude,
        getLongitude: (CollectionPoint p) => p.longitude,
      ) {
    if (initialPoints != null) {
      _index.load(initialPoints);
    }
  }

  final SpatialIndex<CollectionPoint> _index;

  int get size => _index.size;

  void load(Iterable<CollectionPoint> points) => _index.load(points);

  void insert(CollectionPoint point) => _index.insert(point);

  void clear() => _index.clear();

  List<CollectionPoint> queryRadius({
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) => _index.queryRadius(
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
  );

  List<CollectionPoint> nearestNeighbors({
    required double latitude,
    required double longitude,
    int k = 1,
    double? maxRadiusMeters,
  }) => _index.nearestNeighbors(
    latitude: latitude,
    longitude: longitude,
    k: k,
    maxRadiusMeters: maxRadiusMeters,
  );
}
