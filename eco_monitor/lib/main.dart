import "dart:async";

import "package:firebase_core/firebase_core.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

import "data/app_data_sync.dart";
import "data/firebase_service.dart";
import "domain/entities/waste_type.dart";
import "firebase_options.dart";
import "models/campaign.dart";
import "presentation/state/app_providers.dart";
import "presentation/state/sync_notifier.dart";
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
  FirebaseOptions? firebaseOptions;
  try {
    firebaseOptions = DefaultFirebaseOptions.currentPlatform;
  } catch (_) {
    // Plataformas desktop não configuradas caem silenciosamente em modo offline.
  }
  await initializeFirebase(options: firebaseOptions);

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

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
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

  /// Controla a visibilidade da barra de navegação inferior quando um Bottom Sheet está ativo na Home.
  bool _isBottomSheetActive = false;

  /// Controla a exibição da busca rápida na Home via ação da EcoAppBar.
  bool _isSearchActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ownsDataSync = widget.dataSync == null;
    _dataSync = widget.dataSync ?? AppDataSync.createDefault();
    unawaited(_dataSync.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_dataSync.connectivityService.checkNow());
    }
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
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsDataSync) {
      _dataSync.dispose();
    }
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _isSearchActive = false;
    });
  }

  /// Abre a aba do mapa já filtrada pelo resíduo escolhido no guia.
  void _showCollectionPoints(WasteType type) {
    setState(() {
      _wasteFilter = type;
      _focusedCampaign = null;
      _isSearchActive = false;
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
      _isSearchActive = false;
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
  Widget _withAppBar(
    Widget body, {
    String? title,
    Widget? banner,
    List<Widget>? actions,
  }) {
    return Scaffold(
      extendBody: true,
      appBar: EcoAppBar(
        title: title ?? widget.title,
        dataSync: _dataSync,
        actions: actions,
      ),
      body: banner != null
          ? Column(
              children: [
                banner,
                Expanded(child: body),
              ],
            )
          : body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: buildAppProviders(
        dataSync: _dataSync,
        locationService: widget.locationService ?? const LocationService(),
      ),
      child: Scaffold(
        extendBody: true,

        body: Consumer<SyncNotifier>(
          builder: (BuildContext context, SyncNotifier sync, Widget? child) {
            // Banner de conectividade, desatualização e fila pendente posicionado
            // abaixo da AppBar de cada tela (RNF10, RNF17).
            final Widget offlineBanner = OfflineBanner(
              isOffline: !sync.isOnline,
              isStale: sync.isStale,
              lastUpdated: sync.lastUpdated,
              pendingSuggestionsCount: sync.pendingSuggestionsCount,
              isSyncing: sync.isSyncing,
              onRetry: () {
                unawaited(sync.refreshAll());
              },
            );

            final List<Widget> homeAppBarActions = [
              if (!sync.isOnline)
                IconButton(
                  icon: const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: "Modo offline (dados salvos localmente)",
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                            "Modo offline: exibindo ecopontos salvos na memória do aparelho.",
                          ),
                        ),
                      );
                  },
                )
              else if (sync.isStale)
                IconButton(
                  icon: const Icon(
                    Icons.update_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: "Dados desatualizados · Toque para atualizar",
                  onPressed: () => unawaited(sync.refreshAll()),
                )
              else if (sync.pendingSuggestionsCount > 0)
                IconButton(
                  icon: const Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip:
                      "${sync.pendingSuggestionsCount} pendente(s) para sincronização",
                  onPressed: () => unawaited(sync.refreshAll()),
                ),

              IconButton(
                icon: Icon(
                  _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                tooltip: _isSearchActive ? "Fechar busca" : "Buscar resíduo",
                onPressed: () {
                  setState(() {
                    _isSearchActive = !_isSearchActive;
                  });
                },
              ),
            ];

            return IndexedStack(
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
                    locationService:
                        widget.locationService ?? const LocationService(),
                    isActive: _selectedIndex == _homeTab,
                    isSearchActive: _isSearchActive,
                    onSearchActiveChanged: (bool active) {
                      if (_isSearchActive != active && mounted) {
                        setState(() {
                          _isSearchActive = active;
                        });
                      }
                    },
                    onActiveSheetChanged: (bool active) {
                      if (_isBottomSheetActive != active && mounted) {
                        setState(() {
                          _isBottomSheetActive = active;
                        });
                      }
                    },
                  ),
                  actions: homeAppBarActions,
                ),
                GuideNavigator(
                  repository: _dataSync.guideRepository,
                  active: _selectedIndex == _guideTab,
                  onShowCollectionPoints: _showCollectionPoints,
                  onBackToHome: () => _selectTab(_homeTab),
                  banner: offlineBanner,
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
                  banner: offlineBanner,
                ),
                _withAppBar(
                  SuggestScreen(
                    repository: _dataSync.suggestionsRepository,
                    dataSync: _dataSync,
                  ),
                  title: "SUGERIR NOVO PONTO",
                  banner: offlineBanner,
                ),
              ],
            );
          },
        ),

        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: _selectTab,
          isVisible: !_isBottomSheetActive,
        ),
      ),
    );
  }
}
