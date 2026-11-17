import "dart:async";

import "package:flutter/material.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "data/app_data_sync.dart";
import "data/firebase_service.dart";
import "domain/entities/residue.dart";
import "screens/events_screen.dart";
import "screens/guide_navigator.dart";
import "screens/home_screen.dart";
import "screens/suggest_screen.dart";
import "theme/app_colors.dart";
import "widgets/custom_bottom_nav_bar.dart";
import "widgets/eco_app_bar.dart";
import "widgets/offline_banner.dart";

// Init -------------------------------------------------------------------- //

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const accessToken = String.fromEnvironment("ACCESS_TOKEN");
  if (accessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(accessToken);
  }

  // Initializes Firebase when platform credentials are present; gracefully
  // falls back to offline mode otherwise (RNF09, RNF10).
  await initializeFirebase();

  runApp(const MyApp());
}

// Classes ----------------------------------------------------------------- //

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.dataSync});

  /// Optional sync coordinator override used in tests.
  final AppDataSync? dataSync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "EcoMonitor",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: MyHomePage(title: "ECOMONITOR", dataSync: dataSync),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.dataSync});

  final String title;
  final AppDataSync? dataSync;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const int _homeTab = 0;
  static const int _guideTab = 1;

  // Composition root: wires the Firebase + offline Data layer to the
  // presentation layer.
  late final AppDataSync _dataSync;
  late final bool _ownsDataSync;

  int _selectedIndex = _homeTab;

  /// Residue type selected in the guide tab and applied to the map (RF12).
  ResidueType? _residueFilter;

  @override
  void initState() {
    super.initState();

    _ownsDataSync = widget.dataSync == null;
    _dataSync = widget.dataSync ?? AppDataSync.createDefault();
    unawaited(_dataSync.initialize());
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

  /// Opens the map tab already filtered by the residue chosen in the guide.
  void _showCollectionPoints(ResidueType type) {
    setState(() {
      _residueFilter = type;
      _selectedIndex = _homeTab;
    });
  }

  void _clearResidueFilter() {
    setState(() {
      _residueFilter = null;
    });
  }

  /// Home, Events and Suggest use the default AppBar. The Guia tab does not
  /// go through here: GuideNavigator draws its own AppBar on each screen.
  Widget _withAppBar(Widget body) {
    return Scaffold(
      appBar: EcoAppBar(title: widget.title),
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
              // Connectivity / staleness / pending-queue banner (RNF10, RNF17).
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
                        residueFilter: _residueFilter,
                        onClearFilter: _clearResidueFilter,
                        repository: _dataSync.collectPointsRepository,
                        dataSync: _dataSync,
                      ),
                    ),
                    GuideNavigator(
                      repository: _dataSync.guideRepository,
                      active: _selectedIndex == _guideTab,
                      onShowCollectionPoints: _showCollectionPoints,
                    ),
                    _withAppBar(
                      EventsScreen(
                        repository: _dataSync.campaignsRepository,
                        dataSync: _dataSync,
                      ),
                    ),
                    _withAppBar(
                      SuggestScreen(
                        repository: _dataSync.suggestionsRepository,
                        dataSync: _dataSync,
                      ),
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
