import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:material_ui/material_ui.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/route_cache_store.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/route_service.dart";
import "package:eco_monitor/utils/geo.dart";
import "package:eco_monitor/widgets/route_summary_card.dart";


void main() {
  group("RouteCacheStore", () {
    late InMemoryLocalStore localStore;
    late RouteCacheStore cacheStore;
    late DateTime now;

    setUp(() {
      localStore = InMemoryLocalStore();
      now = DateTime.utc(2026, 11, 23, 10, 0, 0);
      cacheStore = RouteCacheStore(
        localStore: localStore,
        maxEntries: 3,
        ttl: const Duration(hours: 24),
        clock: () => now,
      );
    });

    test("puts and retrieves route accurately with coordinate key tolerance", () async {
      await cacheStore.putRoute(
        originLat: -10.91000,
        originLon: -37.05000,
        destLat: -10.92000,
        destLon: -37.06000,
        travelMode: TravelMode.walking,
        distanceMeters: 1450,
        estimatedMinutes: 18,
        routeCoordinates: [
          [-37.05000, -10.91000],
          [-37.06000, -10.92000],
        ],
      );

      expect(await cacheStore.count(), equals(1));

      // Coordenada com variação de ~10 metros (abaixo da tolerância de ~25m)
      final CachedRoute? retrieved = await cacheStore.getRoute(
        originLat: -10.91008,
        originLon: -37.05005,
        destLat: -10.92005,
        destLon: -37.06008,
        travelMode: TravelMode.walking,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.distanceMeters, equals(1450));
      expect(retrieved.estimatedMinutes, equals(18));
      expect(retrieved.travelMode, equals(TravelMode.walking));
      expect(retrieved.routeCoordinates.length, equals(2));
    });

    test("expires route after TTL of 24 hours", () async {
      await cacheStore.putRoute(
        originLat: -10.9100,
        originLon: -37.0500,
        destLat: -10.9200,
        destLon: -37.0600,
        travelMode: TravelMode.walking,
        distanceMeters: 1000,
        estimatedMinutes: 12,
        routeCoordinates: [
          [-37.0500, -10.9100],
          [-37.0600, -10.9200],
        ],
      );

      // Avança o relógio em 23 horas (ainda válido)
      now = now.add(const Duration(hours: 23));
      final CachedRoute? valid = await cacheStore.getRoute(
        originLat: -10.9100,
        originLon: -37.0500,
        destLat: -10.9200,
        destLon: -37.0600,
        travelMode: TravelMode.walking,
      );
      expect(valid, isNotNull);

      // Avança o relógio além de 24 horas (expirado)
      now = now.add(const Duration(hours: 2));
      final CachedRoute? expired = await cacheStore.getRoute(
        originLat: -10.9100,
        originLon: -37.0500,
        destLat: -10.9200,
        destLon: -37.0600,
        travelMode: TravelMode.walking,
      );
      expect(expired, isNull);
      expect(await cacheStore.count(), equals(0));
    });

    test("evicts least recently used (LRU) entry when capacity exceeded", () async {
      // Insere 3 rotas (limite máximo é 3)
      now = DateTime.utc(2026, 11, 23, 10, 0);
      await cacheStore.putRoute(
        originLat: -10.1,
        originLon: -37.1,
        destLat: -10.2,
        destLon: -37.2,
        travelMode: TravelMode.walking,
        distanceMeters: 100,
        estimatedMinutes: 1,
        routeCoordinates: [],
      );

      now = DateTime.utc(2026, 11, 23, 10, 5);
      await cacheStore.putRoute(
        originLat: -10.3,
        originLon: -37.3,
        destLat: -10.4,
        destLon: -37.4,
        travelMode: TravelMode.walking,
        distanceMeters: 200,
        estimatedMinutes: 2,
        routeCoordinates: [],
      );

      now = DateTime.utc(2026, 11, 23, 10, 10);
      await cacheStore.putRoute(
        originLat: -10.5,
        originLon: -37.5,
        destLat: -10.6,
        destLon: -37.6,
        travelMode: TravelMode.walking,
        distanceMeters: 300,
        estimatedMinutes: 3,
        routeCoordinates: [],
      );

      expect(await cacheStore.count(), equals(3));

      // Acessa a rota 1 para renovar seu lastAccessedAt (agora a menos usada é a rota 2)
      now = DateTime.utc(2026, 11, 23, 10, 15);
      await cacheStore.getRoute(
        originLat: -10.1,
        originLon: -37.1,
        destLat: -10.2,
        destLon: -37.2,
        travelMode: TravelMode.walking,
      );

      // Insere uma 4ª rota: a rota 2 deve ser descartada pelo LRU
      now = DateTime.utc(2026, 11, 23, 10, 20);
      await cacheStore.putRoute(
        originLat: -10.7,
        originLon: -37.7,
        destLat: -10.8,
        destLon: -37.8,
        travelMode: TravelMode.walking,
        distanceMeters: 400,
        estimatedMinutes: 4,
        routeCoordinates: [],
      );

      expect(await cacheStore.count(), equals(3));

      // Rota 1 continua no cache
      expect(
        await cacheStore.getRoute(
          originLat: -10.1,
          originLon: -37.1,
          destLat: -10.2,
          destLon: -37.2,
          travelMode: TravelMode.walking,
        ),
        isNotNull,
      );

      // Rota 2 foi removida pelo LRU
      expect(
        await cacheStore.getRoute(
          originLat: -10.3,
          originLon: -37.3,
          destLat: -10.4,
          destLon: -37.4,
          travelMode: TravelMode.walking,
        ),
        isNull,
      );

      // Rota 4 está presente
      expect(
        await cacheStore.getRoute(
          originLat: -10.7,
          originLon: -37.7,
          destLat: -10.8,
          destLon: -37.8,
          travelMode: TravelMode.walking,
        ),
        isNotNull,
      );
    });

    test("RouteService uses cached route when available even without network", () async {
      final RouteService service = RouteService(
        cacheStore: cacheStore,
      );

      const UserLocation origin = UserLocation(
        latitude: -10.9100,
        longitude: -37.0500,
      );

      final CollectionPoint destination = CollectionPoint(
        id: "p1",
        name: "Farmácia Centro",
        type: PointType.pharmacy,
        latitude: -10.9200,
        longitude: -37.0600,
        address: "Rua das Flores, 123",
        acceptedWasteTypes: const {},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      );

      // Pré-popula o cache com rota viária
      await cacheStore.putRoute(
        originLat: origin.latitude,
        originLon: origin.longitude,
        destLat: destination.latitude,
        destLon: destination.longitude,
        travelMode: TravelMode.walking,
        distanceMeters: 1350,
        estimatedMinutes: 16,
        routeCoordinates: [
          [-37.0500, -10.9100],
          [-37.0550, -10.9150],
          [-37.0600, -10.9200],
        ],
      );

      // Chama fetchRoute em modo offline e sem token
      final RouteSummary summary = await service.fetchRoute(
        origin: origin,
        destination: destination,
        travelMode: TravelMode.walking,
        isOnline: false,
        accessToken: null,
      );

      // Deve ter retornado a rota do cache (não o fallback simplificado de 2 pontos)
      expect(summary.isOfflineFallback, isFalse);
      expect(summary.distanceMeters, equals(1350));
      expect(summary.estimatedMinutes, equals(16));
      expect(summary.routeCoordinates.length, equals(3));
    });

    test("RouteService caches successful Mapbox API responses", () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        final Map<String, dynamic> responseJson = {
          "code": "Ok",
          "routes": [
            {
              "distance": 1800.0,
              "duration": 1200.0,
              "geometry": {
                "type": "LineString",
                "coordinates": [
                  [-37.0500, -10.9100],
                  [-37.0550, -10.9150],
                  [-37.0600, -10.9200],
                ],
              },
            }
          ],
        };
        return http.Response(jsonEncode(responseJson), 200);
      });

      final RouteService service = RouteService(
        cacheStore: cacheStore,
        httpClient: mockClient,
      );

      const UserLocation origin = UserLocation(
        latitude: -10.9100,
        longitude: -37.0500,
      );

      final CollectionPoint destination = CollectionPoint(
        id: "p1",
        name: "Farmácia Centro",
        type: PointType.pharmacy,
        latitude: -10.9200,
        longitude: -37.0600,
        address: "Rua Centro",
        acceptedWasteTypes: const {},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      );

      final RouteSummary summary = await service.fetchRoute(
        origin: origin,
        destination: destination,
        travelMode: TravelMode.walking,
        isOnline: true,
        accessToken: "pk.fake_token",
      );

      expect(summary.isOfflineFallback, isFalse);
      expect(summary.distanceMeters, equals(1800.0));
      expect(summary.estimatedMinutes, equals(20));

      // Verifica se a rota foi gravada no cacheStore
      final CachedRoute? cached = await cacheStore.getRoute(
        originLat: origin.latitude,
        originLon: origin.longitude,
        destLat: destination.latitude,
        destLon: destination.longitude,
        travelMode: TravelMode.walking,
      );

      expect(cached, isNotNull);
      expect(cached!.distanceMeters, equals(1800.0));
      expect(cached.routeCoordinates.length, equals(3));
    });

    test("retrieves cached route with GPS drift across grid boundary (~60m)", () async {
      // Coordenada próxima da borda do bucket
      await cacheStore.putRoute(
        originLat: -10.950166,
        originLon: -37.060166,
        destLat: -10.92000,
        destLon: -37.06000,
        travelMode: TravelMode.walking,
        distanceMeters: 3300,
        estimatedMinutes: 40,
        routeCoordinates: [
          [-37.060166, -10.950166],
          [-37.06000, -10.92000],
        ],
      );

      // Nova posição do usuário com drift de ~60 metros (outro bucket de arredondamento)
      final CachedRoute? retrieved = await cacheStore.getRoute(
        originLat: -10.950700,
        originLon: -37.060166,
        destLat: -10.92000,
        destLon: -37.06000,
        travelMode: TravelMode.walking,
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.distanceMeters, equals(3300));
      expect(retrieved.estimatedMinutes, equals(40));
    });

    test("default RouteService automatically uses shared cache store when unmanaged", () async {
      RouteService.defaultStore = cacheStore;

      final RouteService service = RouteService();

      const UserLocation origin = UserLocation(
        latitude: -10.9100,
        longitude: -37.0500,
      );

      final CollectionPoint destination = CollectionPoint(
        id: "p1",
        name: "Ponto Teste",
        type: PointType.pharmacy,
        latitude: -10.9200,
        longitude: -37.0600,
        address: "Rua Teste",
        acceptedWasteTypes: const {},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      );

      await cacheStore.putRoute(
        originLat: origin.latitude,
        originLon: origin.longitude,
        destLat: destination.latitude,
        destLon: destination.longitude,
        travelMode: TravelMode.walking,
        distanceMeters: 2100,
        estimatedMinutes: 25,
        routeCoordinates: [
          [-37.0500, -10.9100],
          [-37.0600, -10.9200],
        ],
      );

      final RouteSummary summary = await service.fetchRoute(
        origin: origin,
        destination: destination,
        travelMode: TravelMode.walking,
        isOnline: false,
      );

      expect(summary.isOfflineFallback, isFalse);
      expect(summary.isFromCache, isTrue);
      expect(summary.distanceMeters, equals(2100));
      expect(summary.routeCoordinates.length, equals(2));
    });

    testWidgets("RouteSummaryCard displays cache recovery feedback badge", (
      WidgetTester tester,
    ) async {
      const RouteSummary cachedSummary = RouteSummary(
        distanceMeters: 1400,
        estimatedMinutes: 18,
        travelMode: TravelMode.walking,
        isOfflineFallback: false,
        isFromCache: true,
        routeCoordinates: [
          [-37.0500, -10.9100],
          [-37.0600, -10.9200],
        ],
      );

      final CollectionPoint point = CollectionPoint(
        id: "p1",
        name: "Ecoponto Bairro Industrial",
        type: PointType.ecoPoint,
        latitude: -10.9200,
        longitude: -37.0600,
        address: "Av. Industrial",
        acceptedWasteTypes: const {},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteSummaryCard(
              point: point,
              summary: cachedSummary,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(
        find.text("Rota viária recuperada do cache local"),
        findsOneWidget,
      );
      expect(
        find.text("Navegação disponível sem internet com base no trajeto salvo."),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.offline_pin_rounded), findsOneWidget);
    });
  });
}
