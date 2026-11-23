import "package:cloud_firestore/cloud_firestore.dart";

import "../models/campaign.dart";
import "../models/collection_point.dart";
import "../models/point_suggestion.dart";
import "campaigns_repository.dart";
import "collect_points_fetcher_firestore.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";
import "point_suggestions_repository.dart";


// Interfaces -------------------------------------------------------------- //


/// Contrato para operações administrativas de manipulação de dados no Cloud Firestore.
abstract interface class AdminDatabaseRepository {
  // Pontos de Coleta
  Future<List<CollectionPoint>> fetchPoints();
  Future<void> savePoint(CollectionPoint point);
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
}
