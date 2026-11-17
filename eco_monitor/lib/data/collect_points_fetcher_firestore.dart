import "package:cloud_firestore/cloud_firestore.dart";

import "../models/collection_point.dart";
import "collect_points_repository.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";

// Constants ---------------------------------------------------------------- //

/// Firestore collection name for official collection points.
const String kCollectPointsCollection = "collectPoints";

// Methods ----------------------------------------------------------------- //

/// Creates a [CollectPointsFetcher] backed by the Firestore `collectPoints`
/// collection.
///
/// Each document is normalized and mapped to a [CollectionPoint] with the
/// document ID injected as `id`. The snapshot timestamp is derived strictly
/// from server timestamps (`updatedAt` across documents and/or the optional
/// `metadata/collectPoints` document) so stale data is never presented as fresh
/// (RNF17).
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
