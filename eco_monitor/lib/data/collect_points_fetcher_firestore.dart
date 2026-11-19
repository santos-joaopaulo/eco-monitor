import "package:cloud_firestore/cloud_firestore.dart";

import "../models/collection_point.dart";
import "collect_points_repository.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";


// Constants ---------------------------------------------------------------- //


/// Nome da coleção no Firestore para pontos de coleta oficiais.
const String kCollectPointsCollection = "collectPoints";


// Methods ----------------------------------------------------------------- //


/// Cria um [CollectPointsFetcher] baseado na coleção `collectPoints`
/// do Firestore.
///
/// Cada documento é normalizado e mapeado para um [CollectionPoint] com o
/// ID do documento injetado como `id`. O timestamp do snapshot é obtido estritamente
/// dos timestamps do servidor (`updatedAt` nos documentos e/ou no documento opcional
/// `metadata/collectPoints`), garantindo que dados desatualizados não sejam apresentados
/// como recentes (RNF17).
CollectPointsFetcher createFirestoreFetcher({FirebaseFirestore? firestore}) {
  return () async {
    if (firestore == null && !isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }

    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final QuerySnapshot<Map<String, dynamic>> snapshot = await db
        .collection(kCollectPointsCollection)
        .get();

    if (snapshot.docs.isEmpty) {
      throw StateError("Remote collectPoints collection is empty.");
    }

    DateTime? mostRecent = await readCollectionMetadataUpdatedAt(
      db,
      kCollectPointsCollection,
    );

    final List<CollectionPoint> points = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> raw = doc.data();
      final DateTime? docUpdatedAt = extractFirestoreTimestamp(
        raw["updatedAt"],
      );
      if (docUpdatedAt != null &&
          (mostRecent == null || docUpdatedAt.isAfter(mostRecent!))) {
        mostRecent = docUpdatedAt;
      }

      final Map<String, dynamic> normalized = normalizeFirestoreData(
        raw,
        documentId: doc.id,
      );
      return CollectionPoint.fromJson(normalized);
    }).toList();

    return CollectPointsRemoteSnapshot(
      points: points,
      updatedAt:
          mostRecent ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  };
}
