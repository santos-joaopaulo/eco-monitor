import "dart:async";


// Interfaces --------------------------------------------------------------- //


/// Contrato para persistência e consulta offline-first dos ecopontos favoritados pelo usuário (RF-FAV).
abstract interface class IFavoritesRepository {
  /// Retorna o conjunto de identificadores de pontos favoritados.
  Future<Set<String>> getFavoriteIds();

  /// Verifica se o ponto identificado por [pointId] está marcado como favorito.
  Future<bool> isFavorite(String pointId);

  /// Adiciona o ponto identificado por [pointId] aos favoritos.
  Future<void> addFavorite(String pointId);

  /// Remove o ponto identificado por [pointId] dos favoritos.
  Future<void> removeFavorite(String pointId);

  /// Alterna o estado de favorito do ponto [pointId], retornando o novo estado (`true` se favoritado).
  Future<bool> toggleFavorite(String pointId);

  /// Fluxo reativo emitindo o conjunto atualizado de IDs favoritados.
  Stream<Set<String>> watchFavoriteIds();
}
