import "dart:async";
import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../domain/repositories/point_suggestions_repository_contract.dart";
import "../domain/entities/point_suggestion.dart";
import "firebase_service.dart";
import "local_store.dart";


// Constants ---------------------------------------------------------------- //


/// Nome da coleção no Firestore para sugestões anônimas de pontos.
const String kPointSuggestionsCollection = "pointSuggestions";

/// Versão do envelope da fila de sugestões offline.
const int kPointSuggestionsQueueVersion = 1;

const String _pendingQueueKey = "pending_point_suggestions_json";


// Types -------------------------------------------------------------------- //


/// Função usada por [PointSuggestionsRepository] para persistir uma sugestão remotamente.
typedef PointSuggestionSender = Future<void> Function(
  PointSuggestion suggestion,
);


// Methods ------------------------------------------------------------------ //


/// Cria um [PointSuggestionSender] baseado na coleção `pointSuggestions` do Firestore.
///
/// O payload é estritamente anônimo (sem identificadores de usuário ou dispositivo — RF11,
/// RNF06) e utiliza [FieldValue.serverTimestamp] para `createdAt` (RNF14).
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


// Classes ------------------------------------------------------------------ //


/// Envia sugestões anônimas de pontos ao Firestore com uma fila offline de contingência
/// protegida por mutex interno para evitar lost updates em chamadas concorrentes
/// (RF11, RNF06, RNF10, RNF14).
class PointSuggestionsRepository implements IPointSuggestionsRepository {
  PointSuggestionsRepository({
    this.sender,
    this.isOnlineChecker,
    LocalStore? localStore,
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _store = localStore ??
           SharedPreferencesLocalStore(
             preferencesFactory: preferencesFactory,
           );

  final PointSuggestionSender? sender;
  final Future<bool> Function()? isOnlineChecker;
  final LocalStore _store;

  Future<void> _lock = Future<void>.value();

  bool get hasRemoteSender => sender != null;


// Methods ------------------------------------------------------------------ //


  /// Envia [suggestion] anonimamente ao backend remoto.
  ///
  /// Quando [sender] for nulo ou lançar exceção (ex.: offline), a sugestão é enfileirada
  /// localmente no [LocalStore] e [SuggestionSubmitResult.queuedOffline]
  /// é retornado para ser reenviado automaticamente assim que a conectividade for restaurada.
  @override
  Future<SuggestionSubmitResult> submit(PointSuggestion suggestion) {
    return _synchronized(() async {
      final PointSuggestionSender? remoteSender = sender;
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
            await remoteSender(suggestion).timeout(const Duration(seconds: 4));
            return SuggestionSubmitResult.sent;
          } catch (_) {
            // Recorre à fila offline para que a sugestão do usuário não seja perdida.
          }
        }
      }

      await _enqueueUnsafe(suggestion);
      return SuggestionSubmitResult.queuedOffline;
    });
  }

  /// Retorna todas as sugestões que estão atualmente aguardando na fila offline.
  Future<List<PointSuggestion>> loadPending() {
    return _synchronized(() => _readQueueUnsafe());
  }

  /// Quantidade de sugestões atualmente enfileiradas offline.
  @override
  Future<int> pendingCount() async {
    final List<PointSuggestion> pending = await loadPending();
    return pending.length;
  }

  /// Tenta enviar todas as sugestões offline enfileiradas na ordem FIFO.
  ///
  /// Retorna o número de sugestões entregues com sucesso. Qualquer sugestão
  /// que ainda falhar permanece na fila local.
  @override
  Future<int> flushPending() {
    return _synchronized(() async {
      final PointSuggestionSender? remoteSender = sender;
      if (remoteSender == null) {
        return 0;
      }

      final List<PointSuggestion> pending = await _readQueueUnsafe();
      if (pending.isEmpty) {
        return 0;
      }

      final List<PointSuggestion> remaining = <PointSuggestion>[];
      int sentCount = 0;

      for (final PointSuggestion suggestion in pending) {
        try {
          await remoteSender(suggestion).timeout(const Duration(seconds: 4));
          sentCount++;
        } catch (_) {
          remaining.add(suggestion);
        }
      }

      await _writeQueueUnsafe(remaining);
      return sentCount;
    });
  }

  /// Limpa todas as sugestões enfileiradas localmente.
  Future<void> clearPending() {
    return _synchronized(() async {
      await _store.remove(_pendingQueueKey);
    });
  }


// Helpers ------------------------------------------------------------------ //


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

  Future<void> _enqueueUnsafe(PointSuggestion suggestion) async {
    final List<PointSuggestion> queue = List<PointSuggestion>.of(
      await _readQueueUnsafe(),
    )..add(suggestion);
    await _writeQueueUnsafe(queue);
  }

  Future<List<PointSuggestion>> _readQueueUnsafe() async {
    final String? raw = await _store.getString(_pendingQueueKey);
    if (raw == null || raw.isEmpty) {
      return const <PointSuggestion>[];
    }

    try {
      final Object? decoded = jsonDecode(raw);

      // Formato novo com envelope versionado: {version, items}
      if (decoded is Map<String, dynamic>) {
        final Object? version = decoded["version"];
        if (version == kPointSuggestionsQueueVersion) {
          final Object? items = decoded["items"];
          if (items is List<dynamic>) {
            return _parseItemsList(items);
          }
        }
        return const <PointSuggestion>[];
      }

      // Formato legado com lista simples
      if (decoded is List<dynamic>) {
        return _parseItemsList(decoded);
      }

      return const <PointSuggestion>[];
    } catch (_) {
      return const <PointSuggestion>[];
    }
  }

  List<PointSuggestion> _parseItemsList(List<dynamic> items) {
    return items
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> json) =>
              PointSuggestion.fromJson(json.cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> _writeQueueUnsafe(List<PointSuggestion> queue) async {
    if (queue.isEmpty) {
      await _store.remove(_pendingQueueKey);
      return;
    }

    final Map<String, dynamic> envelope = <String, dynamic>{
      "version": kPointSuggestionsQueueVersion,
      "items": queue.map((PointSuggestion item) => item.toJson()).toList(),
    };

    await _store.setString(_pendingQueueKey, jsonEncode(envelope));
  }
}
