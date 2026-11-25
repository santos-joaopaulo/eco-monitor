import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/presentation/state/location_notifier.dart";
import "package:eco_monitor/presentation/state/offline_packages_notifier.dart";
import "package:eco_monitor/screens/offline_maps_screen.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/offline_package_manager.dart";
import "package:eco_monitor/widgets/eco_app_bar.dart";
import "package:eco_monitor/widgets/offline_banner.dart";
import "package:eco_monitor/widgets/offline_package_card.dart";
import "package:eco_monitor/widgets/offline_storage_summary_card.dart";


// Tests ------------------------------------------------------------------- //


void main() {
  group("OfflineMapsScreen & Componentes de UI (T14.3 & T14.4)", () {
    late InMemoryLocalStore store;
    late OfflinePackageManager manager;
    late OfflinePackagesNotifier notifier;

    setUp(() async {
      store = InMemoryLocalStore();
      manager = OfflinePackageManager(
        localStore: store,
        stepDuration: Duration.zero,
      );
      notifier = OfflinePackagesNotifier(packageManager: manager);
      await notifier.loadPackages();
    });

    tearDown(() {
      notifier.dispose();
    });

    Widget buildTestScreen(WidgetTester tester, {UserLocation? userLocation}) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      if (userLocation != null) {
        notifier.updateUserLocation(userLocation);
      }

      return MaterialApp(
        home: MultiProvider(
          providers: <ChangeNotifierProvider<dynamic>>[
            ChangeNotifierProvider<OfflinePackagesNotifier>.value(
              value: notifier,
            ),
            ChangeNotifierProvider<LocationNotifier>(
              create: (_) => LocationNotifier(
                locationService: const LocationService(),
              ),
            ),
          ],
          child: const OfflineMapsScreen(),
        ),
      );
    }

    testWidgets("renderiza AppBar, card de armazenamento, campo de busca e chips de região", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      expect(find.text("Mapas Offline"), findsOneWidget);
      expect(find.byType(OfflineStorageSummaryCard), findsOneWidget);
      expect(find.textContaining("Espaço offline utilizado:"), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text("Todos"), findsOneWidget);
      expect(find.text("Nordeste"), findsOneWidget);
      expect(find.text("Sudeste"), findsOneWidget);
      expect(find.text("Estados Brasileiros"), findsOneWidget);
    });

    testWidgets("filtra estados pelo campo de pesquisa em tempo real", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OfflinePackageCard, "Acre"), findsOneWidget);
      expect(find.widgetWithText(OfflinePackageCard, "Bahia"), findsOneWidget);

      await tester.enterText(find.byType(TextField), "Bahia");
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OfflinePackageCard, "Bahia"), findsOneWidget);
      expect(find.widgetWithText(OfflinePackageCard, "Acre"), findsNothing);
    });

    testWidgets("filtra estados ao selecionar chip de região", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Sudeste"));
      await tester.pumpAndSettle();

      expect(find.text("São Paulo"), findsOneWidget);
      expect(find.text("Rio de Janeiro"), findsOneWidget);
      expect(find.text("Minas Gerais"), findsOneWidget);
      expect(find.text("Espírito Santo"), findsOneWidget);
      expect(find.text("Acre"), findsNothing);
    });

    testWidgets("exibe seção 'Sugerido para você' quando localização do usuário está disponível", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestScreen(
          tester,
          userLocation: const UserLocation(latitude: -23.55, longitude: -46.63),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Sugerido para você"), findsOneWidget);
      expect(find.text("Sugerido para a sua localização"), findsOneWidget);
    });

    testWidgets("inicia download e reflete status baixado após conclusão", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      // Busca por Alagoas
      await tester.enterText(find.byType(TextField), "Alagoas");
      await tester.pumpAndSettle();

      expect(find.text("Baixar"), findsOneWidget);
      await tester.tap(find.text("Baixar"));
      await tester.pumpAndSettle();

      expect(find.text("Instalado"), findsOneWidget);
    });

    testWidgets("exibe diálogo de confirmação e exclui pacote instalado", (
      WidgetTester tester,
    ) async {
      // Pré-instala Bahia
      await notifier.downloadPackage("br-ba").drain<void>();

      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), "Bahia");
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text("Excluir mapa de Bahia?"), findsOneWidget);

      await tester.tap(find.text("Excluir"));
      await tester.pumpAndSettle();

      expect(find.text("Baixar"), findsOneWidget);
    });

    testWidgets("limpa pacotes extras via botão do card de armazenamento", (
      WidgetTester tester,
    ) async {
      await notifier.downloadPackage("br-ba").drain<void>();

      await tester.pumpWidget(buildTestScreen(tester));
      await tester.pumpAndSettle();

      expect(find.text("Limpar extras"), findsOneWidget);
      await tester.tap(find.text("Limpar extras"));
      await tester.pumpAndSettle();

      expect(find.text("Limpar mapas extras?"), findsOneWidget);
      await tester.tap(find.text("Limpar"));
      await tester.pumpAndSettle();

      expect(find.text("Limpar extras"), findsNothing);
    });

    testWidgets("EcoAppBar inclui atalho para mapas offline e navega ao tocar quando showOfflineMapsAction é true", (
      WidgetTester tester,
    ) async {
      bool opened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: EcoAppBar(
              title: "TESTE",
              showOfflineMapsAction: true,
              onOfflineMapsPressed: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder offlineBtn = find.byIcon(Icons.download_for_offline_rounded);
      expect(offlineBtn, findsOneWidget);

      await tester.tap(offlineBtn);
      expect(opened, isTrue);
    });

    testWidgets("EcoAppBar não exibe botão de mapas offline quando showOfflineMapsAction é false (padrão)", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: EcoAppBar(
              title: "TESTE",
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder offlineBtn = find.byIcon(Icons.download_for_offline_rounded);
      expect(offlineBtn, findsNothing);
    });

    testWidgets("OfflineBanner não exibe botão de mapas offline quando desconectado", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              isOffline: true,
              isStale: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Mapas offline"), findsNothing);
      expect(find.byIcon(Icons.download_for_offline_rounded), findsNothing);
    });

    testWidgets("renderiza com sucesso em modo autônomo sem Provider ancestral", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineMapsScreen(packageManager: manager),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Mapas Offline"), findsOneWidget);
      expect(find.text("Estados Brasileiros"), findsOneWidget);
      expect(find.widgetWithText(OfflinePackageCard, "Acre"), findsOneWidget);
    });

    testWidgets("EcoAppBar com showOfflineMapsAction: true e onPressed padrão abre OfflineMapsScreen e exibe conteúdo", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: <ChangeNotifierProvider<dynamic>>[
              ChangeNotifierProvider<OfflinePackagesNotifier>.value(
                value: notifier,
              ),
            ],
            child: const Scaffold(
              appBar: EcoAppBar(
                title: "Início",
                showOfflineMapsAction: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder offlineBtn = find.byIcon(Icons.download_for_offline_rounded);
      expect(offlineBtn, findsOneWidget);

      await tester.tap(offlineBtn);
      await tester.pumpAndSettle();

      expect(find.text("Mapas Offline"), findsOneWidget);
      expect(find.text("Estados Brasileiros"), findsOneWidget);
      expect(find.widgetWithText(OfflinePackageCard, "Acre"), findsOneWidget);
    });

    testWidgets("OfflineBanner quando desconectado não abre OfflineMapsScreen", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: <ChangeNotifierProvider<dynamic>>[
              ChangeNotifierProvider<OfflinePackagesNotifier>.value(
                value: notifier,
              ),
            ],
            child: const Scaffold(
              body: OfflineBanner(
                isOffline: true,
                isStale: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Mapas offline"), findsNothing);
      expect(find.text("Estados Brasileiros"), findsNothing);
    });
  });
}
