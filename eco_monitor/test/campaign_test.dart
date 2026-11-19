import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/models/collection_point.dart";

void main() {
  test("fromJson parses valid campaign fields and waste types", () {
    final Campaign campaign = Campaign.fromJson(<String, dynamic>{
      "id": "camp-1",
      "title": "Mutirão de Eletrônicos",
      "description": "Coleta de celulares e baterias.",
      "wasteTypes": ["electronics", "batteries"],
      "locationName": "Parque da Sementeira",
      "address": "Av. Jornalista Santos Santana",
      "latitude": -10.9412,
      "longitude": -37.0537,
      "startDate": "2026-11-15T08:00:00Z",
      "endDate": "2026-11-30T17:00:00Z",
      "status": "active",
    });

    expect(campaign.id, "camp-1");
    expect(campaign.isActive, isTrue);
    expect(campaign.isUpcoming, isFalse);
    expect(campaign.accepts(WasteType.electronics), isTrue);
    expect(campaign.accepts(WasteType.batteries), isTrue);
    expect(campaign.accepts(WasteType.medicines), isFalse);
    expect(campaign.startDate, DateTime.utc(2026, 11, 15, 8));
    expect(campaign.endDate, DateTime.utc(2026, 11, 30, 17));
  });

  test("fromJson defensively falls back to finished on unknown status", () {
    final Campaign campaign = Campaign.fromJson(<String, dynamic>{
      "id": "camp-unknown",
      "wasteTypes": ["medicines", "nuclear"],
      "status": "unknown_status",
      "startDate": DateTime.utc(2026, 12, 1),
      "endDate": DateTime.utc(2026, 12, 2).millisecondsSinceEpoch,
    });

    expect(campaign.status, CampaignStatus.finished);
    expect(campaign.isActive, isFalse);
    expect(campaign.wasteTypes, const {WasteType.medicines});
    expect(campaign.startDate, DateTime.utc(2026, 12, 1));
    expect(campaign.endDate, DateTime.utc(2026, 12, 2));
  });

  test("toJson round-trips all fields and equality is based on id", () {
    final Campaign original = Campaign(
      id: "camp-2",
      title: "Campanha Pilhas",
      description: "Descrição",
      wasteTypes: const {WasteType.batteries, WasteType.electronics},
      locationName: "Centro",
      address: "Praça Fausto Cardoso",
      latitude: -10.9111,
      longitude: -37.0488,
      startDate: DateTime.utc(2026, 12, 1, 9),
      endDate: DateTime.utc(2026, 12, 5, 17),
      status: CampaignStatus.upcoming,
    );

    final Campaign roundTripped = Campaign.fromJson(original.toJson());

    expect(roundTripped, equals(original));
    expect(roundTripped.hashCode, original.hashCode);
    expect(roundTripped.title, original.title);
    expect(roundTripped.status, CampaignStatus.upcoming);
    expect(roundTripped.wasteTypes, original.wasteTypes);
  });
}
