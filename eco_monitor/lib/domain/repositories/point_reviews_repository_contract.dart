import "dart:async";

import "../entities/point_review.dart";


// Interfaces --------------------------------------------------------------- //


/// Contrato para envio anônimo, enfileiramento offline e agregação de avaliações de ecopontos.
abstract interface class IPointReviewsRepository {
  /// Envia uma avaliação de ponto de coleta anonimamente.
  ///
  /// Retorna [PointReviewSubmitResult.sent] quando gravada no servidor remoto,
  /// ou [PointReviewSubmitResult.queuedOffline] quando armazenada na fila local.
  Future<PointReviewSubmitResult> submitReview(PointReview review);

  /// Retorna as avaliações registradas para o ponto de coleta [pointId].
  Future<List<PointReview>> getReviewsForPoint(String pointId);

  /// Retorna as estatísticas consolidadas de avaliação (média, total e tags) para [pointId].
  Future<PointReviewStats> getStatsForPoint(String pointId);

  /// Envia todas as avaliações retidas na fila offline para o servidor remoto.
  Future<int> flushPending();

  /// Atualiza o cache local com as avaliações armazenadas no servidor remoto.
  Future<void> refresh();

  /// Retorna o número de avaliações pendentes de sincronização remota.
  Future<int> pendingCount();

  /// Limpa as avaliações pendentes da fila offline.
  Future<void> clearPending();
}
