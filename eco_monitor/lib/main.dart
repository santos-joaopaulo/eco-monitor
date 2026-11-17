import "package:flutter/material.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "data/disposal_guide_repository_local.dart";
import "screens/events_screen.dart";
import "screens/guide_navigator.dart";
import "screens/home_screen.dart";
import "screens/suggest_screen.dart";
import "widgets/custom_bottom_nav_bar.dart";
import "widgets/eco_app_bar.dart";


// Init -------------------------------------------------------------------- //


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const accessToken = String.fromEnvironment("ACCESS_TOKEN");
  if (accessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(accessToken);
  }
  runApp(const MyApp());
}


// Classes ----------------------------------------------------------------- //


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "EcoMonitor",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF58A29D)),
      ),
      home: const MyHomePage(title: "ECOMONITOR"),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}


class _MyHomePageState extends State<MyHomePage> {
  static const int _homeTab = 0;
  static const int _guideTab = 1;

  // Composition root: this is where the Data layer is wired to the
  // presentation.
  static const DisposalGuideRepositoryLocal _guideRepository =
    DisposalGuideRepositoryLocal();

  int _selectedIndex = _homeTab;

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
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

      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _withAppBar(const HomeScreen()),
          GuideNavigator(
            repository: _guideRepository,
            active: _selectedIndex == _guideTab,
            onShowCollectionPoints: () => _selectTab(_homeTab),
          ),
          _withAppBar(const EventsScreen()),
          _withAppBar(const SuggestScreen()),
        ],
      ),

      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _selectTab,
      ),
    );
  }
}
