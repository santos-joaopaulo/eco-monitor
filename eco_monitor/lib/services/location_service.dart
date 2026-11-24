import "dart:async";

import "package:geolocator/geolocator.dart";


// Enums -------------------------------------------------------------------- //


/// Resultado da verificação de permissão de localização, incluindo disponibilidade do serviço.
enum LocationPermissionState { granted, denied, deniedForever, serviceDisabled }


// Classes ------------------------------------------------------------------ //


/// Posição do dispositivo, mantida apenas em memória (nunca persistida).
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

/// Encapsulamento em torno do geolocator com regras de permissão e timeout do app (T2).
class LocationService {
  const LocationService({this.timeLimit = const Duration(seconds: 12)});

  final Duration timeLimit;


// Methods ------------------------------------------------------------------ //


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

  /// Retorna a posição atual, recorrendo à última conhecida quando
  /// o dispositivo não obtiver a localização dentro de [timeLimit].
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

  /// Emite atualizações contínuas de localização durante a navegação.
  Stream<UserLocation> positionStream({int distanceFilter = 5}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).map((Position position) {
      return UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      );
    });
  }

  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } on Exception {
      return false;
    }
  }
}


// Methods ------------------------------------------------------------------ //


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
