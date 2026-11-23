import "package:flutter/foundation.dart";

import "../../services/location_service.dart";


// Notifiers --------------------------------------------------------------- //


/// Gerenciador de estado reativo para a geolocalização do usuário (Presentation).
class LocationNotifier extends ChangeNotifier {
  LocationNotifier({
    LocationService? locationService,
  }) : _locationService = locationService ?? const LocationService();

  final LocationService _locationService;

  UserLocation? _userLocation;
  LocationPermissionState? _permissionState;
  bool _isLocating = false;
  bool _locationFailed = false;

  UserLocation? get userLocation => _userLocation;

  LocationPermissionState? get permissionState => _permissionState;

  bool get isLocating => _isLocating;

  bool get locationFailed => _locationFailed;

  bool get hasLocation => _userLocation != null;


  // Methods --------------------------------------------------------------- //


  /// Verifica a permissão atual de geolocalização do dispositivo.
  Future<void> checkPermission() async {
    final LocationPermissionState state =
        await _locationService.currentPermission();
    _permissionState = state;
    if (state != LocationPermissionState.granted) {
      _locationFailed = false;
    }
    notifyListeners();
  }

  /// Requisita permissão e obtém a posição atual do usuário sob demanda.
  Future<UserLocation?> locateUser() async {
    _isLocating = true;
    _locationFailed = false;
    notifyListeners();

    try {
      final LocationPermissionState permission =
          await _locationService.requestPermission();
      _permissionState = permission;

      if (permission != LocationPermissionState.granted) {
        _isLocating = false;
        notifyListeners();
        return null;
      }

      final UserLocation? location = await _locationService.currentPosition();
      _isLocating = false;
      if (location != null) {
        _userLocation = location;
        _locationFailed = false;
      } else {
        _locationFailed = true;
      }
      notifyListeners();
      return location;
    } catch (_) {
      _isLocating = false;
      _locationFailed = true;
      notifyListeners();
      return null;
    }
  }

  /// Abre a tela nativa de configurações do sistema.
  Future<void> openSettings() async {
    await _locationService.openAppSettings();
  }

  /// Define manualmente a localização do usuário (útil para testes ou mocks).
  void setUserLocation(UserLocation? location) {
    _userLocation = location;
    notifyListeners();
  }
}
