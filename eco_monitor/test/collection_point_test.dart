import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/models/collection_point.dart";

// Helpers ------------------------------------------------------------------ //

CollectionPoint pointWithWastes(Set<WasteType> wastes) {
  return CollectionPoint(
    id: "point-1",
    name: "Ponto de teste",
    type: PointType.pharmacy,
    latitude: -10.95,
    longitude: -37.067,
    address: "Rua de teste, 1",
    acceptedWasteTypes: wastes,
    hours: "Seg a sex, 8h às 18h",
    status: PointStatus.active,
  );
}

// Tests -------------------------------------------------------------------- //

void main() {
  test("fromJson reads every field of a valid point", () {
    final CollectionPoint point = CollectionPoint.fromJson({
      "id": "farmacia-central",
      "name": "Farmácia Central",
      "type": "pharmacy",
      "latitude": -10.9113,
      "longitude": -37.0715,
      "address": "Av. Barão de Maruim, 450 — Centro",
      "acceptedWasteTypes": ["medicines", "batteries"],
      "hours": "Seg a sex, 7h às 19h",
      "status": "active",
    });

    expect(point.id, "farmacia-central");
    expect(point.name, "Farmácia Central");
    expect(point.type, PointType.pharmacy);
    expect(point.latitude, -10.9113);
    expect(point.longitude, -37.0715);
    expect(point.address, "Av. Barão de Maruim, 450 — Centro");
    expect(point.acceptedWasteTypes, {
      WasteType.medicines,
      WasteType.batteries,
    });
    expect(point.hours, "Seg a sex, 7h às 19h");
    expect(point.status, PointStatus.active);
    expect(point.isActive, isTrue);
  });

  test("fromJson tolerates missing fields", () {
    final CollectionPoint point = CollectionPoint.fromJson(const {});

    expect(point.id, "");
    expect(point.name, "");
    expect(point.type, PointType.ecoPoint);
    expect(point.latitude, 0);
    expect(point.longitude, 0);
    expect(point.address, "");
    expect(point.acceptedWasteTypes, isEmpty);
    expect(point.hours, "");
    expect(point.status, PointStatus.inactive);
    expect(point.isActive, isFalse);
  });

  test("fromJson ignores unknown waste types and statuses", () {
    final CollectionPoint point = CollectionPoint.fromJson({
      "id": "ponto-1",
      "type": "unknown-type",
      "acceptedWasteTypes": ["batteries", "oil", 42],
      "status": "closed",
    });

    expect(point.type, PointType.ecoPoint);
    expect(point.acceptedWasteTypes, {WasteType.batteries});
    expect(point.status, PointStatus.inactive);
  });

  test("fromJson parses numeric strings for coordinates", () {
    final CollectionPoint point = CollectionPoint.fromJson({
      "latitude": "-10.95",
      "longitude": "-37.067",
    });

    expect(point.latitude, -10.95);
    expect(point.longitude, -37.067);
  });

  test("accepts checks the accepted waste types", () {
    final CollectionPoint point = pointWithWastes({WasteType.sharps});

    expect(point.accepts(WasteType.sharps), isTrue);
    expect(point.accepts(WasteType.medicines), isFalse);
    expect(point.acceptsAny({WasteType.medicines, WasteType.sharps}), isTrue);
    expect(point.acceptsAny({WasteType.medicines}), isFalse);
    expect(point.acceptsAny(const {}), isTrue);
  });

  test("equality is based on the point id", () {
    final CollectionPoint first = pointWithWastes({WasteType.medicines});
    final CollectionPoint sameId = CollectionPoint(
      id: first.id,
      name: "Outro nome",
      type: PointType.ecoPoint,
      latitude: 0,
      longitude: 0,
      address: "",
      acceptedWasteTypes: const {},
      hours: "",
      status: PointStatus.inactive,
    );

    expect(first, sameId);
    expect(first.hashCode, sameId.hashCode);
  });

  test("toJson round-trips the accepted waste types", () {
    final CollectionPoint point = pointWithWastes({
      WasteType.batteries,
      WasteType.medicines,
    });

    final CollectionPoint parsed = CollectionPoint.fromJson(point.toJson());

    expect(parsed, point);
    expect(parsed.acceptedWasteTypes, point.acceptedWasteTypes);
    expect(parsed.toJson()["acceptedWasteTypes"], ["batteries", "medicines"]);
  });
}
