import "waste_type.dart";


// Enums -------------------------------------------------------------------- //


/// Tipo de estabelecimento que recebe os resíduos.
enum PointType { pharmacy, healthCenter, ecoPoint }

/// Indica se o ponto está recebendo resíduos no momento.
enum PointStatus { active, inactive }


// Classes ------------------------------------------------------------------ //


/// Um ponto de coleta exibido no mapa da tela inicial (Entidade de Domínio).
class CollectionPoint {
  CollectionPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    required Set<WasteType> acceptedWasteTypes,
    required this.hours,
    required this.status,
  }) : acceptedWasteTypes = Set<WasteType>.unmodifiable(acceptedWasteTypes);

  final String id;
  final String name;
  final PointType type;
  final double latitude;
  final double longitude;
  final String address;
  final Set<WasteType> acceptedWasteTypes;
  final String hours;
  final PointStatus status;

  bool get isActive => status == PointStatus.active;

  bool accepts(WasteType wasteType) => acceptedWasteTypes.contains(wasteType);

  bool acceptsAny(Set<WasteType> wasteTypes) {
    return wasteTypes.isEmpty ||
        wasteTypes.any((WasteType type) => accepts(type));
  }


// Methods ------------------------------------------------------------------ //


  /// Constrói um ponto a partir de JSON, tolerando campos ausentes e valores desconhecidos.
  factory CollectionPoint.fromJson(Map<String, dynamic> json) {
    final Set<WasteType> wasteTypes = wasteTypesFromJson(
      json["acceptedWasteTypes"],
    );

    return CollectionPoint(
      id: _asString(json["id"]),
      name: _asString(json["name"]),
      type: _pointTypeByName(_asString(json["type"])),
      latitude: _asDouble(json["latitude"]),
      longitude: _asDouble(json["longitude"]),
      address: _asString(json["address"]),
      acceptedWasteTypes: wasteTypes,
      hours: _asString(json["hours"]),
      status: _pointStatusByName(_asString(json["status"])),
    );
  }

  Map<String, dynamic> toJson() {
    final List<String> wasteTypes =
        acceptedWasteTypes.map((WasteType type) => type.name).toList()..sort();

    return {
      "id": id,
      "name": name,
      "type": type.name,
      "latitude": latitude,
      "longitude": longitude,
      "address": address,
      "acceptedWasteTypes": wasteTypes,
      "hours": hours,
      "status": status.name,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is CollectionPoint && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => "CollectionPoint($id, $name)";
}


// Methods ------------------------------------------------------------------ //


PointType _pointTypeByName(String name) {
  for (final PointType type in PointType.values) {
    if (type.name == name) {
      return type;
    }
  }

  return PointType.ecoPoint;
}

PointStatus _pointStatusByName(String name) {
  for (final PointStatus status in PointStatus.values) {
    if (status.name == name) {
      return status;
    }
  }

  return PointStatus.inactive;
}

String _asString(Object? value) => value is String ? value : "";

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? "") ?? 0;
}
