import "package:cloud_firestore/cloud_firestore.dart";

import "../domain/entities/collection_point.dart";
import "collect_points_repository.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";


// Constants ---------------------------------------------------------------- //


/// Nome da coleção no Firestore para pontos de coleta oficiais.
const String kCollectPointsCollection = "collectPoints";

/// Nome da coleção opcional de exclusões lógicas (tombstones).
const String kTombstonesCollection = "tombstones";


// Methods ------------------------------------------------------------------ //


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
    final DateTime? metadataUpdatedAt = await readCollectionMetadataUpdatedAt(
      db,
      kCollectPointsCollection,
    );
    if (since == null) {
      mostRecent = metadataUpdatedAt;
    }

    final ({List<CollectionPoint> points, DateTime? mostRecent}) parsed =
        _parsePointsSnapshot(snapshot, initialMostRecent: mostRecent);
    final List<CollectionPoint> points = parsed.points;
    mostRecent = parsed.mostRecent;

    // Consulta de tombstones para remoção lógica de pontos desativados ou excluídos (T11.4)
    List<String> deletedIds = const <String>[];
    if (since != null) {
      try {
        final QuerySnapshot<Map<String, dynamic>> tombstones = await db
            .collection(kTombstonesCollection)
            .where("deletedAt", isGreaterThan: Timestamp.fromDate(since))
            .get();
        deletedIds = tombstones.docs.map((d) => d.id).toList();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in tombstones.docs) {
          final DateTime? deletedAt = extractFirestoreTimestamp(
            doc.data()["deletedAt"],
          );
          if (deletedAt != null &&
              (mostRecent == null || deletedAt.isAfter(mostRecent))) {
            mostRecent = deletedAt;
          }
        }
      } catch (_) {
        // Coleção de tombstones é opcional
      }

      // Se os metadados indicam alteração após `since`, mas o delta veio vazio
      // (ex.: exclusão sem tombstone acessível), recorre à carga completa.
      if (points.isEmpty &&
          deletedIds.isEmpty &&
          metadataUpdatedAt != null &&
          metadataUpdatedAt.isAfter(since)) {
        final QuerySnapshot<Map<String, dynamic>> fullSnapshot = await db
            .collection(kCollectPointsCollection)
            .get();
        if (fullSnapshot.docs.isEmpty) {
          throw StateError("Remote collectPoints collection is empty.");
        }
        final ({List<CollectionPoint> points, DateTime? mostRecent}) fullParsed =
            _parsePointsSnapshot(
              fullSnapshot,
              initialMostRecent: metadataUpdatedAt,
            );
        return CollectPointsRemoteSnapshot(
          points: fullParsed.points,
          updatedAt: fullParsed.mostRecent ?? metadataUpdatedAt,
          isDelta: false,
        );
      }

      if (metadataUpdatedAt != null &&
          (mostRecent == null || metadataUpdatedAt.isAfter(mostRecent))) {
        mostRecent = metadataUpdatedAt;
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

({List<CollectionPoint> points, DateTime? mostRecent}) _parsePointsSnapshot(
  QuerySnapshot<Map<String, dynamic>> snapshot, {
  DateTime? initialMostRecent,
}) {
  DateTime? mostRecent = initialMostRecent;
  final List<CollectionPoint> points = snapshot.docs.map((
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> raw = doc.data();
    final DateTime? docUpdatedAt = extractFirestoreTimestamp(raw["updatedAt"]);
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

  return (points: points, mostRecent: mostRecent);
}
