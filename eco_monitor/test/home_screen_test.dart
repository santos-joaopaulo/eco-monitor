import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/app_data_sync.dart";
import "package:eco_monitor/data/campaigns_repository.dart";
import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/connectivity_service.dart";
import "package:eco_monitor/data/disposal_guide_repository_synced.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/screens/home_screen.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/mapbox_token_provider.dart";
import "package:eco_monitor/widgets/collect_point_sheet.dart";
import "package:eco_monitor/widgets/collect_points_list_view.dart";
import "package:eco_monitor/widgets/filter_bar.dart";
import "package:eco_monitor/widgets/home_map_controls.dart";
import "package:eco_monitor/widgets/route_summary_card.dart";


// Auxiliares -------------------------------------------------------------- //


void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _filterChip(String label) {
  return find.descendant(
    of: find.byType(FilterBar),
    matching: find.text(label),
  );
}

class _FakeLocationService extends LocationService {
  _FakeLocationService({
    this.permission = LocationPermissionState.denied,
    this.requestResult = LocationPermissionState.granted,
    this.position,
  });

  LocationPermissionState permission;
  LocationPermissionState requestResult;
  UserLocation? position;

  int currentPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int openAppSettingsCalls = 0;
  int currentPositionCalls = 0;

  @override
  Future<LocationPermissionState> currentPermission() async {
    currentPermissionCalls++;
    return permission;
  }

  @override
  Future<LocationPermissionState> requestPermission() async {
    requestPermissionCalls++;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
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

class _FakeCampaignsRepository extends CampaignsRepository {
  _FakeCampaignsRepository(this._campaigns);

  final List<Campaign> _campaigns;

  @override
  Future<List<Campaign>> loadOffline() async => _campaigns;

  @override
  Future<List<Campaign>> refresh() async => _campaigns;
}

CollectionPoint _buildPoint({
  required String id,
  required String name,
  required String address,
  required PointType type,
  required double latitude,
  required double longitude,
  Set<WasteType> acceptedWasteTypes = const <WasteType>{WasteType.medicines},
  PointStatus status = PointStatus.active,
  String hours = "Seg a Sex: 08:00 às 18:00",
}) {
  return CollectionPoint(
    id: id,
    name: name,
    type: type,
    latitude: latitude,
    longitude: longitude,
    address: address,
    acceptedWasteTypes: acceptedWasteTypes,
    hours: hours,
    status: status,
  );
}

Campaign _buildCampaign({
  required String id,
  required String title,
  required String locationName,
}) {
  return Campaign(
    id: id,
    title: title,
    description: "Descrição da campanha",
    wasteTypes: const <WasteType>{WasteType.batteries},
    locationName: locationName,
    address: "Endereço da campanha",
    latitude: -10.9400,
    longitude: -37.0600,
    startDate: DateTime.utc(2026, 11, 1),
    endDate: DateTime.utc(2026, 11, 30),
    status: CampaignStatus.active,
  );
}

AppDataSync _createTestDataSync({
  required List<CollectionPoint> points,
  bool isOnline = true,
}) {
  final DateTime fixedClock = DateTime.utc(2026, 11, 20, 12);

  return AppDataSync(
    collectPointsRepository: _FakeCollectPointsRepository(points),
    campaignsRepository: _FakeCampaignsRepository(const <Campaign>[]),
    suggestionsRepository: PointSuggestionsRepository(
      localStore: InMemoryLocalStore(),
    ),
    guideRepository: DisposalGuideRepositorySynced(
      clock: () => fixedClock,
      localStore: InMemoryLocalStore(),
    ),
    connectivityService: ConnectivityService(
      checkConnectivity: () async => isOnline
          ? const <ConnectivityResult>[ConnectivityResult.wifi]
          : const <ConnectivityResult>[ConnectivityResult.none],
      connectivityStream: const Stream<List<ConnectivityResult>>.empty(),
    ),
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

  final CollectionPoint pharmacyPoint = _buildPoint(
    id: "p1",
    name: "Farmácia Zona Sul",
    address: "Av. Beira Mar, 200",
    type: PointType.pharmacy,
    latitude: -10.9800,
    longitude: -37.0500,
    acceptedWasteTypes: const <WasteType>{WasteType.medicines},
  );

  final CollectionPoint ubsPoint = _buildPoint(
    id: "p2",
    name: "UBS Centro",
    address: "Rua São Cristóvão, 100",
    type: PointType.healthCenter,
    latitude: -10.9100,
    longitude: -37.0700,
    acceptedWasteTypes: const <WasteType>{
      WasteType.medicines,
      WasteType.sharps,
    },
  );

  final CollectionPoint ecoPoint = _buildPoint(
    id: "p3",
    name: "Ecoponto Coroa do Meio",
    address: "Av. Santos Dumont, 500",
    type: PointType.ecoPoint,
    latitude: -10.9700,
    longitude: -37.0400,
    acceptedWasteTypes: const <WasteType>{
      WasteType.batteries,
      WasteType.electronics,
    },
  );

  group("HomeScreen offline and tokenless fallback", () {
    testWidgets(
      "renders list fallback and Mapbox warning pill when token is empty",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[
          pharmacyPoint,
          ubsPoint,
        ]);

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

        expect(find.text("Configure o token do Mapbox"), findsOneWidget);
        expect(find.byType(CollectPointsListView), findsOneWidget);
        expect(find.text("Farmácia Zona Sul"), findsOneWidget);
        expect(find.text("UBS Centro"), findsOneWidget);
      },
    );

    testWidgets(
      "displays empty message when no points are available",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(const <CollectionPoint>[]);

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

        expect(find.text("Nenhum ponto de coleta cadastrado."), findsOneWidget);
      },
    );
  });

  group("HomeScreen waste filter chips", () {
    testWidgets(
      "filters list when tapping filter chips and restores on untap",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[
          pharmacyPoint,
          ubsPoint,
          ecoPoint,
        ]);

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

        expect(find.text("Farmácia Zona Sul"), findsOneWidget);
        expect(find.text("UBS Centro"), findsOneWidget);
        expect(find.text("Ecoponto Coroa do Meio"), findsOneWidget);

        // Filtra por Pilhas
        await tester.tap(_filterChip("Pilhas"));
        await tester.pumpAndSettle();

        expect(find.text("Farmácia Zona Sul"), findsNothing);
        expect(find.text("UBS Centro"), findsNothing);
        expect(find.text("Ecoponto Coroa do Meio"), findsOneWidget);

        // Desmarca Pilhas, restaurando todos os pontos
        await tester.tap(_filterChip("Pilhas"));
        await tester.pumpAndSettle();

        expect(find.text("Farmácia Zona Sul"), findsOneWidget);
        expect(find.text("UBS Centro"), findsOneWidget);
        expect(find.text("Ecoponto Coroa do Meio"), findsOneWidget);
      },
    );

    testWidgets(
      "notifies onClearFilter when initial waste filter is cleared",
      (WidgetTester tester) async {
        useTallSurface(tester);

        bool cleared = false;
        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[
          pharmacyPoint,
          ubsPoint,
        ]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                wasteFilter: WasteType.medicines,
                onClearFilter: () => cleared = true,
                repository: repository,
                locationService: _FakeLocationService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Remédios já está ativo inicialmente
        await tester.tap(_filterChip("Remédios"));
        await tester.pumpAndSettle();

        expect(cleared, isTrue);
      },
    );

    testWidgets(
      "displays empty filter state when no point matches selected filter",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[pharmacyPoint]);

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

        await tester.tap(_filterChip("Pilhas"));
        await tester.pumpAndSettle();

        expect(
          find.text("Nenhum ponto aceita os resíduos selecionados."),
          findsOneWidget,
        );
      },
    );
  });

  group("HomeScreen geolocation notices and actions", () {
    testWidgets(
      "displays permission denied notice and requests permission on action tap",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeLocationService locationService = _FakeLocationService(
          permission: LocationPermissionState.denied,
          requestResult: LocationPermissionState.granted,
          position: const UserLocation(latitude: -10.95, longitude: -37.06),
        );

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[pharmacyPoint]);

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

        expect(
          find.text("Permita o acesso à localização para ver sua posição."),
          findsOneWidget,
        );

        await tester.tap(find.text("Permitir"));
        await tester.pumpAndSettle();

        expect(locationService.requestPermissionCalls, 1);
        expect(
          find.text("Permita o acesso à localização para ver sua posição."),
          findsNothing,
        );
      },
    );

    testWidgets(
      "displays denied forever notice and opens settings on action tap",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeLocationService locationService = _FakeLocationService(
          permission: LocationPermissionState.deniedForever,
        );

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[pharmacyPoint]);

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

        expect(
          find.text(
            "A localização está bloqueada nas configurações do app.",
          ),
          findsOneWidget,
        );

        await tester.tap(find.text("Abrir configurações"));
        await tester.pumpAndSettle();

        expect(locationService.openAppSettingsCalls, 1);
      },
    );

    testWidgets(
      "displays service disabled notice and opens settings",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeLocationService locationService = _FakeLocationService(
          permission: LocationPermissionState.serviceDisabled,
        );

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[pharmacyPoint]);

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

        expect(
          find.text("Ative a localização do aparelho para ver sua posição."),
          findsOneWidget,
        );

        await tester.tap(find.text("Abrir configurações"));
        await tester.pumpAndSettle();

        expect(locationService.openAppSettingsCalls, 1);
      },
    );

    testWidgets(
      "displays location failure notice when position is null",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeLocationService locationService = _FakeLocationService(
          permission: LocationPermissionState.granted,
          position: null,
        );

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[pharmacyPoint]);

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

        final Finder locateFab = find.byType(HomeLocateButton);
        await tester.tap(locateFab);
        await tester.pumpAndSettle();

        expect(
          find.text("Não foi possível obter sua localização."),
          findsOneWidget,
        );

        locationService.position = const UserLocation(
          latitude: -10.95,
          longitude: -37.06,
        );

        await tester.tap(find.text("Tentar novamente"));
        await tester.pumpAndSettle();

        expect(
          find.text("Não foi possível obter sua localização."),
          findsNothing,
        );
      },
    );

    testWidgets(
      "tapping locate FAB button triggers location check",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeLocationService locationService = _FakeLocationService(
          permission: LocationPermissionState.denied,
        );

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[pharmacyPoint]);

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

        final Finder locateFab = find.byType(HomeLocateButton);
        expect(locateFab, findsOneWidget);

        await tester.tap(locateFab);
        await tester.pumpAndSettle();

        expect(locationService.requestPermissionCalls, 1);
      },
    );
  });

  group("HomeScreen CollectPointSheet bottom modal", () {
    testWidgets(
      "opens CollectPointSheet on point tap and dismisses on Cancel",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[pharmacyPoint]);

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

        expect(find.byType(CollectPointSheet), findsNothing);

        await tester.tap(find.text("Farmácia Zona Sul"));
        await tester.pumpAndSettle();

        expect(find.byType(CollectPointSheet), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CollectPointSheet),
            matching: find.text("Av. Beira Mar, 200"),
          ),
          findsOneWidget,
        );
        expect(find.text("MATERIAIS ACEITOS"), findsOneWidget);
        expect(find.text("Cancelar"), findsOneWidget);
        expect(find.text("Iniciar rota"), findsOneWidget);

        await tester.tap(find.text("Cancelar"));
        await tester.pumpAndSettle();

        expect(find.byType(CollectPointSheet), findsNothing);
      },
    );

    testWidgets(
      "dismisses CollectPointSheet when new filter excludes selected point",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[
          pharmacyPoint,
          ecoPoint,
        ]);

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

        await tester.tap(find.text("Farmácia Zona Sul"));
        await tester.pumpAndSettle();

        expect(find.byType(CollectPointSheet), findsOneWidget);

        // Aplica filtro de Pilhas (Farmácia Zona Sul não aceita)
        await tester.tap(_filterChip("Pilhas"));
        await tester.pumpAndSettle();

        expect(find.byType(CollectPointSheet), findsNothing);
      },
    );

    testWidgets(
      "initiates in-app offline route navigation without blocking snackbar",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final AppDataSync dataSync = _createTestDataSync(
          points: <CollectionPoint>[pharmacyPoint],
          isOnline: false,
        );
        addTearDown(dataSync.dispose);
        await dataSync.initialize();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                dataSync: dataSync,
                locationService: _FakeLocationService(
                  position: const UserLocation(
                    latitude: -10.945,
                    longitude: -37.065,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text("Farmácia Zona Sul"));
        await tester.pumpAndSettle();

        await tester.tap(find.text("Iniciar rota"));
        await tester.pumpAndSettle();

        expect(
          find.text("A rota exige conexão com a internet."),
          findsNothing,
        );
        expect(find.byType(RouteSummaryCard), findsOneWidget);
        expect(find.text("A pé"), findsOneWidget);
        expect(find.text("Bicicleta"), findsOneWidget);
        expect(find.text("Carro"), findsOneWidget);
        expect(
          find.text(
            "Modo offline: traçado direto por vetor e estimativa local.",
          ),
          findsOneWidget,
        );

        // Alterna para o modo Bicicleta
        await tester.tap(find.text("Bicicleta"));
        await tester.pumpAndSettle();

        // Encerra a rota
        await tester.tap(find.text("Encerrar rota"));
        await tester.pumpAndSettle();

        expect(find.byType(RouteSummaryCard), findsNothing);
      },
    );
  });

  group("HomeScreen focused campaign chip", () {
    testWidgets(
      "renders focused campaign chip and calls onClearCampaign when closed",
      (WidgetTester tester) async {
        useTallSurface(tester);

        bool cleared = false;
        final Campaign campaign = _buildCampaign(
          id: "camp-1",
          title: "Mutirão da Limpeza",
          locationName: "Parque da Cidade",
        );

        final _FakeCollectPointsRepository repository =
            _FakeCollectPointsRepository(<CollectionPoint>[pharmacyPoint]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                focusedCampaign: campaign,
                onClearCampaign: () => cleared = true,
                repository: repository,
                locationService: _FakeLocationService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Mutirão da Limpeza"), findsOneWidget);
        expect(find.text("Parque da Cidade"), findsOneWidget);

        await tester.tap(find.byTooltip("Fechar campanha"));
        await tester.pumpAndSettle();

        expect(cleared, isTrue);
      },
    );
  });
}
