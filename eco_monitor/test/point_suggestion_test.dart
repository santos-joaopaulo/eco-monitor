import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/point_suggestion.dart";

void main() {
  test("toJson serializes anonymously without id or null coordinates", () {
    final PointSuggestion suggestion = PointSuggestion(
      id: "local-temp-id",
      name: "Farmácia Nova Esperança",
      address: "Rua das Flores, 120 — Centro",
      acceptedWasteTypes: const {WasteType.medicines, WasteType.sharps},
      hours: "Seg a sex, 8h às 18h",
      latitude: null,
      longitude: null,
      status: SuggestionStatus.pending,
      createdAt: DateTime.utc(2026, 11, 17, 14),
    );

    final Map<String, dynamic> json = suggestion.toJson();

    expect(json.containsKey("id"), isFalse);
    expect(json.containsKey("latitude"), isFalse);
    expect(json.containsKey("longitude"), isFalse);
    expect(
      json.keys.toSet(),
      equals({
        "name",
        "address",
        "acceptedWasteTypes",
        "hours",
        "status",
        "createdAt",
      }),
    );
    expect(json["acceptedWasteTypes"], ["medicines", "sharps"]);
    expect(json["status"], "pending");
  });

  test("toJson includes coordinates when provided", () {
    final PointSuggestion suggestion = PointSuggestion(
      id: "",
      name: "Ecoponto Bairro Novo",
      address: "Av. Principal, 500",
      acceptedWasteTypes: const {WasteType.electronics},
      hours: "Seg a sáb, 8h às 17h",
      latitude: -10.95,
      longitude: -37.06,
      status: SuggestionStatus.pending,
      createdAt: DateTime.utc(2026, 11, 17, 15),
    );

    final Map<String, dynamic> json = suggestion.toJson();

    expect(json["latitude"], -10.95);
    expect(json["longitude"], -37.06);
  });

  test("fromJson falls back to pending on unknown status", () {
    final PointSuggestion parsed = PointSuggestion.fromJson(<String, dynamic>{
      "id": "sug-1",
      "name": "UBS Teste",
      "address": "Rua A, 10",
      "acceptedWasteTypes": ["sharps", "invalid"],
      "hours": "7h às 17h",
      "status": "mystery",
      "createdAt": "2026-11-17T10:00:00Z",
    });

    expect(parsed.status, SuggestionStatus.pending);
    expect(parsed.acceptedWasteTypes, const {WasteType.sharps});
    expect(parsed.latitude, isNull);
    expect(parsed.longitude, isNull);
    expect(parsed.createdAt, DateTime.utc(2026, 11, 17, 10));
  });
}
