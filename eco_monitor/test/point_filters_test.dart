import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/utils/point_filters.dart";


// Helpers ------------------------------------------------------------------ //


CollectionPoint buildPoint({
  required String id,
  required Set<WasteType> wastes,
  PointStatus status = PointStatus.active,
}) {
  return CollectionPoint(
    id: id,
    name: "Ponto $id",
    type: PointType.ecoPoint,
    latitude: -10.95,
    longitude: -37.067,
    address: "Rua de teste, 1",
    acceptedWasteTypes: wastes,
    hours: "Seg a sex, 8h às 18h",
    status: status,
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  final List<CollectionPoint> points = <CollectionPoint>[
    buildPoint(id: "medicines", wastes: {WasteType.medicines}),
    buildPoint(id: "sharps", wastes: {WasteType.sharps}),
    buildPoint(id: "batteries", wastes: {WasteType.batteries}),
    buildPoint(
      id: "inactive",
      wastes: {WasteType.medicines, WasteType.batteries},
      status: PointStatus.inactive,
    ),
  ];

  test("empty selection returns every active point", () {
    final List<CollectionPoint> visible = filterCollectionPoints(
      points,
      const <WasteType>{},
    );

    expect(visible.map((CollectionPoint point) => point.id), [
      "medicines",
      "sharps",
      "batteries",
    ]);
  });

  test("multiple selected residues use the union of accepted types", () {
    final List<CollectionPoint> visible = filterCollectionPoints(
      points,
      const <WasteType>{WasteType.sharps, WasteType.batteries},
    );

    expect(visible.map((CollectionPoint point) => point.id), [
      "sharps",
      "batteries",
    ]);
  });

  test("inactive points are never visible", () {
    final List<CollectionPoint> visible = filterCollectionPoints(
      points,
      const <WasteType>{WasteType.medicines},
    );

    expect(visible.map((CollectionPoint point) => point.id), ["medicines"]);
  });

  test("returns an empty list when no active point accepts the selection", () {
    final List<CollectionPoint> visible = filterCollectionPoints(
      points,
      const <WasteType>{WasteType.electronics},
    );

    expect(visible, isEmpty);
  });
}
