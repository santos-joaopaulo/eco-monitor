// Enums -------------------------------------------------------------------- //


/// Categorias de resíduos tratadas pelo aplicativo (guia, pontos de coleta e campanhas).
enum WasteType { medicines, sharps, batteries, electronics, glass }


// Methods ------------------------------------------------------------------ //


/// Converte um nome de resíduo em [WasteType].
///
/// Aceita os nomes canônicos gravados pelo app e também os apelidos no singular
/// ainda presentes em dados antigos do Firestore e do cache local (`medicine`,
/// `battery`, `electronic`, `glass`, `vidro`). Retorna `null` para valores desconhecidos.
WasteType? wasteTypeByName(String name) {
  return switch (name.trim().toLowerCase()) {
    "medicines" || "medicine" => WasteType.medicines,
    "sharps" => WasteType.sharps,
    "batteries" || "battery" => WasteType.batteries,
    "electronics" || "electronic" => WasteType.electronics,
    "glass" || "vidro" => WasteType.glass,
    _ => null,
  };
}

/// Lê uma lista JSON de tipos de resíduos, ignorando valores ausentes ou desconhecidos.
Set<WasteType> wasteTypesFromJson(Object? raw) {
  final List<dynamic> values = raw is List<dynamic> ? raw : const <dynamic>[];

  return values
      .whereType<String>()
      .map(wasteTypeByName)
      .whereType<WasteType>()
      .toSet();
}
