import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/domain/entities/collection_point.dart";
import "package:eco_monitor/domain/entities/point_suggestion.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/domain/usecases/get_civic_demand_summary_use_case.dart";
import "package:eco_monitor/models/civic_demand_summary.dart";


// Auxiliares -------------------------------------------------------------- //


PointSuggestion _createSuggestion({
  required String id,
  required String name,
  required String address,
  required Set<WasteType> wastes,
  SuggestionStatus status = SuggestionStatus.pending,
}) {
  return PointSuggestion(
    id: id,
    name: name,
    address: address,
    acceptedWasteTypes: wastes,
    hours: "Seg a Sex: 08h às 17h",
    latitude: -10.92,
    longitude: -37.05,
    status: status,
    createdAt: DateTime.utc(2026, 11, 20),
  );
}

CollectionPoint _createPoint({
  required String id,
  required String address,
  PointStatus status = PointStatus.active,
}) {
  return CollectionPoint(
    id: id,
    name: "Ponto $id",
    type: PointType.pharmacy,
    latitude: -10.92,
    longitude: -37.05,
    address: address,
    acceptedWasteTypes: const {WasteType.medicines},
    hours: "08h às 18h",
    status: status,
  );
}


// Testes ------------------------------------------------------------------ //


void main() {
  group("CivicDemandSummary Address Extraction", () {
    test("extracts neighborhood from standard hyphen format", () {
      expect(
        CivicDemandSummary.extractNeighborhood(
          "Rua das Laranjeiras, 100 - Centro, Aracaju",
        ),
        equals("Centro"),
      );
      expect(
        CivicDemandSummary.extractNeighborhood(
          "Av. Beira Mar, 400 - 13 de Julho",
        ),
        equals("13 de Julho"),
      );
    });

    test("extracts neighborhood from comma-separated format", () {
      expect(
        CivicDemandSummary.extractNeighborhood(
          "Av. Santos Dumont, 1500, Atalaia, Aracaju",
        ),
        equals("Atalaia"),
      );
    });

    test("falls back cleanly on empty or direct neighborhood names", () {
      expect(CivicDemandSummary.extractNeighborhood(""), equals("Não informado"));
      expect(
        CivicDemandSummary.extractNeighborhood("Farolândia"),
        equals("Farolândia"),
      );
    });
  });

  group("CivicDemandSummary Aggregation & Shortage Calculation", () {
    test("groups suggestions by neighborhood and calculates statuses correctly", () {
      final List<PointSuggestion> suggestions = [
        _createSuggestion(
          id: "s1",
          name: "Sugestão 1",
          address: "Rua A - Centro",
          wastes: {WasteType.medicines, WasteType.sharps},
          status: SuggestionStatus.pending,
        ),
        _createSuggestion(
          id: "s2",
          name: "Sugestão 2",
          address: "Rua B - Centro",
          wastes: {WasteType.medicines},
          status: SuggestionStatus.reviewing,
        ),
        _createSuggestion(
          id: "s3",
          name: "Sugestão 3",
          address: "Rua C - Centro",
          wastes: {WasteType.batteries},
          status: SuggestionStatus.approved,
        ),
        _createSuggestion(
          id: "s4",
          name: "Sugestão 4",
          address: "Rua D - Jardins",
          wastes: {WasteType.glass},
          status: SuggestionStatus.rejected,
        ),
      ];

      final summary = CivicDemandSummary.fromData(suggestions: suggestions);

      expect(summary.totalSuggestions, equals(4));
      expect(summary.pendingCount, equals(1));
      expect(summary.reviewingCount, equals(1));
      expect(summary.approvedCount, equals(1));
      expect(summary.rejectedCount, equals(1));

      final centroDemand = summary.demandFor("Centro");
      expect(centroDemand, isNotNull);
      expect(centroDemand!.totalSuggestions, equals(3));
      expect(centroDemand.pendingCount, equals(1));
      expect(centroDemand.reviewingCount, equals(1));
      expect(centroDemand.approvedCount, equals(1));
      expect(centroDemand.rejectedCount, equals(0));

      final jardinsDemand = summary.demandFor("Jardins");
      expect(jardinsDemand, isNotNull);
      expect(jardinsDemand!.totalSuggestions, equals(1));
      expect(jardinsDemand.rejectedCount, equals(1));
    });

    test("ranks waste categories and calculates accurate percentages", () {
      final List<PointSuggestion> suggestions = [
        _createSuggestion(
          id: "s1",
          name: "Sugestão 1",
          address: "Rua A - Centro",
          wastes: {WasteType.medicines, WasteType.batteries},
        ),
        _createSuggestion(
          id: "s2",
          name: "Sugestão 2",
          address: "Rua B - Centro",
          wastes: {WasteType.medicines},
        ),
      ];

      final summary = CivicDemandSummary.fromData(suggestions: suggestions);
      final centro = summary.demandFor("Centro")!;

      expect(centro.rankedWastes.first.type, equals(WasteType.medicines));
      expect(centro.rankedWastes.first.count, equals(2));
      // Total de resíduos solicitados = 3 (2 medicines, 1 batteries) -> medicines ~66.7%, batteries ~33.3%
      expect(centro.wastePercentage(WasteType.medicines), closeTo(66.6, 0.5));
      expect(centro.wastePercentage(WasteType.batteries), closeTo(33.3, 0.5));
      expect(centro.topRequestedWaste, equals(WasteType.medicines));
    });

    test("mitigates territorial shortage when active collection points exist", () {
      // Bairro Atalaia com 3 pedidos pendentes e 0 pontos ativos
      // Bairro Centro com 3 pedidos pendentes e 2 pontos ativos
      final List<PointSuggestion> suggestions = [
        _createSuggestion(
          id: "s1",
          name: "S1",
          address: "Av. Santos Dumont - Atalaia",
          wastes: {WasteType.medicines},
          status: SuggestionStatus.pending,
        ),
        _createSuggestion(
          id: "s2",
          name: "S2",
          address: "Rua 2 - Atalaia",
          wastes: {WasteType.medicines},
          status: SuggestionStatus.pending,
        ),
        _createSuggestion(
          id: "s3",
          name: "S3",
          address: "Rua 3 - Atalaia",
          wastes: {WasteType.medicines},
          status: SuggestionStatus.pending,
        ),
        _createSuggestion(
          id: "s4",
          name: "S4",
          address: "Rua 4 - Centro",
          wastes: {WasteType.medicines},
          status: SuggestionStatus.pending,
        ),
        _createSuggestion(
          id: "s5",
          name: "S5",
          address: "Rua 5 - Centro",
          wastes: {WasteType.medicines},
          status: SuggestionStatus.pending,
        ),
        _createSuggestion(
          id: "s6",
          name: "S6",
          address: "Rua 6 - Centro",
          wastes: {WasteType.medicines},
          status: SuggestionStatus.pending,
        ),
      ];

      final List<CollectionPoint> existingPoints = [
        _createPoint(id: "p1", address: "Rua Centro 1 - Centro"),
        _createPoint(id: "p2", address: "Rua Centro 2 - Centro"),
      ];

      final summary = CivicDemandSummary.fromData(
        suggestions: suggestions,
        existingPoints: existingPoints,
      );

      final atalaia = summary.demandFor("Atalaia")!;
      final centro = summary.demandFor("Centro")!;

      expect(atalaia.activePointsCount, equals(0));
      expect(centro.activePointsCount, equals(2));

      // Atalaia deve ter um shortageScore significativamente maior que Centro
      expect(atalaia.shortageScore, greaterThan(centro.shortageScore));
      expect(atalaia.shortageLevel, equals(ShortageLevel.high));
      expect(atalaia.shortageLevelLabel, equals("Alta Carência"));

      // Na ordenação prioritária, Atalaia deve vir antes de Centro
      expect(summary.neighborhoodDemands.first.neighborhood, equals("Atalaia"));
    });

    test("GetCivicDemandSummaryUseCase executes and returns summary", () {
      const useCase = GetCivicDemandSummaryUseCase();
      final summary = useCase.execute(
        suggestions: [
          _createSuggestion(
            id: "s1",
            name: "S1",
            address: "Rua X - Bugio",
            wastes: {WasteType.glass},
          ),
        ],
        clock: DateTime.utc(2026, 11, 24, 10, 0),
      );

      expect(summary.totalSuggestions, equals(1));
      expect(summary.generatedAt, equals(DateTime.utc(2026, 11, 24, 10, 0)));
      expect(summary.neighborhoodDemands.first.neighborhood, equals("Bugio"));
    });
  });
}
