import "dart:async";
import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../domain/repositories/point_reviews_repository_contract.dart";
import "../models/point_review.dart";
import "firebase_service.dart";
import "local_store.dart";


// Constants ---------------------------------------------------------------- //


/// Coleção do Firestore onde as avaliações anônimas são registradas (RNF06).
const String kPointReviewsCollection = "point_reviews";

const String _pendingReviewsQueueKey = "pending_point_reviews_queue_v1";
const String _localPointReviewsStoreKey = "local_point_reviews_store_v1";


// Types ------------------------------------------------------------------- //


/// Função usada por [PointReviewsRepository] para persistir uma avaliação remotamente.
typedef PointReviewSender = Future<void> Function(PointReview review);


// Methods ----------------------------------------------------------------- //


/// Cria um [PointReviewSender] anônimo integrado ao Cloud Firestore (RNF06, RNF14).
PointReviewSender createFirestorePointReviewSender({
  FirebaseFirestore? firestore,
}) {
  return (PointReview review) async {
    if (firestore == null && !isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }

    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final Map<String, dynamic> data = review.toJson()
      ..["createdAt"] = FieldValue.serverTimestamp();

    await db.collection(kPointReviewsCollection).add(data);
  };
}


// Classes ----------------------------------------------------------------- //


/// Repositório de avaliações de ecopontos com suporte a submissão anônima remota,
/// enfileiramento offline e cálculo local de médias e tags mais votadas.
class PointReviewsRepository implements IPointReviewsRepository {
  PointReviewsRepository({
    this.sender,
    this.isOnlineChecker,
    LocalStore? localStore,
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _store = localStore ??
           SharedPreferencesLocalStore(
             preferencesFactory: preferencesFactory,
           );

  final PointReviewSender? sender;
  final Future<bool> Function()? isOnlineChecker;
  final LocalStore _store;

  Future<void> _lock = Future<void>.value();
  Map<String, List<PointReview>>? _cachedReviewsByPoint;

  bool get hasRemoteSender => sender != null;


  // Methods --------------------------------------------------------------- //


  @override
  Future<PointReviewSubmitResult> submitReview(PointReview review) {
    return _synchronized(() async {
      await _recordLocalReviewUnsafe(review);

      final PointReviewSender? remoteSender = sender;
      if (remoteSender != null) {
        bool isOnline = true;
        if (isOnlineChecker != null) {
          try {
            isOnline = await isOnlineChecker!();
          } catch (_) {
            isOnline = true;
          }
        }

        if (isOnline) {
          try {
            await remoteSender(review).timeout(const Duration(seconds: 4));
            return PointReviewSubmitResult.sent;
          } catch (_) {
            // Falha remota (offline ou timeout): cai no enfileiramento local
          }
        }
      }

      await _enqueuePendingUnsafe(review);
      return PointReviewSubmitResult.queuedOffline;
    });
  }

  @override
  Future<List<PointReview>> getReviewsForPoint(String pointId) {
    return _synchronized(() async {
      final Map<String, List<PointReview>> all = await _loadAllLocalReviewsUnsafe();
      return List<PointReview>.of(all[pointId] ?? const <PointReview>[]);
    });
  }

  @override
  Future<PointReviewStats> getStatsForPoint(String pointId) {
    return _synchronized(() async {
      final Map<String, List<PointReview>> all = await _loadAllLocalReviewsUnsafe();
      final List<PointReview> reviews = all[pointId] ?? const <PointReview>[];

      if (reviews.isEmpty) {
        return PointReviewStats(
          pointId: pointId,
          averageRating: 0.0,
          totalReviews: 0,
        );
      }

      int sumRating = 0;
      final Map<String, int> tagCounts = <String, int>{};

      for (final PointReview r in reviews) {
        sumRating += r.rating;
        for (final String tag in r.tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final double avg = sumRating / reviews.length;
      return PointReviewStats(
        pointId: pointId,
        averageRating: double.parse(avg.toStringAsFixed(1)),
        totalReviews: reviews.length,
        tagCounts: tagCounts,
      );
    });
  }

  @override
  Future<int> flushPending() {
    return _synchronized(() async {
      final PointReviewSender? remoteSender = sender;
      if (remoteSender == null) {
        return 0;
      }

      final List<PointReview> pending = await _readQueueUnsafe();
      if (pending.isEmpty) {
        return 0;
      }

      final List<PointReview> remaining = <PointReview>[];
      int sentCount = 0;

      for (final PointReview review in pending) {
        try {
          await remoteSender(review).timeout(const Duration(seconds: 4));
          sentCount++;
        } catch (_) {
          remaining.add(review);
        }
      }

      await _writeQueueUnsafe(remaining);
      return sentCount;
    });
  }

  @override
  Future<int> pendingCount() {
    return _synchronized(() async {
      final List<PointReview> pending = await _readQueueUnsafe();
      return pending.length;
    });
  }

  @override
  Future<void> clearPending() {
    return _synchronized(() async {
      await _store.remove(_pendingReviewsQueueKey);
    });
  }


  // Helpers ----------------------------------------------------------------- //


  Future<Map<String, List<PointReview>>> _loadAllLocalReviewsUnsafe() async {
    final Map<String, List<PointReview>>? cached = _cachedReviewsByPoint;
    if (cached != null) {
      return cached;
    }

    final String? rawJson = await _store.getString(_localPointReviewsStoreKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      final Map<String, List<PointReview>> empty = <String, List<PointReview>>{};
      _cachedReviewsByPoint = empty;
      return empty;
    }

    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final Map<String, List<PointReview>> map = <String, List<PointReview>>{};
        for (final dynamic item in decoded) {
          if (item is Map<String, dynamic>) {
            final PointReview rev = PointReview.fromJson(item);
            (map[rev.pointId] ??= <PointReview>[]).add(rev);
          }
        }
        _cachedReviewsByPoint = map;
        return map;
      }
    } catch (_) {
      // Ignora payload corrompido
    }

    final Map<String, List<PointReview>> empty = <String, List<PointReview>>{};
    _cachedReviewsByPoint = empty;
    return empty;
  }

  Future<void> _recordLocalReviewUnsafe(PointReview review) async {
    final Map<String, List<PointReview>> all = await _loadAllLocalReviewsUnsafe();
    final List<PointReview> list = all[review.pointId] ?? <PointReview>[];
    list.removeWhere((PointReview existing) => existing.id == review.id);
    list.insert(0, review);
    all[review.pointId] = list;
    _cachedReviewsByPoint = all;

    final List<Map<String, dynamic>> flat = <Map<String, dynamic>>[];
    for (final List<PointReview> pointList in all.values) {
      for (final PointReview item in pointList) {
        flat.add(item.toJson());
      }
    }

    await _store.setString(_localPointReviewsStoreKey, jsonEncode(flat));
  }

  Future<List<PointReview>> _readQueueUnsafe() async {
    final String? rawJson = await _store.getString(_pendingReviewsQueueKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      return <PointReview>[];
    }

    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(PointReview.fromJson)
            .toList();
      }
    } catch (_) {
      // Ignora payload corrompido
    }

    return <PointReview>[];
  }

  Future<void> _writeQueueUnsafe(List<PointReview> queue) async {
    if (queue.isEmpty) {
      await _store.remove(_pendingReviewsQueueKey);
      return;
    }

    final List<Map<String, dynamic>> payload =
        queue.map((PointReview r) => r.toJson()).toList();
    await _store.setString(_pendingReviewsQueueKey, jsonEncode(payload));
  }

  Future<void> _enqueuePendingUnsafe(PointReview review) async {
    final List<PointReview> queue = await _readQueueUnsafe();
    queue.removeWhere((PointReview item) => item.id == review.id);
    queue.add(review);
    await _writeQueueUnsafe(queue);
  }

  Future<T> _synchronized<T>(Future<T> Function() computation) {
    final Completer<T> completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        final T result = await computation();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
