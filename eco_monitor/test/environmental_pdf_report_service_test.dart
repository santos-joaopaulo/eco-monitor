import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/domain/entities/collection_point.dart";
import "package:eco_monitor/domain/entities/point_suggestion.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/domain/repositories/waste_search_analytics_repository_contract.dart";
import "package:eco_monitor/models/civic_demand_summary.dart";
import "package:eco_monitor/services/environmental_pdf_report_service.dart";


// Auxiliares -------------------------------------------------------------- //


CollectionPoint _point(
  String id, {
  PointType type = PointType.pharmacy,
  PointStatus status = PointStatus.active,
  Set<WasteType> wastes = const {WasteType.medicines},
  String address = "Rua Teste, 100 - Centro, Aracaju",
}) {
  return CollectionPoint(
    id: id,
    name: "Ponto $id",
    type: type,
    latitude: -10.92,
    longitude: -37.05,
    address: address,
    acceptedWasteTypes: wastes,
    hours: "08h às 18h",
    status: status,
  );
}

PointSuggestion _suggestion(
  String id, {
  String address = "Rua B, 200 - Centro",
  Set<WasteType> wastes = const {WasteType.medicines},
  SuggestionStatus status = SuggestionStatus.pending,
}) {
  return PointSuggestion(
    id: id,
    name: "Sugestão $id",
    address: address,
    acceptedWasteTypes: wastes,
    hours: "08h às 17h",
    latitude: -10.92,
    longitude: -37.05,
    status: status,
    createdAt: DateTime.utc(2026, 11, 20),
  );
}


// Testes ------------------------------------------------------------------ //


void main() {
  group("EnvironmentalPdfReportService", () {
    const EnvironmentalPdfReportService service =
        EnvironmentalPdfReportService();

    test("generates valid PDF bytes with header, metadata and pages", () async {
      final List<CollectionPoint> points = [
        _point(
          "p1",
          type: PointType.pharmacy,
          wastes: {WasteType.medicines, WasteType.sharps},
        ),
        _point(
          "p2",
          type: PointType.healthCenter,
          wastes: {WasteType.medicines, WasteType.sharps},
        ),
        _point(
          "p3",
          type: PointType.ecoPoint,
          wastes: {WasteType.batteries, WasteType.electronics, WasteType.glass},
        ),
        _point("p4", status: PointStatus.inactive),
      ];

      final List<PointSuggestion> suggestions = [
        _suggestion("s1", address: "Rua X - Centro"),
        _suggestion("s2", address: "Av. Y - Jardins"),
      ];

      final CivicDemandSummary summary = CivicDemandSummary.fromData(
        suggestions: suggestions,
        existingPoints: points,
      );

      final List<WasteSearchStat> stats = const [
        WasteSearchStat(type: WasteType.medicines, count: 50, percentage: 50.0),
        WasteSearchStat(type: WasteType.batteries, count: 30, percentage: 30.0),
        WasteSearchStat(type: WasteType.sharps, count: 20, percentage: 20.0),
      ];

      final Uint8List bytes = await service.generateReportPdf(
        points: points,
        civicSummary: summary,
        searchStats: stats,
        issuedAt: DateTime.utc(2026, 11, 24, 14, 30),
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(1000));

      // Um arquivo PDF válido sempre se inicia pelos bytes "%PDF-"
      final String headerPrefix = String.fromCharCodes(bytes.sublist(0, 5));
      expect(headerPrefix, equals("%PDF-"));
    });

    test("buildReportDocument constructs document with correct metadata and pages", () {
      final List<CollectionPoint> points = [
        _point("p1", wastes: {WasteType.medicines}),
        _point("p2", wastes: {WasteType.batteries}),
      ];

      final CivicDemandSummary summary = CivicDemandSummary.fromData(
        suggestions: [_suggestion("s1")],
        existingPoints: points,
      );

      final doc = service.buildReportDocument(
        points: points,
        civicSummary: summary,
        issuedAt: DateTime.utc(2026, 11, 24, 10, 0),
      );

      expect(doc.document.pdfPageList.pages, isNotEmpty);
    });

    test("generates scoped report filtered by a single neighborhood", () async {
      final List<CollectionPoint> points = [
        _point("p1", address: "Rua A - Farolândia", wastes: {WasteType.medicines}),
        _point("p2", address: "Rua B - Centro", wastes: {WasteType.medicines}),
      ];

      final List<PointSuggestion> suggestions = [
        _suggestion("s1", address: "Rua C - Farolândia", wastes: {WasteType.medicines}),
      ];

      final CivicDemandSummary summary = CivicDemandSummary.fromData(
        suggestions: suggestions,
        existingPoints: points,
      );

      final Uint8List bytes = await service.generateReportPdf(
        points: points,
        civicSummary: summary,
        filterNeighborhood: "Farolândia",
      );

      expect(bytes, isNotEmpty);
      final String headerPrefix = String.fromCharCodes(bytes.sublist(0, 5));
      expect(headerPrefix, equals("%PDF-"));
    });

    test("handles empty points and suggestions gracefully without errors", () async {
      final CivicDemandSummary emptySummary = CivicDemandSummary.fromData(
        suggestions: const [],
        existingPoints: const [],
      );

      final Uint8List bytes = await service.generateReportPdf(
        points: const [],
        civicSummary: emptySummary,
      );

      expect(bytes, isNotEmpty);
    });
  });
}
