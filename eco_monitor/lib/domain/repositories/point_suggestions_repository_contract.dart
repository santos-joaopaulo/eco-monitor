import "../entities/point_suggestion.dart";


// Contracts --------------------------------------------------------------- //


/// Contrato do repositório de sugestões anônimas de pontos (Camada de Domínio).
abstract interface class IPointSuggestionsRepository {
  /// Envia uma sugestão anônima para o backend ou armazena na fila offline.
  Future<SuggestionSubmitResult> submit(PointSuggestion suggestion);

  /// Esvazia e envia os itens retidos na fila offline.
  Future<int> flushPending();

  /// Quantidade de sugestões pendentes aguardando envio na fila offline.
  Future<int> pendingCount();
}
