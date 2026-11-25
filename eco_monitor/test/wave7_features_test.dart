import "dart:convert";

import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/disposal_guide_repository_local.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/waste_search_analytics_repository.dart";
import "package:eco_monitor/domain/entities/collection_point.dart";
import "package:eco_monitor/domain/entities/disposal_guide.dart";
import "package:eco_monitor/domain/entities/residue.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/domain/usecases/get_nearest_point_use_case.dart";
import "package:eco_monitor/screens/disposal_guide_screen.dart";
import "package:eco_monitor/theme/app_colors.dart";
import "package:eco_monitor/widgets/home_map_top_bar.dart";
import "package:eco_monitor/widgets/waste_style.dart";

// Tests -------------------------------------------------------------------- //

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("T13.1 — Resíduo Vidro e Código Universal de Cores", () {
    test("WasteType.glass possui rótulo, cor verde e ícone regulamentar", () {
      expect(WasteType.glass.label, "Vidro");
      expect(WasteType.glass.filterLabel, "Vidro");
      expect(WasteType.glass.appBarTitle, "VIDRO");
      expect(WasteType.glass.color, AppColors.glass);
      expect(WasteType.glass.color, AppColors.battery);
      expect(WasteType.glass.icon, Icons.wine_bar_rounded);
    });

    test("WasteType.medicines permanece estritamente com a cor laranja", () {
      expect(WasteType.medicines.color, AppColors.medicine);
      expect(WasteType.medicines.color, const Color(0xFFE65100));
    });

    test(
      "DisposalGuideRepositoryLocal possui guia educativo completo para Vidro",
      () {
        const DisposalGuideRepositoryLocal repo =
            DisposalGuideRepositoryLocal();
        final List<Residue> residues = repo.listResidues();

        final Residue? glassResidue = residues
            .where((Residue r) => r.type == WasteType.glass)
            .firstOrNull;
        expect(glassResidue, isNotNull);
        expect(glassResidue!.title, contains("Vidro"));
        expect(glassResidue.totalSteps, 4);

        final DisposalGuide? guide = repo.stepsGuideFor(WasteType.glass);
        expect(guide, isNotNull);
        expect(guide!.steps.length, 4);
        expect(guide.warning, contains("frasco quebrado"));
        expect(guide.steps[0].title, contains("Esvazie e higienize"));
        expect(guide.steps[1].title, contains("tampas"));
        expect(guide.steps[2].title, contains("quebra"));
        expect(guide.steps[3].title, contains("ecoponto"));
      },
    );

    test(
      "collect_points.json contém pontos aptos a receber vidro em Aracaju",
      () async {
        final String jsonStr = await rootBundle.loadString(
          "assets/data/collect_points.json",
        );
        final Map<String, dynamic> data =
            jsonDecode(jsonStr) as Map<String, dynamic>;
        final List<dynamic> points = data["points"] as List<dynamic>;

        final Iterable<dynamic> glassPointsInAracaju = points.where((
          dynamic p,
        ) {
          final List<dynamic> wastes =
              (p as Map<String, dynamic>)["acceptedWasteTypes"]
                  as List<dynamic>;
          final String address = p["address"] as String;
          return wastes.contains("glass") && address.contains("Aracaju");
        });

        expect(glassPointsInAracaju, isNotEmpty);
        expect(glassPointsInAracaju.length, greaterThanOrEqualTo(2));
      },
    );
  });

  group("T8.1 — Ação Rápida Ponto Mais Próximo", () {
    test("calcula ecoponto ativo mais próximo via GetNearestPointUseCase", () {
      const GetNearestPointUseCase useCase = GetNearestPointUseCase();
      final List<CollectionPoint> points = <CollectionPoint>[
        CollectionPoint(
          id: "pt-1",
          name: "Ponto Longe",
          type: PointType.ecoPoint,
          latitude: -10.9500,
          longitude: -37.0700,
          address: "Rua A",
          acceptedWasteTypes: const <WasteType>{WasteType.medicines},
          hours: "8h às 18h",
          status: PointStatus.active,
        ),
        CollectionPoint(
          id: "pt-2",
          name: "Ponto Perto",
          type: PointType.ecoPoint,
          latitude: -10.9100,
          longitude: -37.0700,
          address: "Rua B",
          acceptedWasteTypes: const <WasteType>{WasteType.medicines},
          hours: "8h às 18h",
          status: PointStatus.active,
        ),
        CollectionPoint(
          id: "pt-inativo",
          name: "Ponto Inativo Mais Perto",
          type: PointType.ecoPoint,
          latitude: -10.9090,
          longitude: -37.0700,
          address: "Rua C",
          acceptedWasteTypes: const <WasteType>{WasteType.medicines},
          hours: "8h às 18h",
          status: PointStatus.inactive,
        ),
      ];

      final NearestPointResult? result = useCase.execute(
        userLatitude: -10.9080,
        userLongitude: -37.0700,
        points: points,
      );

      expect(result, isNotNull);
      expect(result!.point.id, "pt-2");
      expect(result.distanceMeters, lessThan(500));
    });

    testWidgets(
      "banner de ponto mais próximo exibe distância proativa e aciona callback",
      (WidgetTester tester) async {
        useTallSurface(tester);
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: NearestPointQuickBanner(
                distanceMeters: 450,
                onPressed: () {
                  tapped = true;
                },
              ),
            ),
          ),
        );

        expect(find.text("Mais próximo a 450 m"), findsOneWidget);
        expect(find.text("Traçar rota direta em 1 toque"), findsOneWidget);

        await tester.tap(find.text("Mais próximo a 450 m"));
        expect(tapped, isTrue);
      },
    );

    testWidgets("banner sem distância exibe Ponto mais próximo como padrão", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearestPointQuickBanner(
              distanceMeters: null,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text("Ponto mais próximo"), findsOneWidget);
    });
  });

  group("T8.2 e T8.3 — Busca Textual e Estatísticas no Guia de Descarte", () {
    testWidgets(
      "exibe estado vazio realista quando não há pesquisas registradas",
      (WidgetTester tester) async {
        useTallSurface(tester);
        final store = InMemoryLocalStore();
        final analytics = WasteSearchAnalyticsRepository(localStore: store);
        final repo = const DisposalGuideRepositoryLocal();

        await tester.pumpWidget(
          MaterialApp(
            home: DisposalGuideScreen(
              repository: repo,
              onStartGuide: (_) {},
              analyticsRepository: analytics,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Resíduos mais pesquisados"), findsOneWidget);
        expect(find.text("Todos os estados (Brasil)"), findsOneWidget);
        expect(
          find.text(
            "Nenhuma pesquisa registrada ainda. Consulte um resíduo para iniciar o ranking.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets("exibe estatísticas reais de mais pesquisados e filtra por UF", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);
      final store = InMemoryLocalStore();
      final analytics = WasteSearchAnalyticsRepository(localStore: store);
      await analytics.recordSearch(WasteType.medicines, stateCode: "SE");
      await analytics.recordSearch(WasteType.medicines, stateCode: "SE");
      await analytics.recordSearch(WasteType.batteries, stateCode: "SP");
      await analytics.recordSearch(WasteType.glass, stateCode: "SP");

      final repo = const DisposalGuideRepositoryLocal();

      await tester.pumpWidget(
        MaterialApp(
          home: DisposalGuideScreen(
            repository: repo,
            onStartGuide: (_) {},
            analyticsRepository: analytics,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Visão padrão nacional: 2 remédios (50%), 1 pilha (25%), 1 vidro (25%)
      expect(find.text("Resíduos mais pesquisados"), findsOneWidget);
      expect(find.text("Ranking nacional de todos os dispositivos."), findsOneWidget);
      expect(find.text("Remédios 50%"), findsOneWidget);
      expect(find.text("Pilhas 25%"), findsOneWidget);
      expect(find.text("Vidro 25%"), findsOneWidget);

      // Filtra pelo estado de Sergipe (SE)
      await tester.tap(find.text("Todos os estados (Brasil)"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Sergipe (SE)").last);
      await tester.pumpAndSettle();

      expect(
        find.text("Ranking filtrado para Sergipe (SE)."),
        findsOneWidget,
      );
      expect(find.text("Remédios 100%"), findsOneWidget);
    });

    testWidgets("toque no chip de estatística abre o guia da categoria", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);
      final store = InMemoryLocalStore();
      final analytics = WasteSearchAnalyticsRepository(localStore: store);
      await analytics.recordSearch(WasteType.medicines);
      final repo = const DisposalGuideRepositoryLocal();
      Residue? openedResidue;

      await tester.pumpWidget(
        MaterialApp(
          home: DisposalGuideScreen(
            repository: repo,
            onStartGuide: (Residue r) {
              openedResidue = r;
            },
            analyticsRepository: analytics,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Remédios 100%"));
      await tester.pumpAndSettle();

      expect(openedResidue, isNotNull);
      expect(openedResidue!.type, WasteType.medicines);
    });

    testWidgets(
      "busca textual instantânea filtra categoria por termo popular",
      (WidgetTester tester) async {
        useTallSurface(tester);
        final store = InMemoryLocalStore();
        final analytics = WasteSearchAnalyticsRepository(localStore: store);
        final repo = const DisposalGuideRepositoryLocal();
        Residue? openedResidue;

        await tester.pumpWidget(
          MaterialApp(
            home: DisposalGuideScreen(
              repository: repo,
              onStartGuide: (Residue r) {
                openedResidue = r;
              },
              analyticsRepository: analytics,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Digita "paracetamol" no campo de busca do guia
        await tester.enterText(find.byType(TextField), "paracetamol");
        await tester.pumpAndSettle();

        expect(find.text('Termo: "paracetamol"'), findsOneWidget);
        expect(find.text("Remédios vencidos"), findsOneWidget);

        await tester.tap(find.text("Iniciar guia"));
        await tester.pumpAndSettle();

        expect(openedResidue, isNotNull);
        expect(openedResidue!.type, WasteType.medicines);
      },
    );

    testWidgets("busca sem resultados exibe aviso amigável", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);
      final repo = const DisposalGuideRepositoryLocal();
      final analytics = WasteSearchAnalyticsRepository(
        localStore: InMemoryLocalStore(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DisposalGuideScreen(
            repository: repo,
            onStartGuide: (_) {},
            analyticsRepository: analytics,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "termo_inexistente");
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhum resíduo encontrado para "termo_inexistente"'),
        findsOneWidget,
      );
    });
  });

  group("T8.2 — Busca Textual na Barra Superior do Mapa", () {
    testWidgets(
      "busca na Home sugere categorias e invoca callback ao selecionar",
      (WidgetTester tester) async {
        useTallSurface(tester);
        WasteType? selectedType;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeMapTopBar(
                selectedWasteTypes: const <WasteType>{},
                onFilterChanged: (_) {},
                showMapboxTokenWarning: false,
                isLoadingPoints: false,
                isEmptyResult: false,
                emptyMessage: "",
                locationNotice: null,
                isListMode: false,
                isSearchActive: true,
                onResidueSearched: (WasteType type) {
                  selectedType = type;
                },
              ),
            ),
          ),
        );

        // Digita "pilha" na barra de busca do mapa
        await tester.enterText(find.byType(TextField), "pilha");
        await tester.pumpAndSettle();

        expect(find.byType(ActionChip), findsWidgets);

        await tester.tap(find.byType(ActionChip).first);
        await tester.pumpAndSettle();

        expect(selectedType, WasteType.batteries);
      },
    );
  });
}
