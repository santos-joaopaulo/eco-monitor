import "dart:convert";

import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";

import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/route_service.dart";
import "package:eco_monitor/utils/geo.dart";


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
    test("computes distance with urban factor and walking time", () {
      final RouteSummary summary = service.buildRouteSummary(
        user,
        buildPoint(latitude: -10.945),
      );

      expect(summary.distanceMeters, closeTo(723, 3));
      expect(summary.estimatedMinutes, 9);
      expect(summary.cardinalDirection, "Norte");
      expect(summary.isArrived, isFalse);
      expect(summary.isOfflineFallback, isTrue);
    });

    test("computes faster time for cycling and driving modes", () {
      final RouteSummary cycling = service.buildRouteSummary(
        user,
        buildPoint(latitude: -10.945),
        travelMode: TravelMode.cycling,
      );
      expect(cycling.estimatedMinutes, 3);

      final RouteSummary driving = service.buildRouteSummary(
        user,
        buildPoint(latitude: -10.945),
        travelMode: TravelMode.driving,
      );
      expect(driving.estimatedMinutes, 1);
    });

    test("identifies arrival when the user is within 25 meters", () {
      final RouteSummary summary = service.buildRouteSummary(
        user,
        buildPoint(),
      );

      expect(summary.distanceMeters, 0);
      expect(summary.estimatedMinutes, 0);
      expect(summary.isArrived, isTrue);
    });
  });

  group("buildUpdatedSummary", () {
    test("updates metrics and coordinates dynamically on position change", () {
      final RouteSummary initial = service.buildRouteSummary(
        user,
        buildPoint(latitude: -10.945),
      );

      final RouteSummary updated = service.buildUpdatedSummary(
        const UserLocation(latitude: -10.946, longitude: -37.067),
        buildPoint(latitude: -10.945),
        TravelMode.walking,
        previousSummary: initial,
      );

      expect(updated.distanceMeters, lessThan(initial.distanceMeters));
      expect(updated.cardinalDirection, "Norte");
      expect(updated.isArrived, isFalse);
    });
  });

  group("fetchRoute", () {
    test("returns online geometry and metrics when API succeeds", () async {
      final MockClient client = MockClient((http.Request request) async {
        expect(request.url.path, contains("mapbox/walking"));
        expect(request.url.queryParameters["access_token"], "valid-token");

        final Map<String, dynamic> responseJson = <String, dynamic>{
          "code": "Ok",
          "routes": <dynamic>[
            <String, dynamic>{
              "distance": 850.5,
              "duration": 600.0,
              "geometry": <String, dynamic>{
                "type": "LineString",
                "coordinates": <dynamic>[
                  <dynamic>[-37.067, -10.95],
                  <dynamic>[-37.066, -10.948],
                  <dynamic>[-37.067, -10.945],
                ],
              },
            },
          ],
        };

        return http.Response(jsonEncode(responseJson), 200);
      });

      final RouteSummary summary = await service.fetchRoute(
        origin: user,
        destination: buildPoint(latitude: -10.945),
        travelMode: TravelMode.walking,
        isOnline: true,
        accessToken: "valid-token",
        client: client,
      );

      expect(summary.isOfflineFallback, isFalse);
      expect(summary.distanceMeters, 850.5);
      expect(summary.estimatedMinutes, 10);
      expect(summary.routeCoordinates.length, 3);
    });

    test("falls back to offline estimation when API responds with error", () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response("Internal Server Error", 500);
      });

      final RouteSummary summary = await service.fetchRoute(
        origin: user,
        destination: buildPoint(latitude: -10.945),
        travelMode: TravelMode.walking,
        isOnline: true,
        accessToken: "valid-token",
        client: client,
      );

      expect(summary.isOfflineFallback, isTrue);
      expect(summary.distanceMeters, closeTo(723, 3));
      expect(summary.estimatedMinutes, 9);
      expect(summary.routeCoordinates.length, 2);
    });

    test("falls back immediately when device is offline", () async {
      final RouteSummary summary = await service.fetchRoute(
        origin: user,
        destination: buildPoint(latitude: -10.945),
        travelMode: TravelMode.walking,
        isOnline: false,
        accessToken: "valid-token",
      );

      expect(summary.isOfflineFallback, isTrue);
      expect(summary.distanceMeters, closeTo(723, 3));
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
