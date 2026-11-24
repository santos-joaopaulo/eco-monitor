import "../../models/civic_demand_summary.dart";
import "../../models/collection_point.dart";
import "../../models/point_suggestion.dart";


// Classes ----------------------------------------------------------------- //


/// Caso de uso para agregação e cálculo analítico de demandas cívicas e carência territorial.
class GetCivicDemandSummaryUseCase {
  const GetCivicDemandSummaryUseCase();


  // Methods --------------------------------------------------------------- //


  /// Executa o cálculo consolidado de carência territorial e ranking de resíduos.
  CivicDemandSummary execute({
    required List<PointSuggestion> suggestions,
    List<CollectionPoint> existingPoints = const <CollectionPoint>[],
    DateTime? clock,
  }) {
    return CivicDemandSummary.fromData(
      suggestions: suggestions,
      existingPoints: existingPoints,
      now: clock,
    );
  }
}
