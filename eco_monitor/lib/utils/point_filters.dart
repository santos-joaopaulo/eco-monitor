import "../domain/entities/waste_type.dart";
import "../models/collection_point.dart";


// Methods ----------------------------------------------------------------- //


/// Pontos exibidos no mapa para a seleção atual de resíduos e favoritos.
///
/// Pontos inativos nunca são exibidos. Uma seleção vazia significa "todos os resíduos",
/// caso contrário, o ponto deve aceitar pelo menos um dos tipos selecionados.
List<CollectionPoint> filterCollectionPoints(
  List<CollectionPoint> points,
  Set<WasteType> selectedWasteTypes, {
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
