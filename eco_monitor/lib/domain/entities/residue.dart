import "waste_type.dart";


// Classes ----------------------------------------------------------------- //


/// Resumo de um resíduo exibido na listagem do guia.
class Residue {
  const Residue({
    required this.type,
    required this.title,
    required this.description,
    required this.minutes,
    required this.totalSteps,
  });

  final WasteType type;
  final String title;
  final String description;

  /// Tempo estimado para a leitura completa do guia.
  final int minutes;
  final int totalSteps;


  // Methods --------------------------------------------------------------- //


  /// Constrói um [Residue] a partir de JSON, retornando `null` se o tipo for desconhecido.
  static Residue? tryFromJson(Map<String, dynamic> json) {
    final String rawType = json["type"] is String ? json["type"] as String : "";
    final WasteType? type = wasteTypeByName(rawType);
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


int _asInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? "") ?? fallback;
}
