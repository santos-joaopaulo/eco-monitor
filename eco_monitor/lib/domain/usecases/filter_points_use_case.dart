import "../entities/collection_point.dart";
import "../entities/waste_type.dart";


// Use cases --------------------------------------------------------------- //


/// Caso de uso para filtragem de pontos de coleta por resíduos e status (Domínio).
class FilterPointsUseCase {
  const FilterPointsUseCase();

  /// Filtra pontos ativos compatíveis com os tipos de resíduo selecionados.
  List<CollectionPoint> execute({
    required List<CollectionPoint> points,
    required Set<WasteType> selectedWasteTypes,
  }) {
    return points
        .where(
          (CollectionPoint point) =>
              point.isActive && point.acceptsAny(selectedWasteTypes),
        )
        .toList();
  }
}
