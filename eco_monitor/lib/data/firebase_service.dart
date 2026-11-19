import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_core/firebase_core.dart";
import "package:flutter/foundation.dart";


// State ------------------------------------------------------------------- //


/// Indica se um app padrão do Firebase foi inicializado e está pronto para uso.
bool get isFirebaseReady => Firebase.apps.isNotEmpty;


// Methods ----------------------------------------------------------------- //


/// Inicializa o Firebase e habilita a persistência offline do Cloud Firestore.
///
/// Retorna `true` quando o Firebase estiver pronto, ou `false` se a inicialização falhar
/// (por exemplo, quando `google-services.json` ou `GoogleService-Info.plist` ainda
/// não tiverem sido adicionados). O aplicativo continua operando em modo offline
/// quando este método retorna `false` (RNF09, RNF10).
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
