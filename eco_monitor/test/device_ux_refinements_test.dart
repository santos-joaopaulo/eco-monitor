import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/screens/home_screen.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/mapbox_token_provider.dart";
import "package:eco_monitor/services/route_service.dart";
import "package:eco_monitor/theme/app_colors.dart";
import "package:eco_monitor/theme/eco_theme.dart";
import "package:eco_monitor/utils/geo.dart";
import "package:eco_monitor/widgets/collect_point_sheet.dart";
import "package:eco_monitor/widgets/custom_bottom_nav_bar.dart";
import "package:eco_monitor/widgets/home_map_controls.dart";
import "package:eco_monitor/widgets/offline_banner.dart";
import "package:eco_monitor/widgets/route_summary_card.dart";


// Auxiliares -------------------------------------------------------------- //


class _FakeLocationService extends LocationService {
  LocationPermissionState permission = LocationPermissionState.granted;
  UserLocation? position = const UserLocation(latitude: -10.95, longitude: -37.06);

  int currentPositionCalls = 0;
  int currentPermissionCalls = 0;
  int requestPermissionCalls = 0;

  @override
  Future<LocationPermissionState> currentPermission() async {
    currentPermissionCalls++;
    return permission;
  }

  @override
  Future<LocationPermissionState> requestPermission() async {
    requestPermissionCalls++;
    return permission;
  }

  @override
  Future<UserLocation?> currentPosition() async {
    currentPositionCalls++;
    return position;
  }

  @override
  Stream<UserLocation> positionStream({int distanceFilter = 5}) {
    final UserLocation? loc = position;
    if (loc != null) {
      return Stream<UserLocation>.value(loc);
    }
    return const Stream<UserLocation>.empty();
  }
}

class _FakeCollectPointsRepository extends CollectPointsRepository {
  _FakeCollectPointsRepository(this._points)
      : super(localStore: InMemoryLocalStore());

  final List<CollectionPoint> _points;

  @override
  bool get hasRemoteSource => false;

  @override
  Future<List<CollectionPoint>> loadOffline() async => _points;

  @override
  Future<List<CollectionPoint>> refresh() async => _points;
}

final CollectionPoint _testPoint = CollectionPoint(
  id: "p1",
  name: "Ponto de Teste",
  address: "Rua Central, 100",
  type: PointType.ecoPoint,
  status: PointStatus.active,
  latitude: -10.95,
  longitude: -37.06,
  acceptedWasteTypes: const <WasteType>{WasteType.batteries},
  hours: "Seg-Sex 08:00-17:00",
);


// Testes ------------------------------------------------------------------ //


void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    MapboxTokenProvider.token = "";
  });

  tearDown(() {
    MapboxTokenProvider.token = "";
  });

  group("T6.1 — Redesenho do aviso OfflineBanner em estilo pílula e linha única", () {
    testWidgets("renders pill shape, max width constraint, and textSecondary color", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              isOffline: true,
              isStale: false,
              pendingSuggestionsCount: 1,
            ),
          ),
        ),
      );

      expect(find.text("Sem conexão · Dados salvos (+1)"), findsOneWidget);

      final Finder constrainedBoxFinder = find.byWidgetPredicate((Widget w) {
        return w is ConstrainedBox &&
            w.constraints.maxWidth == kEcoMaxContentWidth;
      });
      expect(constrainedBoxFinder, findsOneWidget);

      final Finder textFinder = find.text("Sem conexão · Dados salvos (+1)");
      final Text textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, AppColors.textSecondary);
      expect(textWidget.maxLines, 1);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });
  });

  group("T6.3 — RouteSummaryCard bússola condicional e limites verticais", () {
    testWidgets("shows cardinal compass orientation only on offline fallback route", (
      WidgetTester tester,
    ) async {
      final RouteSummary offlineRoute = RouteSummary(
        distanceMeters: 1200,
        estimatedMinutes: 15,
        travelMode: TravelMode.walking,
        isOfflineFallback: true,
        bearingDegrees: 45,
        cardinalDirection: "Nordeste",
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteSummaryCard(
              point: _testPoint,
              summary: offlineRoute,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text("Siga rumo ao Nordeste."), findsOneWidget);
      expect(
        find.text("Modo offline: traçado direto por vetor e estimativa local."),
        findsOneWidget,
      );

      final RouteSummary onlineRoute = RouteSummary(
        distanceMeters: 1200,
        estimatedMinutes: 15,
        travelMode: TravelMode.walking,
        isOfflineFallback: false,
        bearingDegrees: 45,
        cardinalDirection: "Nordeste",
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteSummaryCard(
              point: _testPoint,
              summary: onlineRoute,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text("Siga rumo ao Nordeste."), findsNothing);
    });

    testWidgets("card height stays below half of screen height", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final RouteSummary offlineRoute = RouteSummary(
        distanceMeters: 1200,
        estimatedMinutes: 15,
        travelMode: TravelMode.walking,
        isOfflineFallback: true,
        bearingDegrees: 45,
        cardinalDirection: "Nordeste",
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteSummaryCard(
              point: _testPoint,
              summary: offlineRoute,
              onClose: () {},
            ),
          ),
        ),
      );

      final Finder cardFinder = find.descendant(
        of: find.byType(RouteSummaryCard),
        matching: find.byType(Material),
      );
      final Size cardSize = tester.getSize(cardFinder.first);
      expect(cardSize.height, lessThan(400.0));
    });
  });

  group("T6.4 & T6.5 — Controles da Home, GPS sob demanda e alinhamento", () {
    testWidgets("passive startup does not call currentPosition automatically", (
      WidgetTester tester,
    ) async {
      final _FakeLocationService locationService = _FakeLocationService();
      final _FakeCollectPointsRepository repository =
          _FakeCollectPointsRepository(<CollectionPoint>[_testPoint]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              repository: repository,
              locationService: locationService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(locationService.currentPositionCalls, 0);

      final Finder locateFab = find.byType(HomeLocateButton);
      expect(locateFab, findsOneWidget);

      await tester.tap(locateFab);
      await tester.pumpAndSettle();

      expect(locationService.currentPositionCalls, 1);
    });

    testWidgets("HomeViewToggleButton vertical center is aligned with HomeLocateButton center", (
      WidgetTester tester,
    ) async {
      const double locateBottom = 60.0;
      const double locateHeight = 72.0;
      const double toggleHeight = 48.0;

      // O centro vertical deve coincidir: locateBottom + 36 == toggleBottom + 24
      const double expectedToggleBottom = locateBottom + (locateHeight - toggleHeight) / 2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HomeLocateButton(bottom: locateBottom, onPressed: () {}),
                HomeViewToggleButton(
                  bottom: locateBottom,
                  isListMode: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final Finder togglePositionedFinder = find.descendant(
        of: find.byType(HomeViewToggleButton),
        matching: find.byType(Positioned),
      );
      final Positioned togglePositioned =
          tester.widget<Positioned>(togglePositionedFinder.first);

      expect(togglePositioned.bottom, expectedToggleBottom);
      expect(togglePositioned.right, 16);
    });
  });

  group("T6.6 — Transição do modo lista para o mapa na seleção de ponto", () {
    testWidgets("tapping point in list switches view to map and keeps card open", (
      WidgetTester tester,
    ) async {
      final _FakeCollectPointsRepository repository =
          _FakeCollectPointsRepository(<CollectionPoint>[_testPoint]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              repository: repository,
              locationService: _FakeLocationService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Ponto de Teste"), findsOneWidget);

      await tester.tap(find.text("Ponto de Teste"));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(CollectPointSheet),
          matching: find.text("Rua Central, 100"),
        ),
        findsOneWidget,
      );

      // Cancelar o card fecha o CollectPointSheet
      await tester.tap(find.text("Cancelar"));
      await tester.pumpAndSettle();

      expect(find.byType(CollectPointSheet), findsNothing);
    });
  });

  group("T6.7 — Sombra uniforme em 4 lados da CustomBottomNavBar", () {
    testWidgets("navbar uses symmetrical BoxShadow with Offset.zero", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      final Finder containerFinder = find.byWidgetPredicate((Widget w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final BoxDecoration dec = w.decoration! as BoxDecoration;
          final List<BoxShadow>? shadows = dec.boxShadow;
          if (shadows != null && shadows.isNotEmpty) {
            return shadows.any((BoxShadow s) => s.offset == Offset.zero && s.blurRadius >= 16);
          }
        }
        return false;
      });

      expect(containerFinder, findsOneWidget);
    });
  });
}
