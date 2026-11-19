import "collection_point.dart";


// Enums ------------------------------------------------------------------- //


/// Status de revisão de uma sugestão de ponto enviada pelo usuário.
enum SuggestionStatus { pending, reviewing, approved, rejected }


// Classes ----------------------------------------------------------------- //


/// Sugestão anônima de um novo ponto de coleta (RF10, RF11, RNF06).
class PointSuggestion {
  PointSuggestion({
    required this.id,
    required this.name,
    required this.address,
    required Set<WasteType> acceptedWasteTypes,
    required this.hours,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
  }) : acceptedWasteTypes = Set<WasteType>.unmodifiable(acceptedWasteTypes);

  final String id;
  final String name;
  final String address;
  final Set<WasteType> acceptedWasteTypes;
  final String hours;
  final double? latitude;
  final double? longitude;
  final SuggestionStatus status;
  final DateTime createdAt;


  // Methods --------------------------------------------------------------- //


  /// Constrói uma sugestão a partir de JSON, tolerando campos ausentes e valores desconhecidos.
  ///
  /// Tipos de resíduos desconhecidos são ignorados e status desconhecidos assumem pending.
  factory PointSuggestion.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawWasteTypes = switch (json["acceptedWasteTypes"]) {
      final List<dynamic> values => values,
      _ => const <dynamic>[],
    };

    final Set<WasteType> wasteTypes = rawWasteTypes
        .whereType<String>()
        .map(_wasteTypeByName)
        .whereType<WasteType>()
        .toSet();

    return PointSuggestion(
      id: _asString(json["id"]),
      name: _asString(json["name"]),
      address: _asString(json["address"]),
      acceptedWasteTypes: wasteTypes,
      hours: _asString(json["hours"]),
      latitude: _asOptionalDouble(json["latitude"]),
      longitude: _asOptionalDouble(json["longitude"]),
      status: _suggestionStatusByName(_asString(json["status"])),
      createdAt: _asDateTime(json["createdAt"]),
    );
  }

  /// Serializa para JSON para o Firestore.
  ///
  /// O [id] é omitido (o Firestore gera automaticamente) e [latitude] /
  /// [longitude] são omitidos quando nulos. Nenhum dado pessoal é incluído.
  Map<String, dynamic> toJson() {
    final List<String> waste =
        acceptedWasteTypes.map((WasteType type) => type.name).toList()..sort();

    final Map<String, dynamic> json = {
      "name": name,
      "address": address,
      "acceptedWasteTypes": waste,
      "hours": hours,
      "status": status.name,
      "createdAt": createdAt.toIso8601String(),
    };

    if (latitude != null) {
      json["latitude"] = latitude;
    }
    if (longitude != null) {
      json["longitude"] = longitude;
    }

    return json;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is PointSuggestion && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => "PointSuggestion($id, $name)";
}


// Methods ----------------------------------------------------------------- //


WasteType? _wasteTypeByName(String name) {
  for (final WasteType type in WasteType.values) {
    if (type.name == name) {
      return type;
    }
  }

  return null;
}

SuggestionStatus _suggestionStatusByName(String name) {
  for (final SuggestionStatus status in SuggestionStatus.values) {
    if (status.name == name) {
      return status;
    }
  }

  return SuggestionStatus.pending;
}

String _asString(Object? value) => value is String ? value : "";

double? _asOptionalDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}

DateTime _asDateTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
