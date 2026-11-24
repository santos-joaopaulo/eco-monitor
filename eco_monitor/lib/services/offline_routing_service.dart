import "dart:convert";
import "dart:io";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

import "../models/collection_point.dart";
import "../services/location_service.dart";
import "../utils/geo.dart";
import "../utils/polyline_codec.dart";
import "route_service.dart";


// Constants ---------------------------------------------------------------- //


/// Máscaras binárias para os modais de transporte suportados.
const int kModeDriving = 1;
const int kModeCycling = 2;
const int kModeWalking = 4;

/// Margem máxima em graus para validar se uma coordenada pertence à Região Metropolitana de Aracaju.
const double kAracajuBoundingMarginDegrees = 0.04;

/// Distância máxima aceitável em metros para conectar um ponto GPS à via navegável mais próxima.
const double kMaxSnapDistanceMeters = 3000.0;

/// Caminho padrão do ativo empacotado da malha viária OSM de Aracaju.
const String kDefaultRoadNetworkAssetPath =
    "assets/data/aracaju_road_network.json";


// Types ------------------------------------------------------------------- //


/// Exceção lançada quando coordenadas estão fora da cobertura da malha de Aracaju.
class OfflineRoutingOutOfBoundsException implements Exception {
  const OfflineRoutingOutOfBoundsException([
    this.message = "Coordenadas fora da cobertura de Aracaju.",
  ]);

  final String message;

  @override
  String toString() => "OfflineRoutingOutOfBoundsException: $message";
}

/// Representa uma aresta direcionada no grafo viário da cidade.
class RoadEdge {
  const RoadEdge({
    required this.sourceNode,
    required this.targetNode,
    required this.distanceMeters,
    required this.modesMask,
    required this.speedKmh,
    required this.encodedPolyline,
    this.isReversed = false,
  });

  final int sourceNode;
  final int targetNode;
  final double distanceMeters;
  final int modesMask;
  final int speedKmh;
  final String encodedPolyline;
  final bool isReversed;
}

/// Item de fila de prioridade para a busca A*.
class _HeapItem {
  const _HeapItem(this.node, this.priority);

  final int node;
  final double priority;
}

/// Min-heap binário de alta performance para A*.
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

/// Índice espacial em grade (Spatial Hash Grid) para busca em tempo constante O(1).
class _GridSpatialIndex {
  _GridSpatialIndex({
    required this.minLat,
    required this.minLon,
    required this.cellSize,
  });

  final double minLat;
  final double minLon;
  final double cellSize;

  final Map<int, List<int>> _grid = <int, List<int>>{};

  int _hash(int row, int col) => (row * 73856093) ^ (col * 19349663);

  void insert(int nodeIndex, double lat, double lon) {
    final int row = ((lat - minLat) / cellSize).floor();
    final int col = ((lon - minLon) / cellSize).floor();
    final int key = _hash(row, col);
    (_grid[key] ??= <int>[]).add(nodeIndex);
  }

  int findNearestNode(
    double lat,
    double lon,
    Float64List nodeLats,
    Float64List nodeLons, {
    double maxDistanceMeters = kMaxSnapDistanceMeters,
  }) {
    final int centerRow = ((lat - minLat) / cellSize).floor();
    final int centerCol = ((lon - minLon) / cellSize).floor();

    double bestDist = double.infinity;
    int bestNode = -1;

    // Busca em espiral nos quadrantes adjacentes (raio de 3 células ~ 1.5km)
    const int maxRadius = 3;
    for (int r = 0; r <= maxRadius; r++) {
      for (int dr = -r; dr <= r; dr++) {
        for (int dc = -r; dc <= r; dc++) {
          if (dr.abs() != r && dc.abs() != r) {
            continue;
          }
          final int key = _hash(centerRow + dr, centerCol + dc);
          final List<int>? cellNodes = _grid[key];
          if (cellNodes == null) {
            continue;
          }

          for (final int node in cellNodes) {
            final double dist = distanceInMeters(
              lat,
              lon,
              nodeLats[node],
              nodeLons[node],
            );
            if (dist < bestDist) {
              bestDist = dist;
              bestNode = node;
            }
          }
        }
      }
      if (bestDist < r * cellSize * 111000) {
        break;
      }
    }

    if (bestDist <= maxDistanceMeters) {
      return bestNode;
    }

    // Se não encontrou nas células próximas, varredura de fallback
    for (int i = 0; i < nodeLats.length; i++) {
      final double dist = distanceInMeters(
        lat,
        lon,
        nodeLats[i],
        nodeLons[i],
      );
      if (dist < bestDist) {
        bestDist = dist;
        bestNode = i;
      }
    }

    return bestDist <= maxDistanceMeters ? bestNode : -1;
  }
}


// Classes ----------------------------------------------------------------- //


/// Grafo viário OSM em memória para cálculo de caminhos mínimos offline.
class OfflineRoadGraph {
  OfflineRoadGraph({
    required this.bbox,
    required this.nodeLats,
    required this.nodeLons,
    required this.adjacency,
  }) {
    _initSpatialIndex();
  }

  /// Limites geográficos: [minLat, minLon, maxLat, maxLon].
  final List<double> bbox;

  /// Latitudes de todos os nós de interseção.
  final Float64List nodeLats;

  /// Longitudes de todos os nós de interseção.
  final Float64List nodeLons;

  /// Lista de adjacência direcionada.
  final List<List<RoadEdge>> adjacency;

  late final _GridSpatialIndex _spatialIndex;

  int get nodeCount => nodeLats.length;

  void _initSpatialIndex() {
    _spatialIndex = _GridSpatialIndex(
      minLat: bbox[0],
      minLon: bbox[1],
      cellSize: 0.005, // ~550 metros por quadrícula
    );

    for (int i = 0; i < nodeLats.length; i++) {
      _spatialIndex.insert(i, nodeLats[i], nodeLons[i]);
    }
  }

  /// Verifica se uma coordenada pertence ao escopo metropolitano de Aracaju.
  bool isWithinCoverage(double lat, double lon) {
    final double minLat = bbox[0] - kAracajuBoundingMarginDegrees;
    final double minLon = bbox[1] - kAracajuBoundingMarginDegrees;
    final double maxLat = bbox[2] + kAracajuBoundingMarginDegrees;
    final double maxLon = bbox[3] + kAracajuBoundingMarginDegrees;

    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  /// Localiza o nó da malha viária mais próximo de uma coordenada geográfica.
  int findNearestNode(
    double lat,
    double lon, {
    double maxDistanceMeters = kMaxSnapDistanceMeters,
  }) {
    return _spatialIndex.findNearestNode(
      lat,
      lon,
      nodeLats,
      nodeLons,
      maxDistanceMeters: maxDistanceMeters,
    );
  }

  /// Constrói uma instância de [OfflineRoadGraph] a partir de uma String JSON.
  factory OfflineRoadGraph.fromJsonString(String jsonContent) {
    final Map<String, dynamic> root =
        jsonDecode(jsonContent) as Map<String, dynamic>;

    final List<dynamic> rawBbox = root["bbox"] as List<dynamic>;
    final List<double> bbox = rawBbox
        .map((dynamic v) => (v as num).toDouble())
        .toList(growable: false);

    final List<dynamic> rawNodes = root["nodes"] as List<dynamic>;
    final int count = rawNodes.length;
    final Float64List nodeLats = Float64List(count);
    final Float64List nodeLons = Float64List(count);

    for (int i = 0; i < count; i++) {
      final List<dynamic> pair = rawNodes[i] as List<dynamic>;
      nodeLats[i] = (pair[0] as num).toDouble();
      nodeLons[i] = (pair[1] as num).toDouble();
    }

    final List<List<RoadEdge>> adjacency =
        List<List<RoadEdge>>.generate(count, (_) => <RoadEdge>[]);

    final List<dynamic> rawEdges = root["edges"] as List<dynamic>;
    for (final dynamic item in rawEdges) {
      final List<dynamic> list = item as List<dynamic>;
      final int u = list[0] as int;
      final int v = list[1] as int;
      final int modes = list[2] as int;
      final int speed = list[3] as int;
      final int direction = list[4] as int;
      final String polyline = list[5] as String;
      final double distance = (list[6] as num).toDouble();

      // Sentido normal ou bidirecional (u -> v)
      if (direction == 0 || direction == 1) {
        adjacency[u].add(
          RoadEdge(
            sourceNode: u,
            targetNode: v,
            distanceMeters: distance,
            modesMask: modes,
            speedKmh: speed,
            encodedPolyline: polyline,
            isReversed: false,
          ),
        );
      }

      // Sentido reverso ou bidirecional (v -> u)
      if (direction == 0 || direction == 2) {
        adjacency[v].add(
          RoadEdge(
            sourceNode: v,
            targetNode: u,
            distanceMeters: distance,
            modesMask: modes,
            speedKmh: speed,
            encodedPolyline: polyline,
            isReversed: true,
          ),
        );
      }
    }

    return OfflineRoadGraph(
      bbox: bbox,
      nodeLats: nodeLats,
      nodeLons: nodeLons,
      adjacency: adjacency,
    );
  }
}

/// Motor de navegação viária offline nativo de alta precisão (Abordagem B).
class OfflineRoutingService {
  OfflineRoutingService({
    OfflineRoadGraph? roadGraph,
    AssetBundle? assetBundle,
    this.assetPath = kDefaultRoadNetworkAssetPath,
  })  : _bundle = assetBundle {
    _roadGraph = roadGraph;
  }

  OfflineRoadGraph? _roadGraph;
  final AssetBundle? _bundle;
  final String assetPath;

  bool get isLoaded => _roadGraph != null;

  static OfflineRoutingService? _defaultInstance;

  /// Instância singleton padrão do serviço de roteamento offline.
  static OfflineRoutingService get instance =>
      _defaultInstance ??= OfflineRoutingService();

  @visibleForTesting
  static set instance(OfflineRoutingService? custom) {
    _defaultInstance = custom;
  }

  /// Garante que o grafo viário de Aracaju esteja carregado em memória.
  Future<OfflineRoadGraph> ensureLoaded() async {
    final OfflineRoadGraph? existing = _roadGraph;
    if (existing != null) {
      return existing;
    }

    String? content;
    final AssetBundle? bundle = _bundle;
    if (bundle != null) {
      content = await bundle.loadString(assetPath);
    } else {
      try {
        final File localFile = File(assetPath);
        if (localFile.existsSync()) {
          content = localFile.readAsStringSync();
        }
      } catch (_) {}

      content ??= await rootBundle.loadString(assetPath);
    }

    final OfflineRoadGraph graph = OfflineRoadGraph.fromJsonString(content);
    _roadGraph = graph;
    return graph;
  }

  /// Executa o cálculo de menor caminho A* respeitando curvatura, mão única e pontes.
  Future<RouteSummary?> findRoute({
    required UserLocation origin,
    required CollectionPoint destination,
    TravelMode travelMode = TravelMode.walking,
  }) async {
    final OfflineRoadGraph graph = await ensureLoaded();

    // 1. Validação de cobertura geográfica na Região Metropolitana de Aracaju
    if (!graph.isWithinCoverage(origin.latitude, origin.longitude) ||
        !graph.isWithinCoverage(destination.latitude, destination.longitude)) {
      throw const OfflineRoutingOutOfBoundsException(
        "As coordenadas informadas estão fora da cobertura viária de Aracaju.",
      );
    }

    // 2. Mapeamento dos pontos nos nós viários mais próximos
    final int startNode = graph.findNearestNode(
      origin.latitude,
      origin.longitude,
    );
    final int endNode = graph.findNearestNode(
      destination.latitude,
      destination.longitude,
    );

    if (startNode == -1 || endNode == -1) {
      return null;
    }

    final double directDestDistance = distanceInMeters(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    final bool arrived = directDestDistance <= kArrivalThresholdMeters;
    if (arrived || startNode == endNode) {
      final double bearing = bearingInDegrees(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
      return RouteSummary(
        distanceMeters: arrived ? 0 : directDestDistance,
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

    // 3. Execução do algoritmo A* com min-heap
    final int targetModeMask = switch (travelMode) {
      TravelMode.driving => kModeDriving,
      TravelMode.cycling => kModeCycling,
      TravelMode.walking => kModeWalking,
    };

    final int nodeCount = graph.nodeCount;
    final Float64List lats = graph.nodeLats;
    final Float64List lons = graph.nodeLons;

    final Float64List dists = Float64List(nodeCount)
      ..fillRange(0, nodeCount, double.infinity);
    final Int32List parentNodes = Int32List(nodeCount)
      ..fillRange(0, nodeCount, -1);
    final List<RoadEdge?> parentEdges = List<RoadEdge?>.filled(nodeCount, null);

    final _MinHeap heap = _MinHeap();
    dists[startNode] = 0;
    heap.add(startNode, 0);

    final double endLat = lats[endNode];
    final double endLon = lons[endNode];

    while (heap.isNotEmpty) {
      final _HeapItem item = heap.removeFirst();
      final int u = item.node;

      if (u == endNode) {
        break;
      }

      final double currentDist = dists[u];
      if (item.priority >
          currentDist +
              distanceInMeters(lats[u], lons[u], endLat, endLon) +
              1.0) {
        continue;
      }

      for (final RoadEdge edge in graph.adjacency[u]) {
        if ((edge.modesMask & targetModeMask) == 0) {
          continue;
        }

        final int v = edge.targetNode;
        final double tentativeDist = currentDist + edge.distanceMeters;

        if (tentativeDist < dists[v]) {
          dists[v] = tentativeDist;
          parentNodes[v] = u;
          parentEdges[v] = edge;

          final double heuristic = distanceInMeters(
            lats[v],
            lons[v],
            endLat,
            endLon,
          );
          heap.add(v, tentativeDist + heuristic);
        }
      }
    }

    // Se não encontrou caminho na malha viária para o destino
    if (parentNodes[endNode] == -1) {
      return null;
    }

    // 4. Reconstrução da geometria viária detalhada com curvas
    final List<RoadEdge> pathEdges = <RoadEdge>[];
    int curr = endNode;
    while (curr != startNode) {
      final RoadEdge? edge = parentEdges[curr];
      if (edge != null) {
        pathEdges.add(edge);
      }
      curr = parentNodes[curr];
    }
    final List<RoadEdge> orderedEdges = pathEdges.reversed.toList();

    final List<List<double>> routeCoordinates = <List<double>>[
      <double>[origin.longitude, origin.latitude],
      <double>[lons[startNode], lats[startNode]],
    ];

    double totalRoadDistance = distanceInMeters(
      origin.latitude,
      origin.longitude,
      lats[startNode],
      lons[startNode],
    );

    double totalTravelSeconds = 0;

    for (final RoadEdge edge in orderedEdges) {
      totalRoadDistance += edge.distanceMeters;

      // Cálculo de tempo por modalidade viária
      final double edgeSpeedMps = switch (travelMode) {
        TravelMode.driving => math.max(edge.speedKmh * 1000 / 3600, 5.0),
        TravelMode.cycling => 15000 / 3600,
        TravelMode.walking => 5000 / 3600,
      };
      totalTravelSeconds += edge.distanceMeters / edgeSpeedMps;

      // Expande todos os pontos intermediários da curva da rua
      if (edge.encodedPolyline.isNotEmpty) {
        final List<List<double>> intermediate =
            decodePolyline(edge.encodedPolyline);
        final Iterable<List<double>> directedPoints =
            edge.isReversed ? intermediate.reversed : intermediate;

        for (final List<double> pt in directedPoints) {
          routeCoordinates.add(pt);
        }
      }

      routeCoordinates.add(<double>[
        lons[edge.targetNode],
        lats[edge.targetNode],
      ]);
    }

    // Conecta o último nó viário ao ponto final do ecoponto
    totalRoadDistance += distanceInMeters(
      lats[endNode],
      lons[endNode],
      destination.latitude,
      destination.longitude,
    );
    routeCoordinates.add(<double>[destination.longitude, destination.latitude]);

    final int estimatedMinutes = (totalTravelSeconds / 60)
        .round()
        .clamp(1, 1 << 30);

    final double bearing = bearingInDegrees(
      origin.latitude,
      origin.longitude,
      lats[startNode],
      lons[startNode],
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
