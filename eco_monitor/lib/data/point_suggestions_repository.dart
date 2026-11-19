import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../models/point_suggestion.dart";
import "firebase_service.dart";


// Constants ---------------------------------------------------------------- //


/// Nome da coleção no Firestore para sugestões anônimas de pontos.
const String kPointSuggestionsCollection = "pointSuggestions";

const String _pendingQueueKey = "pending_point_suggestions_json";


// Enums ------------------------------------------------------------------- //


/// Resultado do envio de uma nova sugestão de ponto de coleta (RF10, RNF10).
enum SuggestionSubmitResult {
  /// Entregue diretamente ao backend remoto.
  sent,

  /// Salva localmente na fila anônima offline para reenvio automático.
  queuedOffline,
}


// Types ------------------------------------------------------------------- //


/// Função usada por [PointSuggestionsRepository] para persistir uma sugestão remotamente.
typedef PointSuggestionSender = Future<void> Function(
  PointSuggestion suggestion,
);


// Methods ----------------------------------------------------------------- //


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


// Classes ----------------------------------------------------------------- //


/// Envia sugestões anônimas de pontos ao Firestore com uma fila offline de contingência
/// para que os envios nunca sejam perdidos silenciosamente sem internet (RF11, RNF06,
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


  /// Envia [suggestion] anonimamente ao backend remoto.
  ///
  /// Quando [sender] for nulo ou lançar exceção (ex.: offline), a sugestão é enfileirada
  /// localmente no [SharedPreferences] e [SuggestionSubmitResult.queuedOffline]
  /// é retornado para ser reenviado automaticamente assim que a conectividade for restaurada.
  Future<SuggestionSubmitResult> submit(PointSuggestion suggestion) async {
    final PointSuggestionSender? remoteSender = sender;
    if (remoteSender != null) {
      try {
        await remoteSender(suggestion);
        return SuggestionSubmitResult.sent;
      } catch (_) {
        // Recorre à fila offline para que a sugestão do usuário não seja perdida.
      }
    }

    await _enqueue(suggestion);
    return SuggestionSubmitResult.queuedOffline;
  }

  /// Retorna todas as sugestões que estão atualmente aguardando na fila offline.
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

  /// Quantidade de sugestões atualmente enfileiradas offline.
  Future<int> pendingCount() async {
    final List<PointSuggestion> pending = await loadPending();
    return pending.length;
  }

  /// Tenta enviar todas as sugestões offline enfileiradas na ordem FIFO.
  ///
  /// Retorna o número de sugestões entregues com sucesso. Qualquer sugestão
  /// que ainda falhar permanece na fila local.
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

  /// Limpa todas as sugestões enfileiradas localmente.
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
