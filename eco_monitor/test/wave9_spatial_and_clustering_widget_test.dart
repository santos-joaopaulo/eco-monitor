import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/utils/spatial_index.dart";
import "package:eco_monitor/widgets/home_map_top_bar.dart";
import "package:eco_monitor/widgets/location_notice.dart";
import "package:eco_monitor/widgets/point_pin.dart";
import "package:eco_monitor/widgets/radius_filter_bar.dart";


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Wave 9 — Radius Selector & Spatial Filtering Widgets (T11.1)", () {
    testWidgets("RadiusFilterBar renders all 4 options and notifies on tap", (
      WidgetTester tester,
    ) async {
      ProximityRadius activeRadius = ProximityRadius.fiveKm;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return RadiusFilterBar(
                  selectedRadius: activeRadius,
                  onChanged: (ProximityRadius next) {
                    setState(() {
                      activeRadius = next;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verifica a renderização das opções
      expect(find.text("2 km"), findsOneWidget);
      expect(find.text("5 km"), findsOneWidget);
      expect(find.text("10 km"), findsOneWidget);
      expect(find.text("Todos"), findsOneWidget);

      // Toca em '10 km'
      await tester.tap(find.text("10 km"));
      await tester.pumpAndSettle();

      expect(activeRadius, equals(ProximityRadius.tenKm));

      // Toca em '2 km'
      await tester.tap(find.text("2 km"));
      await tester.pumpAndSettle();

      expect(activeRadius, equals(ProximityRadius.twoKm));
    });

    testWidgets("EmptyRadiusNoticePill displays friendly message and expands on tap", (
      WidgetTester tester,
    ) async {
      bool expanded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyRadiusNoticePill(
              radius: ProximityRadius.twoKm,
              onExpand: () {
                expanded = true;
              },
            ),
          ),
        ),
      );

      expect(
        find.text("Nenhum ecoponto em até 2 km"),
        findsOneWidget,
      );
      expect(find.byType(LocationNotice), findsOneWidget);
      expect(find.text("Expandir"), findsOneWidget);

      await tester.tap(find.text("Expandir"));
      await tester.pumpAndSettle();

      expect(expanded, isTrue);
    });

    testWidgets("HomeMapTopBar integrates radius bar and empty notice gracefully", (
      WidgetTester tester,
    ) async {
      ProximityRadius selected = ProximityRadius.fiveKm;
      bool expanded = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeMapTopBar(
              selectedWasteTypes: const <WasteType>{},
              onFilterChanged: (_) {},
              focusedCampaign: null,
              onClearCampaign: null,
              showMapboxTokenWarning: false,
              isLoadingPoints: false,
              isEmptyResult: false,
              emptyMessage: "Nenhum ponto",
              locationNotice: null,
              isListMode: false,
              selectedRadius: selected,
              onRadiusChanged: (r) => selected = r,
              isRadiusEmpty: true,
              onExpandRadius: () => expanded = true,
            ),
          ),
        ),
      );

      // Verifica presença da barra de raio
      expect(find.byType(RadiusFilterBar), findsOneWidget);

      // Verifica presença do aviso de expansão quando isRadiusEmpty == true
      expect(find.byType(EmptyRadiusNoticePill), findsOneWidget);

      // Aciona o botão Expandir
      await tester.tap(find.text("Expandir"));
      await tester.pumpAndSettle();

      expect(expanded, isTrue);
    });
  });

  group("Wave 9 — Mapbox Clustering Render & Visuals (T11.2)", () {
    test("PointPin.renderCluster produces valid PNG bytes with badge count", () async {
      final Uint8List cluster2 = await PointPin.renderCluster(count: 2);
      expect(cluster2, isNotEmpty);
      expect(cluster2.length, greaterThan(100));

      final Uint8List cluster12 = await PointPin.renderCluster(count: 12);
      expect(cluster12, isNotEmpty);

      // Valida que o cache em memória reutiliza os bytes idênticos
      final Uint8List cluster2Cached = await PointPin.renderCluster(count: 2);
      expect(identical(cluster2, cluster2Cached), isTrue);

      final Uint8List clusterLarge = await PointPin.renderCluster(count: 150);
      expect(clusterLarge, isNotEmpty);
    });
  });
}
