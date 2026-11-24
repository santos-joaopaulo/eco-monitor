import "dart:io";

import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/route_cache_store.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/offline_routing_service.dart";
import "package:eco_monitor/services/route_service.dart";
import "package:eco_monitor/utils/geo.dart";
import "package:eco_monitor/utils/polyline_codec.dart";


// Helpers ------------------------------------------------------------------ //


CollectionPoint _buildPoint({
  required String id,
  required String name,
  required double latitude,
  required double longitude,
}) {
  return CollectionPoint(
    id: id,
    name: name,
    type: PointType.ecoPoint,
    latitude: latitude,
    longitude: longitude,
    address: "Aracaju - SE",
    acceptedWasteTypes: const <WasteType>{WasteType.electronics},
    hours: "Seg a sex, 8h às 17h",
    status: PointStatus.active,
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final OfflineRoutingService offlineService;

  setUpAll(() async {
    // Carrega o arquivo do grafo compilado diretamente para testes
    final String jsonContent =
        await File("assets/data/aracaju_road_network.json").readAsString();
    final OfflineRoadGraph graph = OfflineRoadGraph.fromJsonString(jsonContent);
    offlineService = OfflineRoutingService(roadGraph: graph);
    OfflineRoutingService.instance = offlineService;
    RouteService.defaultOfflineService = offlineService;
  });

  group("PolylineCodec — Codificação e Decodificação de Curvas", () {
    test("codifica e decodifica polilinha preservando fidelidade submétrica", () {
      final List<List<double>> originalCoords = <List<double>>[
        <double>[-37.05001, -10.91002],
        <double>[-37.05153, -10.91234],
        <double>[-37.05321, -10.91456],
      ];

      final String encoded = encodePolyline(originalCoords);
      expect(encoded, isNotEmpty);

      final List<List<double>> decoded = decodePolyline(encoded);
      expect(decoded.length, originalCoords.length);

      for (int i = 0; i < originalCoords.length; i++) {
        expect(decoded[i][0], closeTo(originalCoords[i][0], 1e-4));
        expect(decoded[i][1], closeTo(originalCoords[i][1], 1e-4));
      }
    });

    test("trata strings vazias graciosamente", () {
      expect(decodePolyline(""), isEmpty);
      expect(encodePolyline(const <List<double>>[]), "");
    });
  });

  group("OfflineRoadGraph — Topologia Viária e Indexação Espacial", () {
    test("valida limites de cobertura da Região Metropolitana de Aracaju", () async {
      final OfflineRoadGraph graph = await offlineService.ensureLoaded();

      // Pontos dentro da Grande Aracaju
      expect(graph.isWithinCoverage(-10.91, -37.05), isTrue); // Centro
      expect(graph.isWithinCoverage(-10.97, -37.07), isTrue); // Farolândia
      expect(graph.isWithinCoverage(-10.90, -37.03), isTrue); // Barra dos Coqueiros

      // Pontos fora da cobertura
      expect(graph.isWithinCoverage(51.5074, -0.1278), isFalse); // Londres
      expect(graph.isWithinCoverage(-15.7938, -47.8827), isFalse); // Brasília
    });

    test("localiza nós viários em tempo constante com Spatial Hash Grid", () async {
      final OfflineRoadGraph graph = await offlineService.ensureLoaded();

      final Stopwatch sw = Stopwatch()..start();
      final int nearest = graph.findNearestNode(-10.9116, -37.0528);
      sw.stop();

      expect(nearest, isNot(-1));
      expect(sw.elapsedMilliseconds, lessThan(20));
    });
  });

  group("OfflineRoutingService — Rotas Conhecidas de Aracaju (Abordagem B)", () {
    test("calcula rota entre 13 de Julho e Santos Dumont com curvas reais", () async {
      const UserLocation user13DeJulho = UserLocation(
        latitude: -10.9350,
        longitude: -37.0500,
      );
      final CollectionPoint ecopontoSantosDumont = _buildPoint(
        id: "santos_dumont",
        name: "Ecoponto Santos Dumont",
        latitude: -10.8911,
        longitude: -37.0789,
      );

      // Aquecimento de JIT prévio para medição precisa de tempo de execução
      await offlineService.findRoute(
        origin: user13DeJulho,
        destination: ecopontoSantosDumont,
        travelMode: TravelMode.driving,
      );

      final Stopwatch sw = Stopwatch()..start();
      final RouteSummary? summary = await offlineService.findRoute(
        origin: user13DeJulho,
        destination: ecopontoSantosDumont,
        travelMode: TravelMode.driving,
      );
      sw.stop();

      expect(summary, isNotNull);
      expect(sw.elapsedMilliseconds, lessThan(100)); // Critério de <100ms
      expect(summary!.isOfflineFallback, isTrue);

      // Distância viária real deve ser de ~7.5 a ~9 km
      expect(summary.distanceMeters, greaterThan(7000));
      expect(summary.distanceMeters, lessThan(10000));

      // Deve conter múltiplos pontos intermediários seguindo as curvas urbanas
      expect(summary.routeCoordinates.length, greaterThan(100));

      // Início e fim nas coordenadas esperadas
      expect(summary.routeCoordinates.first[0], closeTo(-37.0500, 1e-4));
      expect(summary.routeCoordinates.first[1], closeTo(-10.9350, 1e-4));
      expect(summary.routeCoordinates.last[0], closeTo(-37.0789, 1e-4));
      expect(summary.routeCoordinates.last[1], closeTo(-10.8911, 1e-4));
    });

    test("calcula rota entre Farolândia (UBS Augusto Franco) e Centro", () async {
      const UserLocation ubsFarolandia = UserLocation(
        latitude: -10.9688,
        longitude: -37.0710,
      );
      final CollectionPoint centroPoint = _buildPoint(
        id: "centro_point",
        name: "Casas Bahia — Centro",
        latitude: -10.9098,
        longitude: -37.0491,
      );

      final Stopwatch sw = Stopwatch()..start();
      final RouteSummary? summary = await offlineService.findRoute(
        origin: ubsFarolandia,
        destination: centroPoint,
        travelMode: TravelMode.driving,
      );
      sw.stop();

      expect(summary, isNotNull);
      expect(sw.elapsedMilliseconds, lessThan(100));
      expect(summary!.distanceMeters, greaterThan(7000));
      expect(summary.routeCoordinates.length, greaterThan(100));
    });

    test("compara tempos de deslocamento entre os modais de transporte", () async {
      const UserLocation origin = UserLocation(
        latitude: -10.9350,
        longitude: -37.0500,
      );
      final CollectionPoint dest = _buildPoint(
        id: "dest_point",
        name: "Drogasil — Luzia",
        latitude: -10.9291,
        longitude: -37.0660,
      );

      final RouteSummary? driving = await offlineService.findRoute(
        origin: origin,
        destination: dest,
        travelMode: TravelMode.driving,
      );

      final RouteSummary? cycling = await offlineService.findRoute(
        origin: origin,
        destination: dest,
        travelMode: TravelMode.cycling,
      );

      final RouteSummary? walking = await offlineService.findRoute(
        origin: origin,
        destination: dest,
        travelMode: TravelMode.walking,
      );

      expect(driving, isNotNull);
      expect(cycling, isNotNull);
      expect(walking, isNotNull);

      // Veículo deve ser mais rápido que bicicleta, e bicicleta mais rápida que a pé
      expect(driving!.estimatedMinutes, lessThanOrEqualTo(cycling!.estimatedMinutes));
      expect(cycling.estimatedMinutes, lessThan(walking!.estimatedMinutes));
    });

    test("lança OfflineRoutingOutOfBoundsException para coordenadas fora da cobertura", () async {
      const UserLocation outOfBounds = UserLocation(
        latitude: 51.5074,
        longitude: -0.1278,
      );
      final CollectionPoint localPoint = _buildPoint(
        id: "local_pague_menos",
        name: "Pague Menos",
        latitude: -10.9116,
        longitude: -37.0528,
      );

      expect(
        () => offlineService.findRoute(
          origin: outOfBounds,
          destination: localPoint,
        ),
        throwsA(isA<OfflineRoutingOutOfBoundsException>()),
      );
    });
  });

  group("Validação Crítica Viária — Transposição Exclusiva pelas Pontes Reais", () {
    test("Barra dos Coqueiros para Centro: atravessa exclusivamente pela Ponte Construtor João Alves", () async {
      const UserLocation barraDosCoqueiros = UserLocation(
        latitude: -10.9060,
        longitude: -37.0340,
      );
      final CollectionPoint centroPoint = _buildPoint(
        id: "centro",
        name: "Farmácia Centro",
        latitude: -10.9100,
        longitude: -37.0500,
      );

      final RouteSummary? summary = await offlineService.findRoute(
        origin: barraDosCoqueiros,
        destination: centroPoint,
        travelMode: TravelMode.driving,
      );

      expect(summary, isNotNull);
      final List<List<double>> coords = summary!.routeCoordinates;

      // Canal do Rio Sergipe entre Barra dos Coqueiros e Aracaju
      // Longitude entre -37.049 e -37.036, Latitude entre -10.920 e -10.880
      final List<List<double>> riverCrossingPoints = coords.where((List<double> pt) {
        final double lon = pt[0];
        final double lat = pt[1];
        return lon >= -37.049 && lon <= -37.036 && lat >= -10.920 && lat <= -10.880;
      }).toList();

      // Confirma que a rota de fato cruzou o rio
      expect(riverCrossingPoints, isNotEmpty);

      // Envelope geográfico estrito da Ponte Construtor João Alves
      // Latitude entre -10.898 e -10.893
      final List<List<double>> outsideBridgeViolations =
          riverCrossingPoints.where((List<double> pt) {
        final double lat = pt[1];
        return !(lat >= -10.898 && lat <= -10.893);
      }).toList();

      // NENHUM ponto pode atravessar a água fora da Ponte João Alves!
      expect(
        outsideBridgeViolations,
        isEmpty,
        reason: "Pontos cruzando o Rio Sergipe fora da Ponte Construtor João Alves: $outsideBridgeViolations",
      );
    });

    test("Coroa do Meio para 13 de Julho: atravessa exclusivamente pelas pontes do Rio Poxim", () async {
      const UserLocation coroaDoMeio = UserLocation(
        latitude: -10.9622,
        longitude: -37.0425,
      );
      final CollectionPoint point13DeJulho = _buildPoint(
        id: "point_13_julho",
        name: "Ponto 13 de Julho",
        latitude: -10.9350,
        longitude: -37.0500,
      );

      final RouteSummary? summary = await offlineService.findRoute(
        origin: coroaDoMeio,
        destination: point13DeJulho,
        travelMode: TravelMode.driving,
      );

      expect(summary, isNotNull);
      final List<List<double>> coords = summary!.routeCoordinates;

      // Canal da foz do Rio Poxim entre 13 de Julho e Coroa do Meio
      // Longitude entre -37.0505 e -37.0475, Latitude entre -10.960 e -10.938
      final List<List<double>> riverChannelPoints = coords.where((List<double> pt) {
        final double lon = pt[0];
        final double lat = pt[1];
        return lon >= -37.0505 && lon <= -37.0475 && lat >= -10.960 && lat <= -10.938;
      }).toList();

      expect(riverChannelPoints, isNotEmpty);

      // Envelopes das pontes autorizadas sobre este trecho:
      // 1. Ponte da Coroa do Meio (Av. Delmiro Gouveia): [-10.944, -10.939]
      // 2. Ponte Godofredo Diniz (Av. Paulo VI): [-10.959, -10.954]
      final List<List<double>> outsidePoximBridges =
          riverChannelPoints.where((List<double> pt) {
        final double lat = pt[1];
        final bool onCoroaBridge = lat >= -10.944 && lat <= -10.939;
        final bool onGodofredoBridge = lat >= -10.959 && lat <= -10.954;
        return !onCoroaBridge && !onGodofredoBridge;
      }).toList();

      expect(
        outsidePoximBridges,
        isEmpty,
        reason: "Pontos cruzando o Rio Poxim fora das pontes reais: $outsidePoximBridges",
      );
    });
  });

  group("Integração Completa RouteService com OfflineRoutingService", () {
    test("fetchRoute delega para o motor offline nativo e armazena em cache", () async {
      final RouteCacheStore testCache = RouteCacheStore(
        localStore: InMemoryLocalStore(),
      );
      final RouteService service = RouteService(
        cacheStore: testCache,
        offlineRoutingService: offlineService,
      );

      const UserLocation userFarolandia = UserLocation(
        latitude: -10.9688,
        longitude: -37.0710,
      );
      final CollectionPoint centro = _buildPoint(
        id: "centro_target",
        name: "Centro",
        latitude: -10.9098,
        longitude: -37.0491,
      );

      // 1. Chamada offline
      final RouteSummary firstSummary = await service.fetchRoute(
        origin: userFarolandia,
        destination: centro,
        travelMode: TravelMode.driving,
        isOnline: false,
      );

      expect(firstSummary.isOfflineFallback, isTrue);
      expect(firstSummary.isFromCache, isFalse);
      expect(firstSummary.distanceMeters, greaterThan(7000));
      expect(firstSummary.routeCoordinates.length, greaterThan(100));

      // 2. Segunda chamada idêntica deve ser servida diretamente do cache local
      final RouteSummary secondSummary = await service.fetchRoute(
        origin: userFarolandia,
        destination: centro,
        travelMode: TravelMode.driving,
        isOnline: false,
      );

      expect(secondSummary.isFromCache, isTrue);
      expect(secondSummary.distanceMeters, firstSummary.distanceMeters);
      expect(secondSummary.routeCoordinates.length, firstSummary.routeCoordinates.length);
    });
  });
}
