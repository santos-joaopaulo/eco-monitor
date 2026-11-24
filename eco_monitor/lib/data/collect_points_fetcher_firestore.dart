import "package:cloud_firestore/cloud_firestore.dart";

import "../models/collection_point.dart";
import "collect_points_repository.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";


// Constants ---------------------------------------------------------------- //


/// Nome da coleção no Firestore para pontos de coleta oficiais.
const String kCollectPointsCollection = "collectPoints";

/// Nome da coleção opcional de exclusões lógicas (tombstones).
const String kTombstonesCollection = "tombstones";


// Methods ----------------------------------------------------------------- //


/// Cria um [CollectPointsFetcher] para sincronização completa compatível com o padrão anterior.
CollectPointsFetcher createFirestoreFetcher({FirebaseFirestore? firestore}) {
  final CollectPointsDeltaFetcher deltaFetcher = createFirestoreDeltaFetcher(
    firestore: firestore,
  );
  return () => deltaFetcher(null);
}

/// Cria um [CollectPointsDeltaFetcher] baseado na coleção `collectPoints`
/// do Firestore com suporte a sincronização incremental (T11.4).
CollectPointsDeltaFetcher createFirestoreDeltaFetcher({
  FirebaseFirestore? firestore,
}) {
  return (DateTime? since) async {
    if (firestore == null && !isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }

    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;

    Query<Map<String, dynamic>> query = db.collection(kCollectPointsCollection);
    if (since != null) {
      query = query.where(
        "updatedAt",
        isGreaterThan: Timestamp.fromDate(since),
      );
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

    if (since == null && snapshot.docs.isEmpty) {
      throw StateError("Remote collectPoints collection is empty.");
    }

    DateTime? mostRecent = since;
    if (since == null) {
      mostRecent = await readCollectionMetadataUpdatedAt(
        db,
        kCollectPointsCollection,
      );
    }

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

    // Consulta de tombstones para remoção lógica de pontos desativados (T11.4)
    List<String> deletedIds = const <String>[];
    if (since != null) {
      try {
        final QuerySnapshot<Map<String, dynamic>> tombstones = await db
            .collection(kTombstonesCollection)
            .where("deletedAt", isGreaterThan: Timestamp.fromDate(since))
            .get();
        deletedIds = tombstones.docs.map((d) => d.id).toList();
      } catch (_) {
        // Coleção de tombstones é opcional
      }
    }

    return CollectPointsRemoteSnapshot(
      points: points,
      updatedAt:
          mostRecent ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isDelta: since != null,
      deletedIds: deletedIds,
    );
  };
}
