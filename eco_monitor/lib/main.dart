
import "package:flutter/material.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "data/guia_repository_local.dart";
import "screens/events_screen.dart";
import "screens/guia_navigator.dart";
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
  static const int _abaHome = 0;
  static const int _abaGuia = 1;

  // Raiz de composição: é aqui que a camada Data é ligada à apresentação.
  static const GuiaRepositoryLocal _guiaRepository = GuiaRepositoryLocal();

  int _selectedIndex = _abaHome;

  void _selecionarAba(int index) {
    debugPrint("Selected tab: $index");
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Home, Eventos e Sugerir usam o AppBar padrão. A aba Guia não passa por
  /// aqui: o GuiaNavigator desenha o próprio AppBar em cada tela.
  Widget _comAppBar(Widget corpo) {
    return Scaffold(
      appBar: EcoAppBar(title: widget.title),
      body: corpo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _comAppBar(const HomeScreen()),
          GuiaNavigator(
            repository: _guiaRepository,
            ativo: _selectedIndex == _abaGuia,
            onVerPontosNoMapa: () => _selecionarAba(_abaHome),
          ),
          _comAppBar(const EventsScreen()),
          _comAppBar(const SuggestScreen()),
        ],
      ),

      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _selecionarAba,
      ),
    );
  }
}
