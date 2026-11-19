import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/route_service.dart";


// Helpers ------------------------------------------------------------------ //


CollectionPoint buildPoint({
  double latitude = -10.95,
  double longitude = -37.067,
  String name = "Farmácia São Paulo",
}) {
  return CollectionPoint(
    id: "point-1",
    name: name,
    type: PointType.pharmacy,
    latitude: latitude,
    longitude: longitude,
    address: "Rua de teste, 1",
    acceptedWasteTypes: const <WasteType>{WasteType.medicines},
    hours: "Seg a sex, 8h às 18h",
    status: PointStatus.active,
  );
}

const UserLocation user = UserLocation(latitude: -10.95, longitude: -37.067);


// Tests -------------------------------------------------------------------- //


void main() {
  const RouteService service = RouteService();

  group("buildRouteSummary", () {
    test("computes distance and walking time from the user position", () {
      final RouteSummary summary = service.buildRouteSummary(
        user,
        buildPoint(latitude: -10.945),
      );

      expect(summary.distanceMeters, closeTo(556, 2));
      expect(summary.estimatedMinutes, 7);
    });

    test("returns zero time when the user is at the point", () {
      final RouteSummary summary = service.buildRouteSummary(
        user,
        buildPoint(),
      );

      expect(summary.distanceMeters, 0);
      expect(summary.estimatedMinutes, 0);
    });
  });

  group("buildNavigationUri", () {
    test("uses a geo URI on Android", () {
      final Uri uri = service.buildNavigationUri(
        buildPoint(),
        platform: TargetPlatform.android,
      );

      expect(uri.scheme, "geo");
      expect(uri.path, "-10.95,-37.067");
      expect(uri.queryParameters["q"], contains("Farmácia São Paulo"));
    });

    test("uses Apple Maps on iOS", () {
      final Uri uri = service.buildNavigationUri(
        buildPoint(),
        platform: TargetPlatform.iOS,
      );

      expect(uri.scheme, "https");
      expect(uri.host, "maps.apple.com");
      expect(uri.queryParameters["daddr"], "-10.95,-37.067");
      expect(uri.queryParameters["q"], "Farmácia São Paulo");
    });

    test("falls back to Google Maps on other platforms", () {
      final Uri uri = service.buildNavigationUri(
        buildPoint(),
        platform: TargetPlatform.linux,
      );

      expect(uri.scheme, "https");
      expect(uri.host, "www.google.com");
      expect(uri.queryParameters["destination"], "-10.95,-37.067");
    });
  });

  group("openNavigation", () {
    test("launches the built URI and reports success", () async {
      Uri? launched;
      final RouteService custom = RouteService(
        launcher: (Uri uri) async {
          launched = uri;
          return true;
        },
      );

      final bool opened = await custom.openNavigation(
        buildPoint(),
        platform: TargetPlatform.android,
      );

      expect(opened, isTrue);
      expect(launched?.scheme, "geo");
    });

    test("returns false when the launcher fails", () async {
      final RouteService custom = RouteService(
        launcher: (Uri uri) async => false,
      );

      final bool opened = await custom.openNavigation(
        buildPoint(),
        platform: TargetPlatform.android,
      );

      expect(opened, isFalse);
    });
  });
}
