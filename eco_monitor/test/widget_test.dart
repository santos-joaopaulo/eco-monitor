import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/main.dart";
import "package:eco_monitor/screens/home_screen.dart";
import "package:eco_monitor/screens/offline_maps_screen.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  testWidgets("renders the shell with app bar and four navigation tabs", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text("ECOMONITOR"), findsOneWidget);
    expect(find.text("home"), findsOneWidget);
    expect(find.text("guia"), findsOneWidget);
    expect(find.text("eventos"), findsOneWidget);
    expect(find.text("sugerir"), findsOneWidget);
  });

  testWidgets(
    "exibe botão de mapas offline na navbar apenas na aba home",
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pump();

      final Finder offlineButton = find.byIcon(Icons.download_for_offline_rounded);

      // Aba inicial é Home: botão de mapas offline deve estar presente na navbar.
      expect(offlineButton, findsOneWidget);

      // Navega para aba Guia: botão de mapas offline não deve ser exibido.
      await tester.tap(find.text("guia"));
      await tester.pump();
      expect(offlineButton, findsNothing);

      // Navega para aba Eventos: botão de mapas offline não deve ser exibido.
      await tester.tap(find.text("eventos"));
      await tester.pump();
      expect(offlineButton, findsNothing);

      // Navega para aba Sugerir: botão de mapas offline não deve ser exibido.
      await tester.tap(find.text("sugerir"));
      await tester.pump();
      expect(offlineButton, findsNothing);

      // Retorna para aba Home: botão volta a ser exibido.
      await tester.tap(find.text("home"));
      await tester.pump();
      expect(offlineButton, findsOneWidget);

      // Tocar no botão abre a tela de mapas offline.
      await tester.tap(offlineButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(OfflineMapsScreen), findsOneWidget);
    },
  );

  testWidgets(
    "oculta botão de mapas offline quando a lista de ecopontos está aberta na home",
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pump();

      final Finder offlineButton = find.byIcon(Icons.download_for_offline_rounded);
      expect(offlineButton, findsOneWidget);

      final HomeScreen home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      home.onListViewChanged?.call(true);
      await tester.pump();
      expect(offlineButton, findsNothing);

      home.onListViewChanged?.call(false);
      await tester.pump();
      expect(offlineButton, findsOneWidget);
    },
  );

  testWidgets(
    "exibe botão de pesquisa na navbar apenas quando a lista de ecopontos está aberta na home",
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pump();

      final Finder appBarSearchButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.search_rounded),
      );

      // Com o mapa ativo (lista fechada), o botão de pesquisa não aparece na navbar.
      expect(appBarSearchButton, findsNothing);

      final HomeScreen home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      home.onListViewChanged?.call(true);
      await tester.pump();

      // Com a lista aberta, o botão de pesquisa aparece na navbar.
      expect(appBarSearchButton, findsOneWidget);

      // Tocar no botão alterna o estado de busca.
      await tester.tap(appBarSearchButton);
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.close_rounded),
        ),
        findsOneWidget,
      );

      home.onListViewChanged?.call(false);
      await tester.pump();
      expect(appBarSearchButton, findsNothing);
    },
  );
}
