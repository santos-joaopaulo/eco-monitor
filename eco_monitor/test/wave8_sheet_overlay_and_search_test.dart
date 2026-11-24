import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:eco_monitor/screens/home_screen.dart";
import "package:eco_monitor/widgets/custom_bottom_nav_bar.dart";
import "package:eco_monitor/widgets/collect_point_sheet.dart";
import "package:eco_monitor/widgets/route_summary_card.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/services/location_service.dart";

class _TestPointRepo implements CollectPointsRepository {
  @override
  bool get hasRemoteSource => false;

  @override
  Future<List<CollectionPoint>> loadOffline() async => [
    CollectionPoint(
      id: "p1",
      name: "Ecoponto Central Aracaju",
      type: PointType.pharmacy,
      latitude: -10.91,
      longitude: -37.06,
      address: "Praça Fausto Cardoso, 10",
      acceptedWasteTypes: const {WasteType.medicines},
      hours: "08:00 - 18:00",
      status: PointStatus.active,
    ),
  ];

  @override
  Future<List<CollectionPoint>> refresh() async => loadOffline();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestLocationService extends LocationService {
  @override
  Future<LocationPermissionState> currentPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<UserLocation?> currentPosition() async =>
      const UserLocation(latitude: -10.93, longitude: -37.08);

  @override
  Stream<UserLocation> positionStream({int distanceFilter = 5}) {
    return Stream<UserLocation>.value(
      const UserLocation(latitude: -10.93, longitude: -37.08),
    );
  }
}

void main() {
  group("Wave 8 Refinements — Bottom Sheet Overlay & Search Focus", () {
    testWidgets(
      "Search bar in HomeScreen retains focus on first tap without premature close",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                repository: _TestPointRepo(),
                locationService: _TestLocationService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Aciona o botão de busca na tela para expandir a barra de pesquisa
        final Finder searchButton = find.byTooltip("Buscar resíduo");
        expect(searchButton, findsOneWidget);
        await tester.tap(searchButton);
        await tester.pumpAndSettle();

        final Finder searchField = find.byType(TextField);
        expect(searchField, findsOneWidget);

        final TextField textFieldBefore = tester.widget<TextField>(searchField);
        final FocusNode focusNode = textFieldBefore.focusNode!;
        expect(focusNode.hasFocus, isTrue);

        // Simulando passagem do tempo (teclado aberto)
        await tester.pump(const Duration(milliseconds: 500));
        expect(focusNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      "Opening CollectPointSheet and RouteSummaryCard notifies and hides bottomNavigationBar",
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        bool isSheetActive = false;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  extendBody: true,
                  body: HomeScreen(
                    repository: _TestPointRepo(),
                    locationService: _TestLocationService(),
                    onActiveSheetChanged: (bool active) {
                      setState(() {
                        isSheetActive = active;
                      });
                    },
                  ),
                  bottomNavigationBar: CustomBottomNavBar(
                    currentIndex: 0,
                    onTap: (_) {},
                    isVisible: !isSheetActive,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inicialmente a barra inferior está visível
        expect(find.text("home"), findsOneWidget);
        expect(find.byType(CollectPointSheet), findsNothing);

        // Toca no ponto de coleta para abrir o CollectPointSheet
        await tester.tap(find.text("Ecoponto Central Aracaju"));
        await tester.pumpAndSettle();

        // O CollectPointSheet é exibido e a barra de navegação foi ocultada/sobreposta
        expect(find.byType(CollectPointSheet), findsOneWidget);
        expect(isSheetActive, isTrue);
        expect(find.text("home"), findsNothing);

        // Inicia rota para exibir o RouteSummaryCard
        await tester.tap(find.text("Iniciar rota"));
        await tester.pumpAndSettle();

        // O RouteSummaryCard permanece sobrepondo a barra de navegação
        expect(find.byType(RouteSummaryCard), findsOneWidget);
        expect(isSheetActive, isTrue);
        expect(find.text("home"), findsNothing);

        // Encerra a rota
        await tester.tap(find.text("Encerrar rota"));
        await tester.pumpAndSettle();

        // Volta ao estado inicial: sem sheet e navbar visível novamente
        expect(find.byType(RouteSummaryCard), findsNothing);
        expect(isSheetActive, isFalse);
        expect(find.text("home"), findsOneWidget);
      },
    );
  });
}
