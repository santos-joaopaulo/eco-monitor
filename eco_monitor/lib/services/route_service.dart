import "package:flutter/foundation.dart";
import "package:url_launcher/url_launcher.dart";

import "../models/collection_point.dart";
import "../services/location_service.dart";
import "../utils/geo.dart";

// Constants ---------------------------------------------------------------- //

/// Average walking speed used for the route estimate (5 km/h).
const double kWalkingSpeedMetersPerSecond = 5000 / 3600;

// Types ------------------------------------------------------------------- //

/// Approximate route information shown to the user.
class RouteSummary {
  const RouteSummary({
    required this.distanceMeters,
    required this.estimatedMinutes,
  });

  final double distanceMeters;
  final int estimatedMinutes;
}

typedef UriLauncher = Future<bool> Function(Uri uri);

// Classes ----------------------------------------------------------------- //

/// Builds the route estimate and the external navigation URI (RF04).
class RouteService {
  const RouteService({this.launcher});

  final UriLauncher? launcher;

  // Methods --------------------------------------------------------------- //

  RouteSummary buildRouteSummary(
    UserLocation userPosition,
    CollectionPoint point,
  ) {
    final double distance = distanceInMeters(
      userPosition.latitude,
      userPosition.longitude,
      point.latitude,
      point.longitude,
    );

    final double minutes = distance / kWalkingSpeedMetersPerSecond / 60;
    final int estimatedMinutes = distance > 0
        ? minutes.round().clamp(1, 1 << 30)
        : 0;

    return RouteSummary(
      distanceMeters: distance,
      estimatedMinutes: estimatedMinutes,
    );
  }

  Uri buildNavigationUri(CollectionPoint point, {TargetPlatform? platform}) {
    final TargetPlatform target = platform ?? defaultTargetPlatform;
    final String coordinates = "${point.latitude},${point.longitude}";

    return switch (target) {
      TargetPlatform.android => Uri(
        scheme: "geo",
        path: coordinates,
        queryParameters: <String, String>{"q": "$coordinates(${point.name})"},
      ),
      TargetPlatform.iOS => Uri.https("maps.apple.com", "/", <String, String>{
        "daddr": coordinates,
        "q": point.name,
      }),
      _ => Uri.https("www.google.com", "/maps/dir/", <String, String>{
        "api": "1",
        "destination": coordinates,
      }),
    };
  }

  Future<bool> openNavigation(
    CollectionPoint point, {
    TargetPlatform? platform,
  }) async {
    final Uri uri = buildNavigationUri(point, platform: platform);

    try {
      final UriLauncher? currentLauncher = launcher;
      if (currentLauncher != null) {
        return await currentLauncher(uri);
      }

      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
