import "dart:collection";
import "dart:math" as math;
import "dart:typed_data";

import "package:flutter/foundation.dart";

import "../domain/entities/collection_point.dart";
import "../services/location_service.dart";
import "../utils/geo.dart";
import "../utils/polyline_codec.dart";
import "offline_routing_service.dart";
import "route_service.dart";


// Constants ---------------------------------------------------------------- //


/// Dimensão angular padrão de cada quadrícula/tile espacial (~22 km x 22 km).
const double kTileSizeDegrees = 0.2;

/// Capacidade máxima do cache LRU de tiles residentes no heap de memória (RNF09, T14.1).
const int kMaxLruCachedTiles = 6;

/// Margem máxima em graus para aceitar pontos adjacentes à borda do tile.
const double kTileBorderToleranceDegrees = 0.005;


// Types -------------------------------------------------------------------- //


/// Função assíncrona responsável por carregar os dados de um tile sob demanda.
typedef TileLoader = Future<SpatialTile?> Function(String tileKey);


// Classes ------------------------------------------------------------------ //


/// Representa uma partição espacial contendo nós e arestas de uma região geográfica limitada.
class SpatialTile {
  SpatialTile({
    required this.tileKey,
    required this.bbox,
    required this.nodeIds,
    required this.nodeLats,
    required this.nodeLons,
    required this.adjacency,
    Set<int>? boundaryNodes,
  })  : boundaryNodes = boundaryNodes ?? <int>{},
        _nodeIndexMap = <int, int>{} {
    for (int i = 0; i < nodeIds.length; i++) {
      _nodeIndexMap[nodeIds[i]] = i;
    }
  }

  /// Identificador único da célula (ex.: "-55_-186").
  final String tileKey;

  /// Limites da célula: [minLat, minLon, maxLat, maxLon].
  final List<double> bbox;

  /// Identificadores globais dos nós nesta partição.
  final Int32List nodeIds;

  /// Latitudes correspondentes aos nós da partição.
  final Float64List nodeLats;

  /// Longitudes correspondentes aos nós da partição.
  final Float64List nodeLons;

  /// Adjacência indexada pelo ID global do nó de origem.
  final Map<int, List<RoadEdge>> adjacency;

  /// Conjunto de nós localizados na fronteira ou intercambiáveis com tiles adjacentes.
  final Set<int> boundaryNodes;

  final Map<int, int> _nodeIndexMap;

  int get nodeCount => nodeIds.length;

  bool containsNode(int globalNodeId) => _nodeIndexMap.containsKey(globalNodeId);

  int? getInternalIndex(int globalNodeId) => _nodeIndexMap[globalNodeId];

  /// Verifica se uma coordenada está dentro da área coberta pelo tile.
  bool containsCoordinate(double lat, double lon) {
    return lat >= bbox[0] - kTileBorderToleranceDegrees &&
        lat <= bbox[2] + kTileBorderToleranceDegrees &&
        lon >= bbox[1] - kTileBorderToleranceDegrees &&
        lon <= bbox[3] + kTileBorderToleranceDegrees;
  }

  /// Localiza o nó mais próximo de uma coordenada dentro deste tile.
  int findNearestNode(double lat, double lon) {
    if (nodeIds.isEmpty) {
      return -1;
    }

    double bestDist = double.infinity;
    int bestNodeId = -1;

    for (int i = 0; i < nodeIds.length; i++) {
      final double dist = distanceInMeters(
        lat,
        lon,
        nodeLats[i],
        nodeLons[i],
      );

      if (dist < bestDist) {
        bestDist = dist;
        bestNodeId = nodeIds[i];
      }
    }

    return bestNodeId;
  }

  /// Retorna as coordenadas [latitude, longitude] de um nó deste tile.
  List<double>? getNodeCoordinates(int globalNodeId) {
    final int? index = _nodeIndexMap[globalNodeId];
    if (index == null) {
      return null;
    }
    return <double>[nodeLats[index], nodeLons[index]];
  }
}

/// Backbone rodoviário estadual (rodovias tronco/principais interligando municípios e tiles).
class RoadBackbone {
  RoadBackbone({
    required this.nodeIds,
    required this.nodeLats,
    required this.nodeLons,
    required this.adjacency,
  }) {
    for (int i = 0; i < nodeIds.length; i++) {
      _nodeIndexMap[nodeIds[i]] = i;
    }
  }

  final Int32List nodeIds;
  final Float64List nodeLats;
  final Float64List nodeLons;
  final Map<int, List<RoadEdge>> adjacency;
  final Map<int, int> _nodeIndexMap = <int, int>{};

  bool containsNode(int nodeId) => _nodeIndexMap.containsKey(nodeId);

  List<double>? getNodeCoordinates(int nodeId) {
    final int? index = _nodeIndexMap[nodeId];
    if (index == null) {
      return null;
    }
    return <double>[nodeLats[index], nodeLons[index]];
  }

  int findNearestNode(double lat, double lon) {
    if (nodeIds.isEmpty) {
      return -1;
    }
    double bestDist = double.infinity;
    int bestNode = -1;
    for (int i = 0; i < nodeIds.length; i++) {
      final double dist = distanceInMeters(lat, lon, nodeLats[i], nodeLons[i]);
      if (dist < bestDist) {
        bestDist = dist;
        bestNode = nodeIds[i];
      }
    }
    return bestNode;
  }
}

/// Grafo viário particionado em blocos com cache LRU em memória e busca A* suave (T14.1).
class TiledRoadGraph {
  TiledRoadGraph({
    TileLoader? tileLoader,
    this.backbone,
    this.maxCachedTiles = kMaxLruCachedTiles,
  })  : _loader = tileLoader;

  final TileLoader? _loader;
  final RoadBackbone? backbone;
  final int maxCachedTiles;

  /// Cache LRU (LinkedHashMap garante ordem de inserção e acesso).
  final LinkedHashMap<String, SpatialTile> _lruCache =
      LinkedHashMap<String, SpatialTile>();

  /// Armazenamento em memória para tiles pré-carregados (útil em testes e malhas locais).
  final Map<String, SpatialTile> _registeredTiles = <String, SpatialTile>{};

  int get loadedTileCount => _lruCache.length;
  int get maxLoadedTiles => maxCachedTiles;

  /// Registra um tile no grafo viário (disponível para carregamento sob demanda).
  void registerTile(SpatialTile tile) {
    _registeredTiles[tile.tileKey] = tile;
  }

  /// Converte latitude e longitude na chave canônica de tile.
  static String tileKeyFor(double lat, double lon) {
    final int row = (lat / kTileSizeDegrees).floor();
    final int col = (lon / kTileSizeDegrees).floor();
    return "${row}_$col";
  }

  /// Calcula a bounding box geográfica [minLat, minLon, maxLat, maxLon] de um tile.
  static List<double> tileBbox(int row, int col) {
    final double minLat = row * kTileSizeDegrees;
    final double minLon = col * kTileSizeDegrees;
    return <double>[
      minLat,
      minLon,
      minLat + kTileSizeDegrees,
      minLon + kTileSizeDegrees,
    ];
  }

  /// Garante que o tile esteja residente na memória RAM respeitando a capacidade LRU.
  Future<SpatialTile?> getOrLoadTile(String tileKey) async {
    // 1. Hit no cache LRU: atualiza ordem de acesso
    if (_lruCache.containsKey(tileKey)) {
      final SpatialTile tile = _lruCache.remove(tileKey)!;
      _lruCache[tileKey] = tile;
      return tile;
    }

    // 2. Busca nos tiles registrados em memória
    SpatialTile? loaded = _registeredTiles[tileKey];

    // 3. Busca através do loader assíncrono sob demanda
    if (loaded == null && _loader != null) {
      loaded = await _loader(tileKey);
    }

    if (loaded == null) {
      return null;
    }

    // 4. Inserção no cache com despejo (eviction) se exceder o limite de RAM
    if (_lruCache.length >= maxCachedTiles) {
      final String oldestKey = _lruCache.keys.first;
      _lruCache.remove(oldestKey);
    }

    _lruCache[tileKey] = loaded;
    return loaded;
  }

  /// Localiza as coordenadas geográficas de um nó em qualquer tile carregado ou no backbone.
  List<double>? findNodeCoordinates(int nodeId) {
    for (final SpatialTile tile in _lruCache.values) {
      final List<double>? coords = tile.getNodeCoordinates(nodeId);
      if (coords != null) {
        return coords;
      }
    }
    return backbone?.getNodeCoordinates(nodeId);
  }

  /// Executa o cálculo de menor caminho A* sobre tiles particionados e backbone rodoviário.
  Future<RouteSummary?> findRoute({
    required UserLocation origin,
    required CollectionPoint destination,
    TravelMode travelMode = TravelMode.walking,
  }) async {
    final String startTileKey = tileKeyFor(origin.latitude, origin.longitude);
    final String endTileKey = tileKeyFor(destination.latitude, destination.longitude);

    final SpatialTile? startTile = await getOrLoadTile(startTileKey);
    final SpatialTile? endTile = await getOrLoadTile(endTileKey);

    if (startTile == null || endTile == null) {
      return null;
    }

    final int startNode = startTile.findNearestNode(origin.latitude, origin.longitude);
    final int endNode = endTile.findNearestNode(destination.latitude, destination.longitude);

    if (startNode == -1 || endNode == -1) {
      return null;
    }

    final double directDistance = distanceInMeters(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    final bool arrived = directDistance <= kArrivalThresholdMeters;
    if (arrived || startNode == endNode) {
      final double bearing = bearingInDegrees(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );

      return RouteSummary(
        distanceMeters: arrived ? 0 : directDistance,
        estimatedMinutes: arrived ? 0 : 1,
        travelMode: travelMode,
        bearingDegrees: bearing,
        cardinalDirection: cardinalDirectionFromDegrees(bearing),
        isArrived: arrived,
        isOfflineFallback: true,
        routeCoordinates: <List<double>>[
          <double>[origin.longitude, origin.latitude],
          <double>[destination.longitude, destination.latitude],
        ],
      );
    }

    // Modal viário
    final int targetModeMask = switch (travelMode) {
      TravelMode.driving => kModeDriving,
      TravelMode.cycling => kModeCycling,
      TravelMode.walking => kModeWalking,
    };

    final List<double>? destCoords = endTile.getNodeCoordinates(endNode) ??
        findNodeCoordinates(endNode);
    final double endLat = destCoords?[0] ?? destination.latitude;
    final double endLon = destCoords?[1] ?? destination.longitude;

    // Estruturas do algoritmo A*
    final Map<int, double> dists = <int, double>{startNode: 0.0};
    final Map<int, int> parentNodes = <int, int>{};
    final Map<int, RoadEdge> parentEdges = <int, RoadEdge>{};

    final _MinHeap heap = _MinHeap();
    heap.add(startNode, 0.0);

    bool reachedDestination = false;

    while (heap.isNotEmpty) {
      final _HeapItem item = heap.removeFirst();
      final int u = item.node;

      if (u == endNode) {
        reachedDestination = true;
        break;
      }

      final double currentDist = dists[u] ?? double.infinity;
      final List<double>? uCoords = findNodeCoordinates(u);
      final double uLat = uCoords?[0] ?? origin.latitude;
      final double uLon = uCoords?[1] ?? origin.longitude;

      if (item.priority >
          currentDist + distanceInMeters(uLat, uLon, endLat, endLon) + 1.0) {
        continue;
      }

      // Reúne arestas viárias do nó 'u' vindas dos tiles residentes ou do backbone
      final List<RoadEdge> edges = <RoadEdge>[];

      for (final SpatialTile tile in _lruCache.values) {
        final List<RoadEdge>? tileEdges = tile.adjacency[u];
        if (tileEdges != null) {
          edges.addAll(tileEdges);
        }
      }

      final List<RoadEdge>? backboneEdges = backbone?.adjacency[u];
      if (backboneEdges != null) {
        edges.addAll(backboneEdges);
      }

      for (final RoadEdge edge in edges) {
        if ((edge.modesMask & targetModeMask) == 0) {
          continue;
        }

        final int v = edge.targetNode;
        final double tentativeDist = currentDist + edge.distanceMeters;

        if (tentativeDist < (dists[v] ?? double.infinity)) {
          dists[v] = tentativeDist;
          parentNodes[v] = u;
          parentEdges[v] = edge;

          List<double>? vCoords = findNodeCoordinates(v);

          // Se o nó de destino está em um tile adjacente não residente, carrega sob demanda
          if (vCoords == null) {
            for (final MapEntry<String, SpatialTile> entry in _registeredTiles.entries) {
              if (entry.value.containsNode(v)) {
                await getOrLoadTile(entry.key);
                vCoords = entry.value.getNodeCoordinates(v);
                break;
              }
            }
          }

          final double vLat = vCoords?[0] ?? endLat;
          final double vLon = vCoords?[1] ?? endLon;
          final double heuristic = distanceInMeters(vLat, vLon, endLat, endLon);

          heap.add(v, tentativeDist + heuristic);
        }
      }
    }

    if (!reachedDestination || !parentNodes.containsKey(endNode)) {
      return null;
    }

    // Reconstrução do traçado da rota
    final List<RoadEdge> pathEdges = <RoadEdge>[];
    int curr = endNode;
    while (curr != startNode) {
      final RoadEdge? edge = parentEdges[curr];
      if (edge != null) {
        pathEdges.add(edge);
      }
      curr = parentNodes[curr]!;
    }
    final List<RoadEdge> orderedEdges = pathEdges.reversed.toList();

    final List<double>? startCoords = findNodeCoordinates(startNode);
    final double startLat = startCoords?[0] ?? origin.latitude;
    final double startLon = startCoords?[1] ?? origin.longitude;

    final List<List<double>> routeCoordinates = <List<double>>[
      <double>[origin.longitude, origin.latitude],
      <double>[startLon, startLat],
    ];

    double totalRoadDistance = distanceInMeters(
      origin.latitude,
      origin.longitude,
      startLat,
      startLon,
    );
    double totalTravelSeconds = 0;

    for (final RoadEdge edge in orderedEdges) {
      totalRoadDistance += edge.distanceMeters;

      final double speedMps = switch (travelMode) {
        TravelMode.driving => math.max(edge.speedKmh * 1000 / 3600, 5.0),
        TravelMode.cycling => 15000 / 3600,
        TravelMode.walking => 5000 / 3600,
      };
      totalTravelSeconds += edge.distanceMeters / speedMps;

      if (edge.encodedPolyline.isNotEmpty) {
        final List<List<double>> intermediate =
            decodePolyline(edge.encodedPolyline);
        final Iterable<List<double>> directedPoints =
            edge.isReversed ? intermediate.reversed : intermediate;
        routeCoordinates.addAll(directedPoints);
      }

      final List<double>? targetCoords = findNodeCoordinates(edge.targetNode);
      if (targetCoords != null) {
        routeCoordinates.add(<double>[targetCoords[1], targetCoords[0]]);
      }
    }

    totalRoadDistance += distanceInMeters(
      endLat,
      endLon,
      destination.latitude,
      destination.longitude,
    );
    routeCoordinates.add(<double>[destination.longitude, destination.latitude]);

    final int estimatedMinutes =
        (totalTravelSeconds / 60).round().clamp(1, 1 << 30);
    final double bearing = bearingInDegrees(
      origin.latitude,
      origin.longitude,
      startLat,
      startLon,
    );

    return RouteSummary(
      distanceMeters: totalRoadDistance,
      estimatedMinutes: estimatedMinutes,
      travelMode: travelMode,
      bearingDegrees: bearing,
      cardinalDirection: cardinalDirectionFromDegrees(bearing),
      isArrived: false,
      isOfflineFallback: true,
      isFromCache: false,
      routeCoordinates: routeCoordinates,
    );
  }
}

class _HeapItem {
  const _HeapItem(this.node, this.priority);
  final int node;
  final double priority;
}

class _MinHeap {
  final List<_HeapItem> _items = <_HeapItem>[];

  bool get isNotEmpty => _items.isNotEmpty;

  void add(int node, double priority) {
    _items.add(_HeapItem(node, priority));
    _bubbleUp(_items.length - 1);
  }

  _HeapItem removeFirst() {
    final _HeapItem top = _items[0];
    final _HeapItem last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _sinkDown(0);
    }
    return top;
  }

  void _bubbleUp(int index) {
    int i = index;
    while (i > 0) {
      final int parent = (i - 1) >> 1;
      if (_items[i].priority < _items[parent].priority) {
        final _HeapItem tmp = _items[i];
        _items[i] = _items[parent];
        _items[parent] = tmp;
        i = parent;
      } else {
        break;
      }
    }
  }

  void _sinkDown(int index) {
    int i = index;
    final int len = _items.length;
    while (true) {
      int smallest = i;
      final int left = (i << 1) + 1;
      final int right = left + 1;

      if (left < len && _items[left].priority < _items[smallest].priority) {
        smallest = left;
      }
      if (right < len && _items[right].priority < _items[smallest].priority) {
        smallest = right;
      }

      if (smallest != i) {
        final _HeapItem tmp = _items[i];
        _items[i] = _items[smallest];
        _items[smallest] = tmp;
        i = smallest;
      } else {
        break;
      }
    }
  }
}
