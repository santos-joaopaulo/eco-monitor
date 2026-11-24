import "package:flutter_test/flutter_test.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/utils/geo.dart";
import "package:eco_monitor/utils/spatial_index.dart";


void main() {
  group("SpatialIndex & SpatialBounds", () {
    test("SpatialBounds from circle computes appropriate bounding box", () {
      const double centerLat = -10.9472;
      const double centerLon = -37.0731;
      const double radiusMeters = 5000; // 5 km

      final SpatialBounds bounds = SpatialBounds.fromCircle(
        centerLat: centerLat,
        centerLon: centerLon,
        radiusMeters: radiusMeters,
      );

      // O centro deve estar estritamente contido
      expect(bounds.contains(centerLat, centerLon), isTrue);

      // Ponto a 1 km ao norte deve estar contido
      final double lat1kmNorth = centerLat + (1000 / 111139.0);
      expect(bounds.contains(lat1kmNorth, centerLon), isTrue);

      // Ponto a 10 km ao sul deve estar fora
      final double lat10kmSouth = centerLat - (10000 / 111139.0);
      expect(bounds.contains(lat10kmSouth, centerLon), isFalse);
    });

    test("SpatialIndex correctly indexes and queries points within 5 km radius", () {
      final SpatialIndex<Map<String, dynamic>> index =
          SpatialIndex<Map<String, dynamic>>(
        getLatitude: (Map<String, dynamic> item) => item["lat"] as double,
        getLongitude: (Map<String, dynamic> item) => item["lon"] as double,
      );

      // Aracaju Centro
      const double userLat = -10.9095;
      const double userLon = -37.0505;

      // Ponto A: ~1.2 km de distância (dentro dos 5 km)
      final Map<String, dynamic> pointA = {
        "id": "A",
        "lat": -10.9180,
        "lon": -37.0560,
      };

      // Ponto B: ~3.8 km de distância (dentro dos 5 km)
      final Map<String, dynamic> pointB = {
        "id": "B",
        "lat": -10.9400,
        "lon": -37.0650,
      };

      // Ponto C: ~7.5 km de distância (fora dos 5 km, dentro de 10 km)
      final Map<String, dynamic> pointC = {
        "id": "C",
        "lat": -10.9700,
        "lon": -37.0800,
      };

      // Ponto D: ~25 km de distância (fora de 10 km)
      final Map<String, dynamic> pointD = {
        "id": "D",
        "lat": -10.7000,
        "lon": -37.1500,
      };

      index.load([pointA, pointB, pointC, pointD]);
      expect(index.size, equals(4));

      // Consulta com raio padrão de 5 km (5.000 m)
      final List<Map<String, dynamic>> in5km = index.queryRadius(
        latitude: userLat,
        longitude: userLon,
        radiusMeters: 5000,
      );

      final List<String> in5kmIds = in5km.map((p) => p["id"] as String).toList();
      expect(in5kmIds, containsAll(["A", "B"]));
      expect(in5kmIds, isNot(contains("C")));
      expect(in5kmIds, isNot(contains("D")));

      // Consulta com raio de 10 km (10.000 m)
      final List<Map<String, dynamic>> in10km = index.queryRadius(
        latitude: userLat,
        longitude: userLon,
        radiusMeters: 10000,
      );
      final List<String> in10kmIds = in10km.map((p) => p["id"] as String).toList();
      expect(in10kmIds, containsAll(["A", "B", "C"]));
      expect(in10kmIds, isNot(contains("D")));

      // Consulta com raio de 2 km (2.000 m)
      final List<Map<String, dynamic>> in2km = index.queryRadius(
        latitude: userLat,
        longitude: userLon,
        radiusMeters: 2000,
      );
      final List<String> in2kmIds = in2km.map((p) => p["id"] as String).toList();
      expect(in2kmIds, contains("A"));
      expect(in2kmIds, isNot(contains("B")));
    });

    test("SpatialIndex k-nearest neighbors returns points ordered by proximity", () {
      final SpatialIndex<String> index = SpatialIndex<String>(
        getLatitude: (String item) => double.parse(item.split(",")[0]),
        getLongitude: (String item) => double.parse(item.split(",")[1]),
      );

      // Ponto de origem
      const double originLat = -10.9100;
      const double originLon = -37.0500;

      final List<String> points = [
        "-10.9300,-37.0500", // ~2.2 km
        "-10.9150,-37.0500", // ~0.55 km (mais próximo)
        "-10.9500,-37.0500", // ~4.4 km
        "-10.9200,-37.0500", // ~1.1 km
      ];

      index.load(points);

      final List<String> nearest2 = index.nearestNeighbors(
        latitude: originLat,
        longitude: originLon,
        k: 2,
      );

      expect(nearest2.length, equals(2));
      expect(nearest2[0], equals("-10.9150,-37.0500"));
      expect(nearest2[1], equals("-10.9200,-37.0500"));
    });

    test("CollectionPointSpatialIndex indexes collection points correctly", () {
      final CollectionPoint point1 = CollectionPoint(
        id: "p1",
        name: "Ponto Centro",
        type: PointType.pharmacy,
        latitude: -10.9100,
        longitude: -37.0500,
        address: "Rua A",
        acceptedWasteTypes: const {},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      );

      final CollectionPoint point2 = CollectionPoint(
        id: "p2",
        name: "Ponto Distante",
        type: PointType.ecoPoint,
        latitude: -10.9900,
        longitude: -37.1000,
        address: "Rua B",
        acceptedWasteTypes: const {},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      );

      final CollectionPointSpatialIndex spatialIndex =
          CollectionPointSpatialIndex(initialPoints: [point1, point2]);

      expect(spatialIndex.size, equals(2));

      final List<CollectionPoint> results = spatialIndex.queryRadius(
        latitude: -10.9110,
        longitude: -37.0510,
        radiusMeters: 1000,
      );

      expect(results.length, equals(1));
      expect(results.first.id, equals("p1"));
    });

    test("ProximityRadius enum provides consistent values and next expansion", () {
      expect(ProximityRadius.twoKm.meters, equals(2000.0));
      expect(ProximityRadius.fiveKm.meters, equals(5000.0));
      expect(ProximityRadius.tenKm.meters, equals(10000.0));
      expect(ProximityRadius.unlimited.meters, isNull);

      expect(ProximityRadius.twoKm.expandNext, equals(ProximityRadius.fiveKm));
      expect(ProximityRadius.fiveKm.expandNext, equals(ProximityRadius.tenKm));
      expect(ProximityRadius.tenKm.expandNext, equals(ProximityRadius.unlimited));
      expect(ProximityRadius.unlimited.expandNext, equals(ProximityRadius.unlimited));
    });

    test("Benchmark/Performance: SpatialIndex query vs linear scan", () {
      final SpatialIndex<int> index = SpatialIndex<int>(
        getLatitude: (int i) => -10.9 + (i % 50) * 0.005,
        getLongitude: (int i) => -37.0 + (i ~/ 50) * 0.005,
      );

      // Carrega 250 pontos no índice
      final List<int> items = List.generate(250, (i) => i);
      index.load(items);

      const double searchLat = -10.85;
      const double searchLon = -36.95;
      const double radius = 3000;

      // Executa consulta no índice espacial
      final Stopwatch spatialWatch = Stopwatch()..start();
      final List<int> spatialMatches = index.queryRadius(
        latitude: searchLat,
        longitude: searchLon,
        radiusMeters: radius,
      );
      spatialWatch.stop();

      // Executa varredura linear tradicional
      final Stopwatch linearWatch = Stopwatch()..start();
      final List<int> linearMatches = [];
      for (final int i in items) {
        final double lat = -10.9 + (i % 50) * 0.005;
        final double lon = -37.0 + (i ~/ 50) * 0.005;
        if (distanceInMeters(searchLat, searchLon, lat, lon) <= radius) {
          linearMatches.add(i);
        }
      }
      linearWatch.stop();

      // Os resultados devem ser identicamente precisos
      expect(spatialMatches.toSet(), equals(linearMatches.toSet()));
    });
  });
}
