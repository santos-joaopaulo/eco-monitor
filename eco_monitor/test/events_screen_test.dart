import "package:connectivity_plus/connectivity_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/app_data_sync.dart";
import "package:eco_monitor/data/campaigns_repository.dart";
import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/connectivity_service.dart";
import "package:eco_monitor/data/disposal_guide_repository_synced.dart";
import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/main.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/screens/events_screen.dart";
import "package:eco_monitor/widgets/campaign_card.dart";


// Helpers ------------------------------------------------------------------ //


void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AppDataSync _createTestDataSync() {
  final DateTime fixedClock = DateTime.utc(2026, 11, 17, 12);

  return AppDataSync(
    collectPointsRepository: CollectPointsRepository(clock: () => fixedClock),
    campaignsRepository: CampaignsRepository(clock: () => fixedClock),
    suggestionsRepository: PointSuggestionsRepository(),
    guideRepository: DisposalGuideRepositorySynced(clock: () => fixedClock),
    connectivityService: ConnectivityService(
      checkConnectivity: () async => const [ConnectivityResult.wifi],
      connectivityStream: const Stream<List<ConnectivityResult>>.empty(),
    ),
  );
}

class _FakeCampaignsRepository extends CampaignsRepository {
  _FakeCampaignsRepository(this._campaigns, {this.shouldThrow = false});

  final List<Campaign> _campaigns;
  bool shouldThrow;

  @override
  Future<List<Campaign>> loadOffline() async {
    if (shouldThrow) {
      throw StateError("Failed to load campaigns");
    }
    return _campaigns;
  }

  @override
  Future<List<Campaign>> refresh() => loadOffline();
}

Campaign _sampleCampaign({
  required String id,
  required String title,
  required CampaignStatus status,
  Set<WasteType> wasteTypes = const {WasteType.batteries},
  String locationName = "Parque da Sementeira",
  String address = "Av. Jornalista Santos Santana, s/n — Jardins, Aracaju",
}) {
  return Campaign(
    id: id,
    title: title,
    description: "Descrição completa da campanha $title.",
    wasteTypes: wasteTypes,
    locationName: locationName,
    address: address,
    latitude: -10.9412,
    longitude: -37.0537,
    startDate: DateTime(2026, 11, 15, 8, 0),
    endDate: DateTime(2026, 11, 30, 17, 0),
    status: status,
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    "events tab renders AppBar, filter chips, and bundled campaigns",
    (WidgetTester tester) async {
      useTallSurface(tester);
      final AppDataSync dataSync = _createTestDataSync();
      addTearDown(dataSync.dispose);
      await tester.runAsync(dataSync.initialize);

      await tester.pumpWidget(MyApp(dataSync: dataSync));
      await tester.pumpAndSettle();

      await tester.tap(find.text("eventos"));
      await tester.pumpAndSettle();

      expect(find.text("CAMPANHAS ATIVAS"), findsOneWidget);
      expect(find.text("Todas"), findsOneWidget);
      expect(find.text("Ativas"), findsOneWidget);
      expect(find.text("Em breve"), findsWidgets);

      expect(find.text("Mutirão de Lixo Eletrônico na Orla"), findsOneWidget);
      expect(find.text("Ponto Extra de Pilhas e Baterias"), findsOneWidget);
      expect(
        find.text("Semana do Descarte Seguro de Medicamentos"),
        findsOneWidget,
      );
    },
  );

  testWidgets("filter chips filter active and upcoming campaigns", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final _FakeCampaignsRepository repository = _FakeCampaignsRepository([
      _sampleCampaign(
        id: "active-1",
        title: "Mutirão de Pilhas",
        status: CampaignStatus.active,
      ),
      _sampleCampaign(
        id: "upcoming-1",
        title: "Descarte Consciente de Remédios",
        status: CampaignStatus.upcoming,
        wasteTypes: const {WasteType.medicines},
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventsScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Mutirão de Pilhas"), findsOneWidget);
    expect(find.text("Descarte Consciente de Remédios"), findsOneWidget);

    await tester.tap(find.text("Ativas"));
    await tester.pumpAndSettle();
    expect(find.text("Mutirão de Pilhas"), findsOneWidget);
    expect(find.text("Descarte Consciente de Remédios"), findsNothing);

    await tester.tap(find.text("Em breve"));
    await tester.pumpAndSettle();
    expect(find.text("Mutirão de Pilhas"), findsNothing);
    expect(find.text("Descarte Consciente de Remédios"), findsOneWidget);

    await tester.tap(find.text("Todas"));
    await tester.pumpAndSettle();
    expect(find.text("Mutirão de Pilhas"), findsOneWidget);
    expect(find.text("Descarte Consciente de Remédios"), findsOneWidget);
  });

  testWidgets("empty filtered state allows resetting back to all campaigns", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final _FakeCampaignsRepository repository = _FakeCampaignsRepository([
      _sampleCampaign(
        id: "active-only",
        title: "Mutirão Ativo",
        status: CampaignStatus.active,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventsScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Em breve"));
    await tester.pumpAndSettle();

    expect(find.text("Nenhuma campanha programada"), findsOneWidget);
    expect(find.text("Ver todas"), findsOneWidget);

    await tester.tap(find.text("Ver todas"));
    await tester.pumpAndSettle();

    expect(find.text("Mutirão Ativo"), findsOneWidget);
  });

  testWidgets("error state shows retry action and recovers on retry", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    final _FakeCampaignsRepository repository = _FakeCampaignsRepository([
      _sampleCampaign(
        id: "recovered",
        title: "Campanha Recuperada",
        status: CampaignStatus.active,
      ),
    ], shouldThrow: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventsScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Não foi possível carregar as campanhas"), findsOneWidget);

    repository.shouldThrow = false;
    await tester.tap(find.text("Tentar novamente"));
    await tester.pumpAndSettle();

    expect(find.text("Campanha Recuperada"), findsOneWidget);
  });

  testWidgets("tapping a campaign card opens the detail bottom sheet", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);
    Campaign? selectedLocation;

    final _FakeCampaignsRepository repository = _FakeCampaignsRepository([
      _sampleCampaign(
        id: "orla",
        title: "Mutirão de Eletrônicos",
        status: CampaignStatus.active,
        wasteTypes: const {WasteType.electronics, WasteType.batteries},
        locationName: "Arcos da Orla de Atalaia",
        address: "Av. Santos Dumont, s/n — Atalaia, Aracaju",
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventsScreen(
            repository: repository,
            onShowCampaignLocation: (Campaign c) => selectedLocation = c,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Mutirão de Eletrônicos"));
    await tester.pumpAndSettle();

    expect(
      find.text("Descrição completa da campanha Mutirão de Eletrônicos."),
      findsOneWidget,
    );
    expect(find.text("MATERIAIS COLETADOS"), findsOneWidget);
    expect(find.text("Lixo eletrônico"), findsOneWidget);
    expect(find.text("Pilhas e baterias"), findsOneWidget);
    expect(
      find.text("Av. Santos Dumont, s/n — Atalaia, Aracaju"),
      findsOneWidget,
    );

    await tester.tap(find.text("Ver no mapa"));
    await tester.pumpAndSettle();

    expect(selectedLocation?.id, "orla");
  });

  testWidgets(
    "tapping Ver local navigates to the Home tab with focused campaign",
    (WidgetTester tester) async {
      useTallSurface(tester);
      final AppDataSync dataSync = _createTestDataSync();
      addTearDown(dataSync.dispose);
      await tester.runAsync(dataSync.initialize);

      await tester.pumpWidget(MyApp(dataSync: dataSync));
      await tester.pumpAndSettle();

      await tester.tap(find.text("eventos"));
      await tester.pumpAndSettle();

      final Finder orlaCard = find.ancestor(
        of: find.text("Mutirão de Lixo Eletrônico na Orla"),
        matching: find.byType(CampaignCard),
      );

      await tester.tap(
        find.descendant(of: orlaCard, matching: find.text("Ver local")),
      );
      await tester.pumpAndSettle();

      expect(find.text("ECOMONITOR"), findsOneWidget);
      expect(find.text("Mutirão de Lixo Eletrônico na Orla"), findsOneWidget);
      expect(find.text("Arcos da Orla de Atalaia"), findsOneWidget);

      await tester.tap(find.byTooltip("Fechar campanha"));
      await tester.pumpAndSettle();

      expect(find.text("Mutirão de Lixo Eletrônico na Orla"), findsNothing);
    },
  );
}
