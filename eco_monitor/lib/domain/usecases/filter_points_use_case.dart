import "../entities/collection_point.dart";
import "../entities/waste_type.dart";


// Use cases --------------------------------------------------------------- //


/// Caso de uso para filtragem de pontos de coleta por resíduos e status (Domínio).
class FilterPointsUseCase {
  const FilterPointsUseCase();

  /// Filtra pontos ativos compatíveis com os tipos de resíduo selecionados e favoritos.
  List<CollectionPoint> execute({
    required List<CollectionPoint> points,
    required Set<WasteType> selectedWasteTypes,
    bool onlyFavorites = false,
    Set<String> favoriteIds = const <String>{},
  }) {
    return points
        .where(
          (CollectionPoint point) =>
              point.isActive &&
              point.acceptsAny(selectedWasteTypes) &&
              (!onlyFavorites || favoriteIds.contains(point.id)),
        )
        .toList();
  }
}
