import "dart:math" as math;

// Constants ---------------------------------------------------------------- //

/// Mean Earth radius in meters, used by the haversine formula.
const double kEarthRadiusInMeters = 6371000;

// Methods ----------------------------------------------------------------- //

/// Great-circle distance in meters between two geographic coordinates.
double distanceInMeters(double lat1, double lon1, double lat2, double lon2) {
  final double deltaLat = _toRadians(lat2 - lat1);
  final double deltaLon = _toRadians(lon2 - lon1);

  final double sinLat = math.sin(deltaLat / 2);
  final double sinLon = math.sin(deltaLon / 2);

  final double a =
      sinLat * sinLat +
      math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * sinLon * sinLon;

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return kEarthRadiusInMeters * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;
