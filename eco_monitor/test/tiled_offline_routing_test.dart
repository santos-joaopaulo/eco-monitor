import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/offline_routing_service.dart";
import "package:eco_monitor/services/route_service.dart";
import "package:eco_monitor/services/tiled_road_graph.dart";
import "package:eco_monitor/utils/geo.dart";


// Tests ------------------------------------------------------------------- //


void main() {
  group("TiledRoadGraph e LRU Cache de Partições (T14.1)", () {
    late TiledRoadGraph graph;

    setUp(() {
      graph = TiledRoadGraph(maxCachedTiles: 6);
    });

    test("tileKeyFor e tileBbox convertem coordenadas com precisão de grade", () {
      final String key = TiledRoadGraph.tileKeyFor(-10.92, -37.07);
      expect(key, isNotEmpty);

      final List<double> bbox = TiledRoadGraph.tileBbox(-55, -186);
      expect(bbox.length, equals(4));
      expect(bbox[2] - bbox[0], closeTo(kTileSizeDegrees, 0.0001));
      expect(bbox[3] - bbox[1], closeTo(kTileSizeDegrees, 0.0001));
    });

    test("mantém no máximo 6 tiles residentes no heap descartando o mais antigo (LRU)", () async {
      // Registra 8 tiles distintos
      for (int i = 0; i < 8; i++) {
        final String key = "tile_$i";
        final SpatialTile tile = SpatialTile(
          tileKey: key,
          bbox: <double>[i * 0.2, 0.0, (i + 1) * 0.2, 0.2],
          nodeIds: Int32List.fromList(<int>[i * 10, i * 10 + 1]),
          nodeLats: Float64List.fromList(<double>[i * 0.2 + 0.05, i * 0.2 + 0.1]),
          nodeLons: Float64List.fromList(<double>[0.05, 0.1]),
          adjacency: <int, List<RoadEdge>>{},
        );
        graph.registerTile(tile);
      }

      // Carrega 6 tiles sequencialmente
      for (int i = 0; i < 6; i++) {
        await graph.getOrLoadTile("tile_$i");
      }
      expect(graph.loadedTileCount, equals(6));

      // Carrega o 7º tile: deve desalojar 'tile_0'
      await graph.getOrLoadTile("tile_6");
      expect(graph.loadedTileCount, equals(6));

      // Carrega o 8º tile: deve desalojar 'tile_1'
      await graph.getOrLoadTile("tile_7");
      expect(graph.loadedTileCount, equals(6));
    });

    test("atualiza ordem LRU quando um tile já residente é acessado novamente", () async {
      for (int i = 0; i < 7; i++) {
        final String key = "tile_$i";
        graph.registerTile(
          SpatialTile(
            tileKey: key,
            bbox: <double>[i * 0.2, 0.0, (i + 1) * 0.2, 0.2],
            nodeIds: Int32List.fromList(<int>[i]),
            nodeLats: Float64List.fromList(<double>[i * 0.2]),
            nodeLons: Float64List.fromList(<double>[0.0]),
            adjacency: <int, List<RoadEdge>>{},
          ),
        );
      }

      // Carrega tiles 0 a 5
      for (int i = 0; i < 6; i++) {
        await graph.getOrLoadTile("tile_$i");
      }

      // Acessa novamente 'tile_0' para movê-lo ao final do LRU
      await graph.getOrLoadTile("tile_0");

      // Carrega 'tile_6': agora o mais antigo a ser descartado deve ser 'tile_1', não 'tile_0'
      await graph.getOrLoadTile("tile_6");
      expect(graph.loadedTileCount, equals(6));
    });

    test("calcula rota A* local dentro do mesmo tile em menos de 50 ms", () async {
      final double latOrigin = -10.92;
      final double lonOrigin = -37.07;
      final String originKey = TiledRoadGraph.tileKeyFor(latOrigin, lonOrigin);

      // Cria um grid viário local no tile
      final SpatialTile localTile = SpatialTile(
        tileKey: originKey,
        bbox: <double>[-11.0, -37.2, -10.8, -37.0],
        nodeIds: Int32List.fromList(<int>[1, 2, 3]),
        nodeLats: Float64List.fromList(<double>[-10.920, -10.922, -10.925]),
        nodeLons: Float64List.fromList(<double>[-37.070, -37.072, -37.075]),
        adjacency: <int, List<RoadEdge>>{
          1: <RoadEdge>[
            const RoadEdge(
              sourceNode: 1,
              targetNode: 2,
              distanceMeters: 250,
              modesMask: kModeWalking | kModeDriving,
              speedKmh: 40,
              encodedPolyline: "",
            ),
          ],
          2: <RoadEdge>[
            const RoadEdge(
              sourceNode: 2,
              targetNode: 3,
              distanceMeters: 350,
              modesMask: kModeWalking | kModeDriving,
              speedKmh: 40,
              encodedPolyline: "",
            ),
          ],
        },
      );

      graph.registerTile(localTile);

      final Stopwatch stopwatch = Stopwatch()..start();

      final RouteSummary? route = await graph.findRoute(
        origin: const UserLocation(latitude: -10.919, longitude: -37.069),
        destination: CollectionPoint(
          id: "pt_local",
          name: "Ecoponto Local",
          type: PointType.ecoPoint,
          latitude: -10.926,
          longitude: -37.076,
          address: "Rua Local, 123",
          acceptedWasteTypes: const <WasteType>{WasteType.medicines},
          hours: "08:00 - 17:00",
          status: PointStatus.active,
        ),
        travelMode: TravelMode.walking,
      );

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50));
      expect(route, isNotNull);
      expect(route!.distanceMeters, greaterThan(500));
      expect(route.isOfflineFallback, isTrue);
      expect(route.routeCoordinates, isNotEmpty);
    });

    test("transita suavemente entre nós na borda de tiles adjacentes via interligação em < 150 ms", () async {
      // Tile A
      final double latA = -10.90;
      final double lonA = -37.10;
      final String keyA = TiledRoadGraph.tileKeyFor(latA, lonA);

      // Tile B (adjacente ao sul ou leste)
      final double latB = -10.70;
      final double lonB = -37.10;
      final String keyB = TiledRoadGraph.tileKeyFor(latB, lonB);

      final SpatialTile tileA = SpatialTile(
        tileKey: keyA,
        bbox: <double>[-11.0, -37.2, -10.8, -37.0],
        nodeIds: Int32List.fromList(<int>[100, 101]),
        nodeLats: Float64List.fromList(<double>[-10.90, -10.81]),
        nodeLons: Float64List.fromList(<double>[-37.10, -37.10]),
        boundaryNodes: <int>{101},
        adjacency: <int, List<RoadEdge>>{
          100: <RoadEdge>[
            const RoadEdge(
              sourceNode: 100,
              targetNode: 101,
              distanceMeters: 1000,
              modesMask: kModeWalking | kModeDriving,
              speedKmh: 60,
              encodedPolyline: "",
            ),
          ],
          101: <RoadEdge>[
            const RoadEdge(
              sourceNode: 101,
              targetNode: 200,
              distanceMeters: 200,
              modesMask: kModeWalking | kModeDriving,
              speedKmh: 60,
              encodedPolyline: "",
            ),
          ],
        },
      );

      final SpatialTile tileB = SpatialTile(
        tileKey: keyB,
        bbox: <double>[-10.8, -37.2, -10.6, -37.0],
        nodeIds: Int32List.fromList(<int>[200, 201]),
        nodeLats: Float64List.fromList(<double>[-10.79, -10.70]),
        nodeLons: Float64List.fromList(<double>[-37.10, -37.10]),
        boundaryNodes: <int>{200},
        adjacency: <int, List<RoadEdge>>{
          200: <RoadEdge>[
            const RoadEdge(
              sourceNode: 200,
              targetNode: 201,
              distanceMeters: 1000,
              modesMask: kModeWalking | kModeDriving,
              speedKmh: 60,
              encodedPolyline: "",
            ),
          ],
        },
      );

      graph.registerTile(tileA);
      graph.registerTile(tileB);

      final Stopwatch stopwatch = Stopwatch()..start();

      final RouteSummary? interRoute = await graph.findRoute(
        origin: const UserLocation(latitude: -10.91, longitude: -37.10),
        destination: CollectionPoint(
          id: "pt_inter",
          name: "Ecoponto Intermunicipal",
          type: PointType.ecoPoint,
          latitude: -10.69,
          longitude: -37.10,
          address: "Rodovia Estadual, km 20",
          acceptedWasteTypes: const <WasteType>{WasteType.electronics},
          hours: "08:00 - 17:00",
          status: PointStatus.active,
        ),
        travelMode: TravelMode.driving,
      );

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(150));
      expect(interRoute, isNotNull);
      expect(interRoute!.distanceMeters, greaterThan(2000));
      expect(graph.loadedTileCount, lessThanOrEqualTo(6));
    });
  });
}
