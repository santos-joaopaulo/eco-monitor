import "package:cloud_firestore/cloud_firestore.dart";

import "../models/campaign.dart";
import "../models/collection_point.dart";
import "../models/point_review.dart";
import "../models/point_suggestion.dart";
import "campaigns_repository.dart";
import "collect_points_fetcher_firestore.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";
import "point_reviews_repository.dart";
import "point_suggestions_repository.dart";


// Interfaces -------------------------------------------------------------- //


/// Contrato para operações administrativas de manipulação de dados no Cloud Firestore.
abstract interface class AdminDatabaseRepository {
  // Pontos de Coleta
  Future<List<CollectionPoint>> fetchPoints();
  Future<void> savePoint(CollectionPoint point);
  Future<void> savePointsBatch(List<CollectionPoint> points);
  Future<void> deletePoint(String pointId);

  // Campanhas
  Future<List<Campaign>> fetchCampaigns();
  Future<void> saveCampaign(Campaign campaign);
  Future<void> deleteCampaign(String campaignId);

  // Sugestões
  Future<List<PointSuggestion>> fetchSuggestions();
  Future<void> updateSuggestionStatus(
    String suggestionId,
    SuggestionStatus status,
  );
  Future<void> deleteSuggestion(String suggestionId);

  // Avaliações e Reportes Cidadãos
  Future<List<PointReview>> fetchReviews({String? pointId});
  Future<void> deleteReview(String reviewId);
  Future<List<CollectionPoint>> fetchPointsWithCriticalReports({
    String criticalTag = PointReviewTags.fullCollector,
    int minReports = 2,
  });
}


// Implementations --------------------------------------------------------- //


/// Implementação direta no Cloud Firestore para gestão administrativa do banco.
class FirestoreAdminDatabaseRepository implements AdminDatabaseRepository {
  FirestoreAdminDatabaseRepository({this.firestore});

  final FirebaseFirestore? firestore;

  FirebaseFirestore get _db {
    if (firestore != null) {
      return firestore!;
    }
    if (!isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }
    return FirebaseFirestore.instance;
  }


  // Pontos de Coleta ------------------------------------------------------ //


  @override
  Future<List<CollectionPoint>> fetchPoints() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection(kCollectPointsCollection)
        .get();

    final List<CollectionPoint> points = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> normalized = normalizeFirestoreData(
        doc.data(),
        documentId: doc.id,
      );
      return CollectionPoint.fromJson(normalized);
    }).toList();

    points.sort(
      (CollectionPoint a, CollectionPoint b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return points;
  }

  @override
  Future<void> savePoint(CollectionPoint point) async {
    final CollectionReference<Map<String, dynamic>> collection = _db
        .collection(kCollectPointsCollection);

    final DocumentReference<Map<String, dynamic>> docRef = point.id.isEmpty
        ? collection.doc()
        : collection.doc(point.id);

    final Map<String, dynamic> data = point.toJson()
      ..remove("id")
      ..["updatedAt"] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));

    // Atualiza metadados globais da coleção para acionar sincronização
    await _db
        .collection("metadata")
        .doc(kCollectPointsCollection)
        .set(<String, dynamic>{
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<void> savePointsBatch(List<CollectionPoint> points) async {
    if (points.isEmpty) {
      return;
    }

    final WriteBatch batch = _db.batch();
    final CollectionReference<Map<String, dynamic>> collection = _db
        .collection(kCollectPointsCollection);

    for (final CollectionPoint point in points) {
      final DocumentReference<Map<String, dynamic>> docRef = point.id.isEmpty
          ? collection.doc()
          : collection.doc(point.id);

      final Map<String, dynamic> data = point.toJson()
        ..remove("id")
        ..["updatedAt"] = FieldValue.serverTimestamp();

      batch.set(docRef, data, SetOptions(merge: true));
    }

    await batch.commit();

    // Atualiza metadados globais da coleção para acionar sincronização
    await _db
        .collection("metadata")
        .doc(kCollectPointsCollection)
        .set(<String, dynamic>{
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<void> deletePoint(String pointId) async {
    await _db.collection(kCollectPointsCollection).doc(pointId).delete();

    await _db
        .collection("metadata")
        .doc(kCollectPointsCollection)
        .set(<String, dynamic>{
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }


  // Campanhas ------------------------------------------------------------- //


  @override
  Future<List<Campaign>> fetchCampaigns() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection(kCampaignsCollection)
        .get();

    final List<Campaign> campaigns = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> normalized = normalizeFirestoreData(
        doc.data(),
        documentId: doc.id,
      );
      return Campaign.fromJson(normalized);
    }).toList();

    campaigns.sort((Campaign a, Campaign b) => a.startDate.compareTo(b.startDate));
    return campaigns;
  }

  @override
  Future<void> saveCampaign(Campaign campaign) async {
    final CollectionReference<Map<String, dynamic>> collection = _db
        .collection(kCampaignsCollection);

    final DocumentReference<Map<String, dynamic>> docRef = campaign.id.isEmpty
        ? collection.doc()
        : collection.doc(campaign.id);

    final Map<String, dynamic> data = campaign.toJson()
      ..remove("id")
      ..["updatedAt"] = FieldValue.serverTimestamp();

    await docRef.set(data, SetOptions(merge: true));

    await _db
        .collection("metadata")
        .doc(kCampaignsCollection)
        .set(<String, dynamic>{
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteCampaign(String campaignId) async {
    await _db.collection(kCampaignsCollection).doc(campaignId).delete();

    await _db
        .collection("metadata")
        .doc(kCampaignsCollection)
        .set(<String, dynamic>{
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }


  // Sugestões ------------------------------------------------------------- //


  @override
  Future<List<PointSuggestion>> fetchSuggestions() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _db
        .collection(kPointSuggestionsCollection)
        .get();

    final List<PointSuggestion> suggestions = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> normalized = normalizeFirestoreData(
        doc.data(),
        documentId: doc.id,
      );
      return PointSuggestion.fromJson(normalized);
    }).toList();

    suggestions.sort(
      (PointSuggestion a, PointSuggestion b) =>
          b.createdAt.compareTo(a.createdAt),
    );
    return suggestions;
  }

  @override
  Future<void> updateSuggestionStatus(
    String suggestionId,
    SuggestionStatus status,
  ) async {
    await _db
        .collection(kPointSuggestionsCollection)
        .doc(suggestionId)
        .update(<String, dynamic>{
          "status": status.name,
          "updatedAt": FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> deleteSuggestion(String suggestionId) async {
    await _db.collection(kPointSuggestionsCollection).doc(suggestionId).delete();
  }


  // Avaliações e Reportes Cidadãos ---------------------------------------- //


  @override
  Future<List<PointReview>> fetchReviews({String? pointId}) async {
    Query<Map<String, dynamic>> query = _db.collection(kPointReviewsCollection);
    if (pointId != null && pointId.isNotEmpty) {
      query = query.where("pointId", isEqualTo: pointId);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
    final List<PointReview> reviews = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      final Map<String, dynamic> normalized = normalizeFirestoreData(
        doc.data(),
        documentId: doc.id,
      );
      return PointReview.fromJson(normalized);
    }).toList();

    reviews.sort(
      (PointReview a, PointReview b) => b.createdAt.compareTo(a.createdAt),
    );
    return reviews;
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    await _db.collection(kPointReviewsCollection).doc(reviewId).delete();
  }

  @override
  Future<List<CollectionPoint>> fetchPointsWithCriticalReports({
    String criticalTag = PointReviewTags.fullCollector,
    int minReports = 2,
  }) async {
    final List<PointReview> allReviews = await fetchReviews();
    final Map<String, int> countsByPoint = <String, int>{};

    for (final PointReview r in allReviews) {
      if (r.tags.contains(criticalTag)) {
        countsByPoint[r.pointId] = (countsByPoint[r.pointId] ?? 0) + 1;
      }
    }

    final Set<String> criticalPointIds = countsByPoint.entries
        .where((MapEntry<String, int> e) => e.value >= minReports)
        .map((MapEntry<String, int> e) => e.key)
        .toSet();

    if (criticalPointIds.isEmpty) {
      return <CollectionPoint>[];
    }

    final List<CollectionPoint> allPoints = await fetchPoints();
    return allPoints
        .where((CollectionPoint p) => criticalPointIds.contains(p.id))
        .toList();
  }
}
