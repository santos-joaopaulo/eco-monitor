import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/point_suggestion.dart";
import "firebase_service.dart";

// Constants ---------------------------------------------------------------- //

/// Firestore collection name for anonymous point suggestions.
const String kPointSuggestionsCollection = "pointSuggestions";

const String _pendingQueueKey = "pending_point_suggestions_json";

// Enums ------------------------------------------------------------------- //

/// Outcome of submitting a new collection point suggestion (RF10, RNF10).
enum SuggestionSubmitResult {
  /// Delivered directly to the remote backend.
  sent,

  /// Saved locally in the anonymous offline queue for automatic retry.
  queuedOffline,
}

// Types ------------------------------------------------------------------- //

/// Hook used by [PointSuggestionsRepository] to persist a suggestion remotely.
typedef PointSuggestionSender = Future<void> Function(
  PointSuggestion suggestion,
);

// Methods ----------------------------------------------------------------- //

/// Creates a [PointSuggestionSender] backed by Firestore `pointSuggestions`.
///
/// The payload is strictly anonymous (no user or device identifiers — RF11,
/// RNF06) and uses [FieldValue.serverTimestamp] for `createdAt` (RNF14).
PointSuggestionSender createFirestoreSuggestionSender({
  FirebaseFirestore? firestore,
}) {
  return (PointSuggestion suggestion) async {
    if (firestore == null && !isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }

    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final Map<String, dynamic> data = suggestion.toJson()
      ..["status"] = SuggestionStatus.pending.name
      ..["createdAt"] = FieldValue.serverTimestamp();

    await db.collection(kPointSuggestionsCollection).add(data);
  };
}

// Classes ----------------------------------------------------------------- //

/// Sends anonymous point suggestions to Firestore with an offline fallback
/// queue so submissions are never silently lost without internet (RF11, RNF06,
/// RNF10, RNF14).
class PointSuggestionsRepository {
  PointSuggestionsRepository({
    this.sender,
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  final PointSuggestionSender? sender;
  final Future<SharedPreferences> Function() _preferencesFactory;

  bool get hasRemoteSender => sender != null;

  // Methods --------------------------------------------------------------- //

  /// Submits [suggestion] anonymously to the remote backend.
  ///
  /// When [sender] is null or throws (e.g., offline), the suggestion is queued
  /// locally in [SharedPreferences] and [SuggestionSubmitResult.queuedOffline]
  /// is returned so it can be retried automatically when connectivity returns.
  Future<SuggestionSubmitResult> submit(PointSuggestion suggestion) async {
    final PointSuggestionSender? remoteSender = sender;
    if (remoteSender != null) {
      try {
        await remoteSender(suggestion);
        return SuggestionSubmitResult.sent;
      } catch (_) {
        // Fall through to offline queue so the user's suggestion is not lost.
      }
    }

    await _enqueue(suggestion);
    return SuggestionSubmitResult.queuedOffline;
  }

  /// Returns all suggestions currently waiting in the offline queue.
  Future<List<PointSuggestion>> loadPending() async {
    final SharedPreferences preferences = await _preferencesFactory();
    final String? raw = preferences.getString(_pendingQueueKey);
    if (raw == null || raw.isEmpty) {
      return const <PointSuggestion>[];
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return const <PointSuggestion>[];
      }

      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> json) =>
                PointSuggestion.fromJson(json.cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const <PointSuggestion>[];
    }
  }

  /// Number of suggestions currently queued offline.
  Future<int> pendingCount() async {
    final List<PointSuggestion> pending = await loadPending();
    return pending.length;
  }

  /// Attempts to send all queued offline suggestions in FIFO order.
  ///
  /// Returns the number of suggestions successfully delivered. Any suggestion
  /// that still fails remains in the local queue.
  Future<int> flushPending() async {
    final PointSuggestionSender? remoteSender = sender;
    if (remoteSender == null) {
      return 0;
    }

    final List<PointSuggestion> pending = await loadPending();
    if (pending.isEmpty) {
      return 0;
    }

    final List<PointSuggestion> remaining = <PointSuggestion>[];
    int sentCount = 0;

    for (final PointSuggestion suggestion in pending) {
      try {
        await remoteSender(suggestion);
        sentCount++;
      } catch (_) {
        remaining.add(suggestion);
      }
    }

    await _writeQueue(remaining);
    return sentCount;
  }

  /// Clears all locally queued suggestions.
  Future<void> clearPending() async {
    final SharedPreferences preferences = await _preferencesFactory();
    await preferences.remove(_pendingQueueKey);
  }

  Future<void> _enqueue(PointSuggestion suggestion) async {
    final List<PointSuggestion> queue = List<PointSuggestion>.of(
      await loadPending(),
    )..add(suggestion);
    await _writeQueue(queue);
  }

  Future<void> _writeQueue(List<PointSuggestion> queue) async {
    final SharedPreferences preferences = await _preferencesFactory();
    if (queue.isEmpty) {
      await preferences.remove(_pendingQueueKey);
      return;
    }

    await preferences.setString(
      _pendingQueueKey,
      jsonEncode(queue.map((PointSuggestion item) => item.toJson()).toList()),
    );
  }
}
