import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_core/firebase_core.dart";
import "package:flutter/foundation.dart";

// State ------------------------------------------------------------------- //

/// Whether a default Firebase app has been initialized and is ready to use.
bool get isFirebaseReady => Firebase.apps.isNotEmpty;

// Methods ----------------------------------------------------------------- //

/// Initializes Firebase and enables Cloud Firestore offline persistence.
///
/// Returns `true` when Firebase is ready, or `false` if initialization fails
/// (for example, when `google-services.json` or `GoogleService-Info.plist` has
/// not been added yet). The app continues operating in offline mode when this
/// returns `false` (RNF09, RNF10).
Future<bool> initializeFirebase({FirebaseOptions? options}) async {
  if (Firebase.apps.isNotEmpty) {
    return true;
  }

  try {
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      await Firebase.initializeApp();
    }

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    return true;
  } catch (error) {
    debugPrint("Firebase initialization skipped (running offline): $error");
    return false;
  }
}
