import "package:flutter/foundation.dart";

import "../../domain/repositories/favorites_repository_contract.dart";


// Classes ----------------------------------------------------------------- //


/// Gerenciador de estado reativo para os pontos de coleta favoritados (RF-FAV).
class FavoritesNotifier extends ChangeNotifier {
  FavoritesNotifier(this._repository) {
    _init();
  }

  final IFavoritesRepository _repository;
  Set<String> _favoriteIds = const <String>{};
  bool _isLoading = true;

  Set<String> get favoriteIds => _favoriteIds;
  bool get isLoading => _isLoading;

  /// Retorna se o ponto com [pointId] está marcado como favorito.
  bool isFavorite(String pointId) => _favoriteIds.contains(pointId);


  // Methods --------------------------------------------------------------- //


  Future<void> _init() async {
    _favoriteIds = await _repository.getFavoriteIds();
    _isLoading = false;
    notifyListeners();
  }

  /// Alterna o estado de favorito de [pointId], notificando ouvintes reativos.
  Future<bool> toggleFavorite(String pointId) async {
    final bool isFav = await _repository.toggleFavorite(pointId);
    if (isFav) {
      _favoriteIds = Set<String>.unmodifiable(<String>{..._favoriteIds, pointId});
    } else {
      _favoriteIds = Set<String>.unmodifiable(
        _favoriteIds.where((String id) => id != pointId),
      );
    }
    notifyListeners();
    return isFav;
  }

  /// Força o recarregamento do repositório.
  Future<void> reload() async {
    _favoriteIds = await _repository.getFavoriteIds();
    notifyListeners();
  }
}
