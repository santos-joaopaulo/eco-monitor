import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/disposal_guide_repository_local.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/screens/disposal_step_by_step_screen.dart";
import "package:eco_monitor/screens/home_screen.dart";
import "package:eco_monitor/screens/suggest_screen.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/mapbox_token_provider.dart";
import "package:eco_monitor/services/route_service.dart";
import "package:eco_monitor/theme/app_colors.dart";
import "package:eco_monitor/widgets/collect_point_sheet.dart";
import "package:eco_monitor/widgets/collect_points_list_view.dart";
import "package:eco_monitor/widgets/custom_bottom_nav_bar.dart";
import "package:eco_monitor/widgets/eco_app_bar.dart";
import "package:eco_monitor/widgets/filter_bar.dart";
import "package:eco_monitor/widgets/home_map_controls.dart";
import "package:eco_monitor/widgets/opening_hours_row.dart";
import "package:eco_monitor/widgets/route_summary_card.dart";
import "package:eco_monitor/widgets/waste_type_option_card.dart";


// Auxiliares -------------------------------------------------------------- //


double _linearize(double component) {
  return component <= 0.04045
      ? component / 12.92
      : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color color) {
  final double r = _linearize(color.r);
  final double g = _linearize(color.g);
  final double b = _linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final double l1 = _relativeLuminance(a);
  final double l2 = _relativeLuminance(b);
  final double lighter = math.max(l1, l2);
  final double darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

CollectionPoint _samplePoint() {
  return CollectionPoint(
    id: "p-test",
    name: "Farmácia Pague Menos",
    type: PointType.pharmacy,
    latitude: -10.95,
    longitude: -37.06,
    address: "Rua Laranjeiras, 450 - Centro",
    acceptedWasteTypes: const <WasteType>{
      WasteType.medicines,
      WasteType.sharps,
    },
    hours: "Seg a Sex: 08:00 às 18:00",
    status: PointStatus.active,
  );
}


// Testes ------------------------------------------------------------------ //


void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    MapboxTokenProvider.token = "";
  });

  tearDown(() {
    MapboxTokenProvider.token = "";
  });

  group("WCAG 2.1 Color contrast compliance (RNF04)", () {
    test("primaryAccessible meets WCAG AA (>= 4.5:1) on white surface", () {
      final double ratio = _contrastRatio(
        AppColors.primaryAccessible,
        Colors.white,
      );

      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: "primaryAccessible deve ter contraste >= 4.5:1 para texto normal",
      );
    });

    test("textPrimary meets WCAG AAA (>= 7.0:1) on white and background", () {
      final double ratioWhite = _contrastRatio(
        AppColors.textPrimary,
        AppColors.surface,
      );
      final double ratioBg = _contrastRatio(
        AppColors.textPrimary,
        AppColors.background,
      );
      final double ratioTint = _contrastRatio(
        AppColors.textPrimary,
        AppColors.primaryTint,
      );

      expect(ratioWhite, greaterThanOrEqualTo(7.0));
      expect(ratioBg, greaterThanOrEqualTo(7.0));
      expect(ratioTint, greaterThanOrEqualTo(7.0));
    });

    test("textSecondary meets WCAG AA (>= 3.0:1) for large text and UI", () {
      final double ratio = _contrastRatio(
        AppColors.textSecondary,
        AppColors.surface,
      );

      expect(ratio, greaterThanOrEqualTo(3.0));
    });

    test("warningText meets WCAG AA (>= 4.5:1) on warningBackground", () {
      final double ratio = _contrastRatio(
        AppColors.warningText,
        AppColors.warningBackground,
      );

      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test("waste category colors meet UI component contrast (>= 3.0:1)", () {
      const List<Color> wasteColors = <Color>[
        AppColors.medicine,
        AppColors.battery,
        AppColors.sharps,
        AppColors.electronics,
        AppColors.userLocation,
      ];

      for (final Color color in wasteColors) {
        final double ratio = _contrastRatio(color, Colors.white);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: "Cor $color deve ter contraste >= 3.0:1 sobre branco",
        );
      }
    });
  });

  group("Accessibility labels on non-text buttons (RNF04, RNF18)", () {
    testWidgets("HomeLocateButton has explicit tooltip and semantics", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HomeLocateButton(bottom: 0, onPressed: () {}),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byTooltip("Centralizar na minha localização"),
        findsOneWidget,
      );
    });

    testWidgets("HomeViewToggleButton has explicit tooltip and semantics", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HomeViewToggleButton(
                  bottom: 0,
                  isListMode: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byTooltip("Visualização em mapa"), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                HomeViewToggleButton(
                  bottom: 0,
                  isListMode: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byTooltip("Visualização em lista"), findsOneWidget);
    });

    testWidgets("EcoAppBar back button has explicit tooltip and semantics", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: EcoAppBar(title: "Passo a passo", onBack: () {}),
          ),
        ),
      );

      expect(find.byTooltip("Voltar"), findsOneWidget);
    });

    testWidgets("RouteSummaryCard close button has explicit tooltip", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteSummaryCard(
              point: _samplePoint(),
              summary: const RouteSummary(
                distanceMeters: 1200,
                estimatedMinutes: 15,
              ),
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.byTooltip("Fechar rota"), findsOneWidget);
    });

    testWidgets("SuggestScreen location and remove buttons have explicit tooltips", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const LocationService service = LocationService();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SuggestScreen(locationService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byTooltip("Preencher com localização atual (GPS)"),
        findsOneWidget,
      );
      expect(
        find.byTooltip("Replicar horário para todos os dias"),
        findsOneWidget,
      );
    });

    testWidgets("FilterBar pills have semantics with buttons and labels", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              selectedTypes: const <WasteType>{WasteType.medicines},
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel("Remédios"),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Seringas"),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Pilhas"),
        findsOneWidget,
      );
    });

    testWidgets("CustomBottomNavBar items have semantics with button and label", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel("home"), findsOneWidget);
      expect(find.bySemanticsLabel("guia"), findsOneWidget);
      expect(find.bySemanticsLabel("eventos"), findsOneWidget);
      expect(find.bySemanticsLabel("sugerir"), findsOneWidget);
    });

    testWidgets("WasteTypeOptionCard has semantics button and hint", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WasteTypeOptionCard(
              type: WasteType.medicines,
              isSelected: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel("Remédios"), findsOneWidget);
    });

    testWidgets("OpeningHoursRow has semantics button for day toggle and time pills", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OpeningHoursRow(
              dayLabel: "Seg",
              isOpen: true,
              opensAt: const TimeOfDay(hour: 8, minute: 0),
              closesAt: const TimeOfDay(hour: 18, minute: 0),
              onToggleOpen: () {},
              onOpeningTap: () {},
              onClosingTap: () {},
            ),
          ),
        ),
      );

      expect(
        find.bySemanticsLabel("Seg, aberto"),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Seg, horário de abertura, 08:00"),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel("Seg, horário de fechamento, 18:00"),
        findsOneWidget,
      );
    });
  });

  group("1.5x text scaling without RenderFlex overflow (RNF04, RNF18)", () {
    Widget with15xScaling(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 740),
              textScaler: TextScaler.linear(1.5),
            ),
            child: child,
          ),
        ),
      );
    }

    testWidgets("renders CustomBottomNavBar with 1.5x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with15xScaling(
          CustomBottomNavBar(currentIndex: 0, onTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders FilterBar with 1.5x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with15xScaling(
          FilterBar(
            selectedTypes: const <WasteType>{WasteType.medicines},
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders EcoAppBar with 1.5x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 740),
              textScaler: TextScaler.linear(1.5),
            ),
            child: EcoAppBar(
              title: "ECOMONITOR",
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders CollectPointSheet with 1.5x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with15xScaling(
          CollectPointSheet(
            point: _samplePoint(),
            distanceMeters: 450,
            activeFilter: const <WasteType>{},
            isDataStale: false,
            onCancel: () {},
            onStartRoute: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders RouteSummaryCard with 1.5x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with15xScaling(
          RouteSummaryCard(
            point: _samplePoint(),
            summary: const RouteSummary(
              distanceMeters: 1200,
              estimatedMinutes: 15,
            ),
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders CollectPointsListView with 1.5x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with15xScaling(
          CollectPointsListView(
            points: <CollectionPoint>[_samplePoint()],
            onPointSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders SuggestScreen with 1.5x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with15xScaling(
          const SuggestScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Rola o formulário até o fim para verificar todos os campos
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders HomeScreen list mode with 1.5x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with15xScaling(
          const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group("1.8x and 2.0x high text scaling for elderly accessibility (RNF04, RNF18)", () {
    Widget with18xScaling(Widget child, {Size size = const Size(360, 640)}) {
      return MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.8),
            ),
            child: child,
          ),
        ),
      );
    }

    testWidgets("renders SuggestScreen at 1.8x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(with18xScaling(const SuggestScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -900),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders RouteSummaryCard at 1.8x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with18xScaling(
          RouteSummaryCard(
            point: _samplePoint(),
            summary: const RouteSummary(
              distanceMeters: 1400,
              estimatedMinutes: 18,
            ),
            onClose: () {},
            onOpenExternal: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders CollectPointSheet at 1.8x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        with18xScaling(
          CollectPointSheet(
            point: _samplePoint(),
            distanceMeters: 1250,
            activeFilter: const {},
            isDataStale: false,
            onCancel: () {},
            onStartRoute: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets("renders DisposalStepByStepScreen at 1.8x scaling without overflow", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = DisposalGuideRepositoryLocal();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.8),
            ),
            child: DisposalStepByStepScreen(
              wasteType: WasteType.medicines,
              repository: repo,
              onShowCollectionPoints: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets("CustomBottomNavBar hides when keyboard opens", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(360, 640),
              viewInsets: EdgeInsets.only(bottom: 280),
            ),
            child: Scaffold(
              bottomNavigationBar: CustomBottomNavBar(
                currentIndex: 0,
                onTap: _noop,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text("home"), findsNothing);
    });
  });
}

void _noop(int _) {}
