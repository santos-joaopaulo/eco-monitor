import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/disposal_guide_repository_local.dart";
import "package:eco_monitor/domain/entities/disposal_guide.dart";
import "package:eco_monitor/domain/entities/residue.dart";
import "package:eco_monitor/domain/repositories/disposal_guide_repository.dart";
import "package:eco_monitor/main.dart";
import "package:eco_monitor/screens/guide_navigator.dart";
import "package:eco_monitor/widgets/residue_card.dart";

// Helpers ------------------------------------------------------------------ //

/// Large surface so the whole guide list and the step-by-step are laid out.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Opens the "guia" tab from the shell bottom bar.
Future<void> openGuideTab(WidgetTester tester) async {
  await tester.tap(find.text("guia"));
  await tester.pumpAndSettle();
}

/// Opens the step-by-step of the residue whose card displays [cardTitle].
Future<void> openResidueGuide(WidgetTester tester, String cardTitle) async {
  final Finder residueCard = find.ancestor(
    of: find.text(cardTitle),
    matching: find.byType(ResidueCard),
  );

  await tester.tap(
    find.descendant(of: residueCard, matching: find.text("Iniciar")),
  );
  await tester.pumpAndSettle();
}

class _UnavailableGuideRepository implements DisposalGuideRepository {
  const _UnavailableGuideRepository();

  @override
  List<Residue> listResidues() => const [
    Residue(
      type: ResidueType.battery,
      title: "Pilhas e baterias",
      description: "Descrição de teste.",
      minutes: 2,
      totalSteps: 4,
    ),
  ];

  @override
  DisposalGuide? stepsGuideFor(ResidueType type) => null;
}

// Tests -------------------------------------------------------------------- //

void main() {
  testWidgets("guide list shows all four residue categories", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);

    expect(find.text("Como descartar certo?"), findsOneWidget);
    expect(find.text("Remédios vencidos"), findsOneWidget);
    expect(find.text("Pilhas e baterias"), findsOneWidget);
    expect(find.text("Seringas e agulhas"), findsOneWidget);
    expect(find.text("Lixo eletrônico"), findsOneWidget);
  });

  testWidgets("guide list opens the medicine step-by-step", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);
    await openResidueGuide(tester, "Remédios vencidos");

    expect(find.text("REMÉDIOS"), findsOneWidget);
    expect(
      find.text("Não jogue no lixo comum, pia ou vaso sanitário."),
      findsOneWidget,
    );
    expect(find.text("Separe os medicamentos"), findsOneWidget);
    expect(find.text("Mantenha na embalagem"), findsOneWidget);
    expect(find.text("Caixa e bula no reciclável"), findsOneWidget);
    expect(find.text("Leve a uma farmácia"), findsOneWidget);
  });

  testWidgets("guide list opens the battery step-by-step", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);
    await openResidueGuide(tester, "Pilhas e baterias");

    expect(find.text("PILHAS E BATERIAS"), findsOneWidget);
    expect(
      find.text(
        "Não perfure, amasse, queime ou jogue no lixo comum: há risco de vazamento tóxico.",
      ),
      findsOneWidget,
    );
    expect(find.text("Separe do lixo comum"), findsOneWidget);
    expect(find.text("Isole os polos"), findsOneWidget);
    expect(find.text("Embale itens danificados"), findsOneWidget);
    expect(find.text("Leve a um ponto de coleta"), findsOneWidget);
  });

  testWidgets("guide list opens the sharps step-by-step", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);
    await openResidueGuide(tester, "Seringas e agulhas");

    expect(find.text("SERINGAS E AGULHAS"), findsOneWidget);
    expect(
      find.text(
        "Risco biológico (ANVISA Grupo E): nunca reencape agulhas nem misture com remédios.",
      ),
      findsOneWidget,
    );
    expect(find.text("Não reencape nem quebre"), findsOneWidget);
    expect(find.text("Separe de outros resíduos"), findsOneWidget);
    expect(find.text("Use um recipiente rígido"), findsOneWidget);
    expect(find.text("Feche e identifique"), findsOneWidget);
    expect(find.text("Entregue em uma UBS"), findsOneWidget);
  });

  testWidgets("guide list opens the electronics step-by-step", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);
    await openResidueGuide(tester, "Lixo eletrônico");

    expect(find.text("LIXO ELETRÔNICO"), findsOneWidget);
    expect(
      find.text(
        "Não desmonte aparelhos nem jogue no lixo comum: eles contêm substâncias tóxicas.",
      ),
      findsOneWidget,
    );
    expect(find.text("Apague seus dados"), findsOneWidget);
    expect(find.text("Retire pilhas e baterias"), findsOneWidget);
    expect(find.text("Reúna cabos e acessórios"), findsOneWidget);
    expect(find.text("Leve a um ecoponto"), findsOneWidget);
  });

  testWidgets("back arrow returns to the guide list", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);
    await openResidueGuide(tester, "Pilhas e baterias");

    await tester.tap(find.byTooltip("Voltar"));
    await tester.pumpAndSettle();

    expect(find.text("Como descartar certo?"), findsOneWidget);
    expect(find.text("Isole os polos"), findsNothing);
  });

  testWidgets("show collection points closes the route and opens the map", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);
    await openResidueGuide(tester, "Lixo eletrônico");

    await tester.tap(find.text("Ver pontos no mapa"));
    await tester.pumpAndSettle();

    // Home tab is visible (no Mapbox token in tests, so the placeholder map
    // message is shown).
    expect(find.text("Configure o token do Mapbox"), findsOneWidget);

    // The internal route was popped: going back to the guide shows the list.
    await openGuideTab(tester);
    expect(find.text("Como descartar certo?"), findsOneWidget);
    expect(find.text("Apague seus dados"), findsNothing);
  });

  testWidgets(
    "show collection points forwards each residue type to the callback",
    (WidgetTester tester) async {
      useTallSurface(tester);
      final List<ResidueType> selectedTypes = <ResidueType>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuideNavigator(
              repository: const DisposalGuideRepositoryLocal(),
              active: true,
              onShowCollectionPoints: selectedTypes.add,
            ),
          ),
        ),
      );

      for (final (String title, ResidueType expectedType) in const [
        ("Remédios vencidos", ResidueType.medicine),
        ("Pilhas e baterias", ResidueType.battery),
        ("Seringas e agulhas", ResidueType.sharps),
        ("Lixo eletrônico", ResidueType.electronics),
      ]) {
        await openResidueGuide(tester, title);
        await tester.tap(find.text("Ver pontos no mapa"));
        await tester.pumpAndSettle();

        expect(selectedTypes.last, expectedType);
        expect(find.text("Como descartar certo?"), findsOneWidget);
      }

      expect(selectedTypes, const [
        ResidueType.medicine,
        ResidueType.battery,
        ResidueType.sharps,
        ResidueType.electronics,
      ]);
    },
  );

  testWidgets("shows snackbar when a residue guide is unavailable", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuideNavigator(
            repository: const _UnavailableGuideRepository(),
            active: true,
            onShowCollectionPoints: (_) {},
          ),
        ),
      ),
    );

    await openResidueGuide(tester, "Pilhas e baterias");

    expect(
      find.text("O guia de pilhas e baterias está indisponível no momento."),
      findsOneWidget,
    );
    expect(find.text("Como descartar certo?"), findsOneWidget);
  });
}
