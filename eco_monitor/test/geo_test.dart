import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/utils/geo.dart";


// Tests -------------------------------------------------------------------- //


void main() {
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
}
