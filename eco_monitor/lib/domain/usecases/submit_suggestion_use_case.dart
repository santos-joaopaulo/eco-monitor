import "../entities/point_suggestion.dart";
import "../entities/waste_type.dart";
import "../repositories/point_suggestions_repository_contract.dart";


// Use cases --------------------------------------------------------------- //


/// Caso de uso para validação e submissão de sugestões anônimas de pontos (Domínio).
class SubmitSuggestionUseCase {
  const SubmitSuggestionUseCase(this._repository);

  final IPointSuggestionsRepository _repository;

  /// Valida as regras de negócio e submete a sugestão de ponto.
  Future<SuggestionSubmitResult> execute({
    required String name,
    required String address,
    required Set<WasteType> acceptedWasteTypes,
    required String hours,
    double? latitude,
    double? longitude,
  }) async {
    final String trimmedName = name.trim();
    final String trimmedAddress = address.trim();

    if (trimmedName.length < 2 || trimmedName.length > 120) {
      throw ArgumentError("O nome deve ter entre 2 e 120 caracteres.");
    }

    if (trimmedAddress.length < 5 || trimmedAddress.length > 200) {
      throw ArgumentError("O endereço deve ter entre 5 e 200 caracteres.");
    }

    if (acceptedWasteTypes.isEmpty) {
      throw ArgumentError("Selecione ao menos um tipo de resíduo aceito.");
    }

    final PointSuggestion suggestion = PointSuggestion(
      id: "",
      name: trimmedName,
      address: trimmedAddress,
      acceptedWasteTypes: acceptedWasteTypes,
      hours: hours.trim(),
      latitude: latitude,
      longitude: longitude,
      status: SuggestionStatus.pending,
      createdAt: DateTime.now().toUtc(),
    );

    return _repository.submit(suggestion);
  }
}
