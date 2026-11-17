// Enums ------------------------------------------------------------------- //

/// Waste categories handled by the disposal guide.
enum ResidueType { medicine, battery, sharps }

// Classes ----------------------------------------------------------------- //

/// Summary of a residue shown in the guide list.
class Residue {
  const Residue({
    required this.type,
    required this.title,
    required this.description,
    required this.minutes,
    required this.totalSteps,
  });

  final ResidueType type;
  final String title;
  final String description;

  /// Estimated time to read the full guide.
  final int minutes;
  final int totalSteps;

  // Methods --------------------------------------------------------------- //

  /// Builds a [Residue] from JSON, returning `null` if the type is unknown.
  static Residue? tryFromJson(Map<String, dynamic> json) {
    final String rawType = json["type"] is String ? json["type"] as String : "";
    final ResidueType? type = residueTypeByName(rawType);
    if (type == null) {
      return null;
    }

    return Residue(
      type: type,
      title: json["title"] is String ? json["title"] as String : "",
      description: json["description"] is String
          ? json["description"] as String
          : "",
      minutes: _asInt(json["minutes"], fallback: 1),
      totalSteps: _asInt(json["totalSteps"], fallback: 0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type.name,
    "title": title,
    "description": description,
    "minutes": minutes,
    "totalSteps": totalSteps,
  };
}

// Methods ----------------------------------------------------------------- //

/// Parses a [ResidueType] by name (also tolerating plural aliases used by
/// collection points such as `medicines` and `batteries`).
ResidueType? residueTypeByName(String name) {
  return switch (name) {
    "medicine" || "medicines" => ResidueType.medicine,
    "battery" || "batteries" => ResidueType.battery,
    "sharps" => ResidueType.sharps,
    _ => null,
  };
}

int _asInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? "") ?? fallback;
}
