import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/main.dart";
import "package:eco_monitor/widgets/residue_card.dart";

// Helpers ------------------------------------------------------------------ //

/// Large surface so the whole guide list and the step-by-step are laid out.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Opens the "guia" tab from the shell bottom bar.
Future<void> openGuideTab(WidgetTester tester) async {
  await tester.tap(find.text("guia"));
  await tester.pumpAndSettle();
}

/// Opens the "Remédios vencidos" step-by-step from the guide list.
Future<void> openMedicineGuide(WidgetTester tester) async {
  final Finder medicineCard = find.ancestor(
    of: find.text("Remédios vencidos"),
    matching: find.byType(ResidueCard),
  );

  await tester.tap(
    find.descendant(of: medicineCard, matching: find.text("Iniciar")),
  );
  await tester.pumpAndSettle();
}

// Tests -------------------------------------------------------------------- //

void main() {
  testWidgets("guide list opens the medicine step-by-step", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);

    expect(find.text("Como descartar certo?"), findsOneWidget);

    await openMedicineGuide(tester);

    expect(
      find.text("Não jogue no lixo comum, pia ou vaso sanitário."),
      findsOneWidget,
    );
    expect(find.text("Separe os medicamentos"), findsOneWidget);
    expect(find.text("Mantenha na embalagem"), findsOneWidget);
    expect(find.text("Caixa e bula no reciclável"), findsOneWidget);
    expect(find.text("Leve a uma farmácia"), findsOneWidget);
  });

  testWidgets("back arrow returns to the guide list", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);
    await openMedicineGuide(tester);

    await tester.tap(find.byTooltip("Voltar"));
    await tester.pumpAndSettle();

    expect(find.text("Como descartar certo?"), findsOneWidget);
    expect(
      find.text("Não jogue no lixo comum, pia ou vaso sanitário."),
      findsNothing,
    );
  });

  testWidgets("show collection points closes the route and opens the map", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MyApp());
    await openGuideTab(tester);
    await openMedicineGuide(tester);

    await tester.tap(find.text("Ver pontos no mapa"));
    await tester.pumpAndSettle();

    // Home tab is visible (no Mapbox token in tests, so the placeholder map
    // message is shown).
    expect(find.text("Configure o token do Mapbox"), findsOneWidget);

    // The internal route was popped: going back to the guide shows the list.
    await openGuideTab(tester);
    expect(find.text("Como descartar certo?"), findsOneWidget);
    expect(
      find.text("Não jogue no lixo comum, pia ou vaso sanitário."),
      findsNothing,
    );
  });
}
