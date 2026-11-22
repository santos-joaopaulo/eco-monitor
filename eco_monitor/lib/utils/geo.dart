import "dart:math" as math;

import "package:flutter/material.dart";


// Constants ---------------------------------------------------------------- //


/// Raio médio da Terra em metros, usado pela fórmula de haversine.
const double kEarthRadiusInMeters = 6371000;

/// Fator multiplicador de desvio urbano a pé/veicular em relação à distância direta.
const double kUrbanDetourFactor = 1.30;


// Enums ------------------------------------------------------------------- //


/// Modos de transporte disponíveis para o cálculo e traçado da rota.
enum TravelMode {
  walking,
  cycling,
  driving;

  String get mapboxProfile => switch (this) {
    TravelMode.walking => "mapbox/walking",
    TravelMode.cycling => "mapbox/cycling",
    TravelMode.driving => "mapbox/driving",
  };

  /// Velocidade média estimada em metros por segundo para estimativas locais.
  double get speedMetersPerSecond => switch (this) {
    TravelMode.walking => 5000 / 3600, // 5 km/h
    TravelMode.cycling => 15000 / 3600, // 15 km/h
    TravelMode.driving => 30000 / 3600, // 30 km/h (urbano com paradas)
  };

  String get label => switch (this) {
    TravelMode.walking => "A pé",
    TravelMode.cycling => "Bicicleta",
    TravelMode.driving => "Carro",
  };

  IconData get icon => switch (this) {
    TravelMode.walking => Icons.directions_walk_rounded,
    TravelMode.cycling => Icons.directions_bike_rounded,
    TravelMode.driving => Icons.directions_car_rounded,
  };
}


// Methods ----------------------------------------------------------------- //


/// Distância ortodrômica em metros entre duas coordenadas geográficas.
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

/// Azimute geográfico inicial em graus (0° a 360°) do ponto 1 para o ponto 2.
double bearingInDegrees(double lat1, double lon1, double lat2, double lon2) {
  final double phi1 = _toRadians(lat1);
  final double phi2 = _toRadians(lat2);
  final double deltaLambda = _toRadians(lon2 - lon1);

  final double y = math.sin(deltaLambda) * math.cos(phi2);
  final double x =
      math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

  final double theta = math.atan2(y, x);
  return (theta * 180 / math.pi + 360) % 360;
}

/// Converte o azimute em graus para a direção cardeal correspondente em português.
String cardinalDirectionFromDegrees(double degrees) {
  final double normalized = (degrees % 360 + 360) % 360;

  if (normalized >= 337.5 || normalized < 22.5) {
    return "Norte";
  }
  if (normalized < 67.5) {
    return "Nordeste";
  }
  if (normalized < 112.5) {
    return "Leste";
  }
  if (normalized < 157.5) {
    return "Sudeste";
  }
  if (normalized < 202.5) {
    return "Sul";
  }
  if (normalized < 247.5) {
    return "Sudoeste";
  }
  if (normalized < 292.5) {
    return "Oeste";
  }
  return "Noroeste";
}

double _toRadians(double degrees) => degrees * math.pi / 180;
