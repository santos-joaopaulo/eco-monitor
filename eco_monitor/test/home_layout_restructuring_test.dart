import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/screens/home_screen.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/widgets/eco_app_bar.dart";
import "package:eco_monitor/widgets/filter_bar.dart";
import "package:eco_monitor/widgets/focused_campaign_sheet.dart";
import "package:eco_monitor/widgets/home_map_controls.dart";
import "package:eco_monitor/widgets/home_map_top_bar.dart";
import "package:eco_monitor/widgets/radius_filter_bar.dart";


// Auxiliares -------------------------------------------------------------- //


void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _FakeLocationService extends LocationService {
  @override
  Future<LocationPermissionState> currentPermission() async =>
      LocationPermissionState.granted;

  @override
  Future<UserLocation?> currentPosition() async =>
      const UserLocation(latitude: -10.9300, longitude: -37.0600);

  @override
  Stream<UserLocation> positionStream({int distanceFilter = 5}) =>
      Stream<UserLocation>.value(
        const UserLocation(latitude: -10.9300, longitude: -37.0600),
      );
}

class _FakeRepo extends CollectPointsRepository {
  _FakeRepo(this._points) : super(localStore: InMemoryLocalStore());

  final List<CollectionPoint> _points;

  @override
  bool get hasRemoteSource => false;

  @override
  Future<List<CollectionPoint>> loadOffline() async => _points;

  @override
  Future<List<CollectionPoint>> refresh() async => _points;
}

CollectionPoint _makePoint({
  required String id,
  required String name,
  required double latitude,
  required double longitude,
}) {
  return CollectionPoint(
    id: id,
    name: name,
    type: PointType.pharmacy,
    latitude: latitude,
    longitude: longitude,
    address: "Rua Exemplo, 123",
    acceptedWasteTypes: const <WasteType>{WasteType.medicines},
    hours: "08:00 - 18:00",
    status: PointStatus.active,
  );
}

Campaign _makeCampaign({
  required String id,
  required String title,
  required String locationName,
}) {
  return Campaign(
    id: id,
    title: title,
    description: "Mutirão para recolhimento ecológico.",
    wasteTypes: const <WasteType>{WasteType.batteries},
    locationName: locationName,
    address: "Praça Fausto Cardoso, Centro",
    latitude: -10.9100,
    longitude: -37.0500,
    startDate: DateTime.utc(2026, 11, 20),
    endDate: DateTime.utc(2026, 11, 30),
    status: CampaignStatus.active,
  );
}


// Testes ------------------------------------------------------------------ //


void main() {
  group("Reestruturação do Layout e UX da Tela Inicial (Home)", () {
    testWidgets(
      "EcoAppBar suporta ações com ícones de busca e indicador offline",
      (WidgetTester tester) async {
        useTallSurface(tester);
        bool searchTapped = false;
        bool offlineTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: EcoAppBar(
                title: "ECOMONITOR",
                actions: [
                  IconButton(
                    icon: const Icon(Icons.wifi_off_rounded),
                    tooltip: "Modo offline",
                    onPressed: () => offlineTapped = true,
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    tooltip: "Buscar resíduo",
                    onPressed: () => searchTapped = true,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.search_rounded));
        expect(searchTapped, isTrue);

        await tester.tap(find.byIcon(Icons.wifi_off_rounded));
        expect(offlineTapped, isTrue);
      },
    );

    testWidgets(
      "HomeMapTopBar exibe FilterBar e RadiusFilterBar compactos e suprime pills redundantes",
      (WidgetTester tester) async {
        useTallSurface(tester);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeMapTopBar(
                selectedWasteTypes: const <WasteType>{WasteType.medicines},
                onFilterChanged: (_) {},
                showMapboxTokenWarning: false,
                isLoadingPoints: false,
                isEmptyResult: true,
                emptyMessage: "Nenhum ponto",
                locationNotice: null,
                isListMode: false,
                isRadiusEmpty: true,
                onExpandRadius: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Filtro de resíduos e raio presentes
        expect(find.byType(FilterBar), findsOneWidget);
        expect(find.byType(RadiusFilterBar), findsOneWidget);

        // Quando isRadiusEmpty == true, exibe EmptyRadiusNoticePill e suprime _MapStatusPill redundante
        expect(find.byType(EmptyRadiusNoticePill), findsOneWidget);
        expect(find.text("Nenhum ponto"), findsNothing);

        // Campo de texto permanente NÃO existe no topo
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets(
      "FocusedCampaignSheet exibe padrão visual com ícone de evento, dados e ações",
      (WidgetTester tester) async {
        useTallSurface(tester);
        bool cleared = false;
        bool routeStarted = false;

        final Campaign campaign = _makeCampaign(
          id: "camp-test",
          title: "Mutirão da Orla",
          locationName: "Arcos da Orla",
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusedCampaignSheet(
                campaign: campaign,
                onClearCampaign: () => cleared = true,
                onStartRoute: () => routeStarted = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Mutirão da Orla"), findsOneWidget);
        expect(find.text("Arcos da Orla"), findsOneWidget);
        expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
        expect(find.text("Traçar rota para a campanha"), findsOneWidget);

        // Toca no botão de traçar rota
        await tester.tap(find.text("Traçar rota para a campanha"));
        expect(routeStarted, isTrue);

        // Fecha a campanha
        await tester.tap(find.byTooltip("Fechar campanha"));
        expect(cleared, isTrue);
      },
    );

    testWidgets(
      "HomeScreen exibe botão unificado de ponto mais próximo e botões na área inferior no estado neutro",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final CollectionPoint pt = _makePoint(
          id: "pt-1",
          name: "Farmácia Teste",
          latitude: -10.9310,
          longitude: -37.0610,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                repository: _FakeRepo([pt]),
                locationService: _FakeLocationService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Botões flutuantes presentes na área inferior no estado neutro
        expect(find.byType(HomeSearchButton), findsOneWidget);
        expect(find.byType(HomeLocateButton), findsOneWidget);

        // Ao tocar no botão de busca, expande a busca e oculta os botões neutros
        await tester.tap(find.byType(HomeSearchButton));
        await tester.pumpAndSettle();

        expect(find.byType(HomeSearchBar), findsOneWidget);
        expect(find.byType(HomeLocateButton), findsNothing);

        // Toca no backdrop de busca para fechar
        await tester.tap(find.byKey(const ValueKey("home-search-backdrop")));
        await tester.pumpAndSettle();

        expect(find.byType(HomeSearchBar), findsNothing);
        expect(find.byType(HomeLocateButton), findsOneWidget);
      },
    );

    testWidgets(
      "HomeViewToggleButton alterna entre visualização em lista e mapa",
      (WidgetTester tester) async {
        useTallSurface(tester);
        bool isList = false;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    HomeViewToggleButton(
                      bottom: 20,
                      isListMode: isList,
                      onPressed: () {
                        setState(() {
                          isList = !isList;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Alterna para visualização em lista
        expect(find.byTooltip("Visualização em lista"), findsOneWidget);
        await tester.tap(find.byTooltip("Visualização em lista"));
        await tester.pumpAndSettle();

        // No modo lista, o botão de alternar permanece visível para voltar ao mapa
        expect(find.byTooltip("Visualização em mapa"), findsOneWidget);
        await tester.tap(find.byTooltip("Visualização em mapa"));
        await tester.pumpAndSettle();

        // Retorna ao mapa com sucesso
        expect(find.byTooltip("Visualização em lista"), findsOneWidget);
      },
    );

    testWidgets(
      "HomeScreen exibe FocusedCampaignSheet na parte inferior quando focusedCampaign != null",
      (WidgetTester tester) async {
        useTallSurface(tester);
        bool cleared = false;
        bool sheetActiveNotified = false;

        final Campaign campaign = _makeCampaign(
          id: "camp-foco",
          title: "Campanha Focada no Mapa",
          locationName: "Parque da Cidade",
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                focusedCampaign: campaign,
                onClearCampaign: () => cleared = true,
                onActiveSheetChanged: (active) => sheetActiveNotified = active,
                repository: _FakeRepo([]),
                locationService: _FakeLocationService(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // FocusedCampaignSheet está visível na parte inferior
        expect(find.byType(FocusedCampaignSheet), findsOneWidget);
        expect(find.text("Campanha Focada no Mapa"), findsOneWidget);
        expect(find.text("Parque da Cidade"), findsOneWidget);

        // Botões neutros ocultos quando há campanha focada
        expect(find.byType(HomeLocateButton), findsNothing);
        expect(sheetActiveNotified, isTrue);

        // Fecha a campanha
        await tester.tap(find.byTooltip("Fechar campanha"));
        await tester.pumpAndSettle();

        expect(cleared, isTrue);
      },
    );
  });
}
