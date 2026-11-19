import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/firestore_helpers.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/models/collection_point.dart";

void main() {
  test("normalizeFirestoreData converts Timestamp and GeoPoint for models", () {
    final Timestamp start = Timestamp.fromDate(DateTime.utc(2026, 11, 15, 8));
    final Timestamp end = Timestamp.fromDate(DateTime.utc(2026, 11, 30, 17));

    final Map<String, dynamic> normalized = normalizeFirestoreData(
      <String, dynamic>{
        "title": "Mutirão Firestore",
        "description": "Coleta de eletrônicos.",
        "wasteTypes": <String>["electronics"],
        "locationName": "Orla",
        "address": "Av. Santos Dumont",
        "location": const GeoPoint(-10.9896, -37.0432),
        "startDate": start,
        "endDate": end,
        "status": "active",
      },
      documentId: "doc-123",
    );

    final Campaign campaign = Campaign.fromJson(normalized);

    expect(campaign.id, "doc-123");
    expect(campaign.latitude, -10.9896);
    expect(campaign.longitude, -37.0432);
    expect(campaign.startDate, DateTime.utc(2026, 11, 15, 8));
    expect(campaign.endDate, DateTime.utc(2026, 11, 30, 17));
    expect(campaign.accepts(WasteType.electronics), isTrue);
  });

  test(
    "extractFirestoreTimestamp handles Timestamp, DateTime, String, int",
    () {
      final DateTime expected = DateTime.utc(2026, 11, 17, 12);

      expect(extractFirestoreTimestamp(Timestamp.fromDate(expected)), expected);
      expect(extractFirestoreTimestamp(expected), expected);
      expect(extractFirestoreTimestamp(expected.toIso8601String()), expected);
      expect(
        extractFirestoreTimestamp(expected.millisecondsSinceEpoch),
        expected,
      );
      expect(extractFirestoreTimestamp(null), isNull);
    },
  );
}
