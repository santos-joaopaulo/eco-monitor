import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/utils/geo.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  group("distanceInMeters", () {
    test("distance between equal coordinates is zero", () {
      expect(distanceInMeters(-10.95, -37.067, -10.95, -37.067), 0);
    });

    test("one hundredth of a degree of latitude is about 1112 m", () {
      final double distance = distanceInMeters(0, 0, 0.01, 0);

      expect(distance, closeTo(1112, 1));
    });

    test(
      "one hundredth of a degree of longitude at the equator is about 1112 m",
      () {
        final double distance = distanceInMeters(0, 0, 0, 0.01);

        expect(distance, closeTo(1112, 1));
      },
    );

    test("Aracaju coordinates match a known distance", () {
      // 0,01 grau de latitude entre dois pontos em Aracaju.
      final double distance = distanceInMeters(-10.95, -37.067, -10.96, -37.067);

      expect(distance, closeTo(1112, 1));
    });

    test("distance is symmetric", () {
      final double forward = distanceInMeters(-10.95, -37.067, -10.91, -37.04);
      final double backward = distanceInMeters(-10.91, -37.04, -10.95, -37.067);

      expect(forward, closeTo(backward, 0.001));
    });
  });

  group("bearingInDegrees", () {
    test("identifies due north as 0 degrees", () {
      final double bearing = bearingInDegrees(0, 0, 1, 0);
      expect(bearing, closeTo(0, 0.1));
    });

    test("identifies due east as 90 degrees", () {
      final double bearing = bearingInDegrees(0, 0, 0, 1);
      expect(bearing, closeTo(90, 0.1));
    });

    test("identifies due south as 180 degrees", () {
      final double bearing = bearingInDegrees(1, 0, 0, 0);
      expect(bearing, closeTo(180, 0.1));
    });

    test("identifies due west as 270 degrees", () {
      final double bearing = bearingInDegrees(0, 1, 0, 0);
      expect(bearing, closeTo(270, 0.1));
    });
  });

  group("cardinalDirectionFromDegrees", () {
    test("maps all 8 cardinal quadrants correctly", () {
      expect(cardinalDirectionFromDegrees(0), "Norte");
      expect(cardinalDirectionFromDegrees(10), "Norte");
      expect(cardinalDirectionFromDegrees(45), "Nordeste");
      expect(cardinalDirectionFromDegrees(90), "Leste");
      expect(cardinalDirectionFromDegrees(135), "Sudeste");
      expect(cardinalDirectionFromDegrees(180), "Sul");
      expect(cardinalDirectionFromDegrees(225), "Sudoeste");
      expect(cardinalDirectionFromDegrees(270), "Oeste");
      expect(cardinalDirectionFromDegrees(315), "Noroeste");
      expect(cardinalDirectionFromDegrees(355), "Norte");
    });
  });

  group("TravelMode", () {
    test("has valid mapbox profiles and positive speeds", () {
      expect(TravelMode.walking.mapboxProfile, "mapbox/walking");
      expect(TravelMode.cycling.mapboxProfile, "mapbox/cycling");
      expect(TravelMode.driving.mapboxProfile, "mapbox/driving");

      expect(TravelMode.walking.label, "A pé");
      expect(TravelMode.cycling.label, "Bicicleta");
      expect(TravelMode.driving.label, "Carro");

      expect(TravelMode.walking.speedMetersPerSecond, closeTo(1.38, 0.01));
      expect(TravelMode.cycling.speedMetersPerSecond, closeTo(4.16, 0.01));
      expect(TravelMode.driving.speedMetersPerSecond, closeTo(8.33, 0.01));
    });
  });
}
