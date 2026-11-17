import "dart:async";

import "package:geolocator/geolocator.dart";

// Enums ------------------------------------------------------------------- //

/// Result of a location permission check, including service availability.
enum LocationPermissionState { granted, denied, deniedForever, serviceDisabled }

// Classes ----------------------------------------------------------------- //

/// Position of the device, kept in memory only (never persisted).
class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
}

/// Thin wrapper around geolocator with the permission and timeout rules of
/// the app (T2).
class LocationService {
  const LocationService({this.timeLimit = const Duration(seconds: 12)});

  final Duration timeLimit;

  // Methods --------------------------------------------------------------- //

  Future<LocationPermissionState> currentPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationPermissionState.serviceDisabled;
      }

      return _mapPermission(await Geolocator.checkPermission());
    } on Exception {
      return LocationPermissionState.denied;
    }
  }

  Future<LocationPermissionState> requestPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationPermissionState.serviceDisabled;
      }

      return _mapPermission(await Geolocator.requestPermission());
    } on Exception {
      return LocationPermissionState.denied;
    }
  }

  /// Returns the current position, falling back to the last known one when
  /// the device does not provide a fix within [timeLimit].
  Future<UserLocation?> currentPosition() async {
    UserLocation? lastKnown;

    try {
      final Position? position = await Geolocator.getLastKnownPosition();
      lastKnown = _toUserLocation(position);
    } on Exception {
      lastKnown = null;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );

      return _toUserLocation(position);
    } on TimeoutException {
      return lastKnown;
    } on LocationServiceDisabledException {
      return null;
    } on Exception {
      return lastKnown;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } on Exception {
      return false;
    }
  }
}

// Methods ----------------------------------------------------------------- //

LocationPermissionState _mapPermission(LocationPermission permission) {
  return switch (permission) {
    LocationPermission.always ||
    LocationPermission.whileInUse => LocationPermissionState.granted,
    LocationPermission.deniedForever => LocationPermissionState.deniedForever,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => LocationPermissionState.denied,
  };
}

UserLocation? _toUserLocation(Position? position) {
  if (position == null) {
    return null;
  }

  return UserLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
  );
}
