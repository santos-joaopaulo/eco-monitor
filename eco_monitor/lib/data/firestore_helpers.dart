import "package:cloud_firestore/cloud_firestore.dart";

// Methods ----------------------------------------------------------------- //

/// Converts a Firestore document map into plain JSON-compatible values.
///
/// Firestore-specific types ([Timestamp], [GeoPoint]) are converted to ISO 8601
/// UTC strings and numeric coordinates so domain models remain decoupled from
/// `cloud_firestore` and can be cached directly in `SharedPreferences`.
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

/// Extracts a UTC [DateTime] from a Firestore [Timestamp], [DateTime],
/// ISO 8601 [String], or Unix epoch milliseconds [int].
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

/// Reads the optional `metadata/<collectionName>` document's `updatedAt`
/// server timestamp, returning `null` if unavailable.
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
