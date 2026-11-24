import "package:cloud_firestore/cloud_firestore.dart";


// Methods ------------------------------------------------------------------ //


/// Converte um mapa de documento do Firestore em valores compatíveis com JSON puro.
///
/// Tipos específicos do Firestore ([Timestamp], [GeoPoint]) são convertidos em strings ISO 8601
/// UTC e coordenadas numéricas, mantendo os modelos de domínio desacoplados do
/// `cloud_firestore` e permitindo cache direto no `SharedPreferences`.
Map<String, dynamic> normalizeFirestoreData(
  Map<String, dynamic> raw, {
  String? documentId,
}) {
  final Map<String, dynamic> normalized = <String, dynamic>{};

  for (final MapEntry<String, dynamic> entry in raw.entries) {
    final Object? value = entry.value;

    if (value is GeoPoint) {
      normalized.putIfAbsent("latitude", () => value.latitude);
      normalized.putIfAbsent("longitude", () => value.longitude);
      normalized[entry.key] = <String, double>{
        "latitude": value.latitude,
        "longitude": value.longitude,
      };
    } else {
      normalized[entry.key] = _normalizeValue(value);
    }
  }

  if (documentId != null && documentId.isNotEmpty) {
    normalized["id"] = documentId;
  }

  return normalized;
}

/// Extrai um [DateTime] em UTC a partir de um [Timestamp] do Firestore, [DateTime],
/// [String] em formato ISO 8601 ou milissegundos da época Unix ([int]).
DateTime? extractFirestoreTimestamp(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toUtc();
  }
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  return null;
}

/// Lê o timestamp de servidor `updatedAt` do documento opcional `metadata/<collectionName>`,
/// retornando `null` se indisponível.
Future<DateTime?> readCollectionMetadataUpdatedAt(
  FirebaseFirestore firestore,
  String collectionName,
) async {
  try {
    final DocumentSnapshot<Map<String, dynamic>> doc = await firestore
        .collection("metadata")
        .doc(collectionName)
        .get();
    if (!doc.exists) {
      return null;
    }

    return extractFirestoreTimestamp(doc.data()?["updatedAt"]);
  } catch (_) {
    return null;
  }
}

Object? _normalizeValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate().toUtc().toIso8601String();
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is GeoPoint) {
    return <String, double>{
      "latitude": value.latitude,
      "longitude": value.longitude,
    };
  }
  if (value is List<dynamic>) {
    return value.map(_normalizeValue).toList();
  }
  if (value is Map<dynamic, dynamic>) {
    return value.map(
      (dynamic key, dynamic entryValue) => MapEntry<String, dynamic>(
        key.toString(),
        _normalizeValue(entryValue),
      ),
    );
  }

  return value;
}
