import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/widgets/collect_points_list_view.dart";


// Helpers ------------------------------------------------------------------ //


CollectionPoint _buildPoint({
  required String id,
  required String name,
  required String address,
  required PointType type,
  required double latitude,
  required double longitude,
  Set<WasteType> acceptedWasteTypes = const <WasteType>{WasteType.medicines},
  PointStatus status = PointStatus.active,
}) {
  return CollectionPoint(
    id: id,
    name: name,
    type: type,
    latitude: latitude,
    longitude: longitude,
    address: address,
    acceptedWasteTypes: acceptedWasteTypes,
    hours: "Seg a Sex, 08h às 18h",
    status: status,
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  final CollectionPoint pointFar = _buildPoint(
    id: "p1",
    name: "Farmácia Zona Sul",
    address: "Av. Beira Mar, 200",
    type: PointType.pharmacy,
    latitude: -11.0100,
    longitude: -37.0700,
    acceptedWasteTypes: const <WasteType>{WasteType.medicines},
  );

  final CollectionPoint pointNear = _buildPoint(
    id: "p2",
    name: "UBS Centro",
    address: "Rua São Cristóvão, 100",
    type: PointType.healthCenter,
    latitude: -10.9501,
    longitude: -37.0671,
    acceptedWasteTypes: const <WasteType>{
      WasteType.medicines,
      WasteType.sharps,
    },
  );

  testWidgets("renders list of collection points with details", (
    WidgetTester tester,
  ) async {
    CollectionPoint? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectPointsListView(
            points: <CollectionPoint>[pointFar, pointNear],
            onPointSelected: (CollectionPoint p) => selected = p,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Farmácia Zona Sul"), findsOneWidget);
    expect(find.text("Av. Beira Mar, 200"), findsOneWidget);
    expect(find.text("UBS Centro"), findsOneWidget);
    expect(find.text("Rua São Cristóvão, 100"), findsOneWidget);
    expect(find.text("Ativo"), findsNWidgets(2));

    await tester.tap(find.text("UBS Centro"));
    await tester.pumpAndSettle();

    expect(selected?.id, "p2");
  });

  testWidgets("sorts by distance and shows distance tags when location is provided", (
    WidgetTester tester,
  ) async {
    const UserLocation user = UserLocation(
      latitude: -10.9500,
      longitude: -37.0670,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectPointsListView(
            points: <CollectionPoint>[pointFar, pointNear],
            userLocation: user,
            onPointSelected: (CollectionPoint p) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Farmácia Zona Sul"), findsOneWidget);
    expect(find.text("UBS Centro"), findsOneWidget);

    // UBS Centro is ~15m away, should show distance tag
    expect(find.textContaining("m"), findsWidgets);

    // UBS Centro should appear first in the list since it is much closer
    final Finder firstPointName = find.text("UBS Centro");
    final Finder secondPointName = find.text("Farmácia Zona Sul");
    expect(
      tester.getTopLeft(firstPointName).dy <
          tester.getTopLeft(secondPointName).dy,
      isTrue,
    );
  });

  testWidgets("displays empty state when points list is empty", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CollectPointsListView(
            points: const <CollectionPoint>[],
            activeFilter: const <WasteType>{WasteType.electronics},
            onPointSelected: (CollectionPoint p) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Nenhum ponto aceita os resíduos selecionados."),
      findsOneWidget,
    );
    expect(
      find.text("Tente alterar os filtros acima para encontrar outros pontos."),
      findsOneWidget,
    );
  });
}
