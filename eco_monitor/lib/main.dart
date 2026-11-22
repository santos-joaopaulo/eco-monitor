import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "data/app_data_sync.dart";
import "data/firebase_service.dart";
import "domain/entities/waste_type.dart";
import "models/campaign.dart";
import "screens/events_screen.dart";
import "screens/guide_navigator.dart";
import "screens/home_screen.dart";
import "screens/suggest_screen.dart";
import "services/location_service.dart";
import "services/mapbox_token_provider.dart";
import "theme/app_colors.dart";
import "widgets/custom_bottom_nav_bar.dart";
import "widgets/eco_app_bar.dart";
import "widgets/offline_banner.dart";


// Inicialização ------------------------------------------------------------ //


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve o token do Mapbox (variável de compilação ou arquivo local)
  // antes de criar o mapa, para que builds sem --dart-define funcionem.
  await MapboxTokenProvider.loadLocalToken();
  final accessToken = MapboxTokenProvider.token;
  if (accessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(accessToken);
  }

  // Inicializa o Firebase quando as credenciais da plataforma estão presentes;
  // caso contrário, opera em modo offline (RNF09, RNF10).
  await initializeFirebase();

  runApp(const MyApp());
}


// Classes ----------------------------------------------------------------- //


class MyApp extends StatelessWidget {
  const MyApp({super.key, this.dataSync, this.locationService});

  /// Coordenador de sincronização opcional utilizado em testes.
  final AppDataSync? dataSync;

  /// Serviço de localização opcional utilizado em testes.
  final LocationService? locationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "EcoMonitor",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: MyHomePage(
        key: ValueKey<Object?>(dataSync),
        title: "ECOMONITOR",
        dataSync: dataSync,
        locationService: locationService,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    this.dataSync,
    this.locationService,
  });

  final String title;
  final AppDataSync? dataSync;
  final LocationService? locationService;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const int _homeTab = 0;
  static const int _guideTab = 1;
  static const int _eventsTab = 2;

  // Raiz de composição: conecta a camada de dados (Firebase + offline) à
  // camada de apresentação.
  late final AppDataSync _dataSync;
  late final bool _ownsDataSync;

  int _selectedIndex = _homeTab;

  /// Tipo de resíduo selecionado na aba do guia e aplicado ao mapa (RF12).
  WasteType? _wasteFilter;

  /// Campanha selecionada na aba de eventos para focar no mapa (RF09).
  Campaign? _focusedCampaign;

  @override
  void initState() {
    super.initState();

    _ownsDataSync = widget.dataSync == null;
    _dataSync = widget.dataSync ?? AppDataSync.createDefault();
    unawaited(_dataSync.initialize());
  }

  @override
  void didUpdateWidget(covariant MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSync != widget.dataSync) {
      if (_ownsDataSync) {
        _dataSync.dispose();
      }
      _ownsDataSync = widget.dataSync == null;
      _dataSync = widget.dataSync ?? AppDataSync.createDefault();
      unawaited(_dataSync.initialize());
    }
  }

  @override
  void dispose() {
    if (_ownsDataSync) {
      _dataSync.dispose();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Abre a aba do mapa já filtrada pelo resíduo escolhido no guia.
  void _showCollectionPoints(WasteType type) {
    setState(() {
      _wasteFilter = type;
      _focusedCampaign = null;
      _selectedIndex = _homeTab;
    });
  }

  void _clearWasteFilter() {
    setState(() {
      _wasteFilter = null;
    });
  }

  /// Abre a aba do mapa focada na localização de uma campanha (RF09).
  void _showCampaignLocation(Campaign campaign) {
    setState(() {
      _focusedCampaign = campaign;
      _wasteFilter = null;
      _selectedIndex = _homeTab;
    });
  }

  void _clearFocusedCampaign() {
    setState(() {
      _focusedCampaign = null;
    });
  }

  /// Envolve uma aba com a [EcoAppBar] padrão. A aba de Guia não passa por
  /// aqui: o GuideNavigator renderiza sua própria AppBar em cada tela.
  Widget _withAppBar(Widget body, {String? title}) {
    return Scaffold(
      appBar: EcoAppBar(title: title ?? widget.title),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: ListenableBuilder(
        listenable: _dataSync,
        builder: (BuildContext context, Widget? child) {
          return Column(
            children: [
              // Banner de conectividade, desatualização e fila pendente (RNF10, RNF17).
              OfflineBanner(
                isOffline: !_dataSync.isOnline,
                isStale: _dataSync.isStale,
                lastUpdated: _dataSync.lastUpdated,
                pendingSuggestionsCount: _dataSync.pendingSuggestionsCount,
                isSyncing: _dataSync.isSyncing,
                onRetry: () {
                  unawaited(_dataSync.refreshAll());
                },
              ),

              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _withAppBar(
                      HomeScreen(
                        wasteFilter: _wasteFilter,
                        onClearFilter: _clearWasteFilter,
                        focusedCampaign: _focusedCampaign,
                        onClearCampaign: _clearFocusedCampaign,
                        repository: _dataSync.collectPointsRepository,
                        dataSync: _dataSync,
                        locationService: widget.locationService ?? const LocationService(),
                        isActive: _selectedIndex == _homeTab,
                      ),
                    ),
                    GuideNavigator(
                      repository: _dataSync.guideRepository,
                      active: _selectedIndex == _guideTab,
                      onShowCollectionPoints: _showCollectionPoints,
                      onBackToHome: () => _selectTab(_homeTab),
                    ),
                    _withAppBar(
                      TickerMode(
                        enabled: _selectedIndex == _eventsTab,
                        child: EventsScreen(
                          repository: _dataSync.campaignsRepository,
                          dataSync: _dataSync,
                          onShowCampaignLocation: _showCampaignLocation,
                        ),
                      ),
                      title: "CAMPANHAS ATIVAS",
                    ),
                    _withAppBar(
                      SuggestScreen(
                        repository: _dataSync.suggestionsRepository,
                        dataSync: _dataSync,
                      ),
                      title: "SUGERIR NOVO PONTO",
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _selectTab,
      ),
    );
  }
}
