
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'screens/events_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/home_screen.dart';
import 'screens/suggest_screen.dart';


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
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    GuideScreen(),
    EventsScreen(),
    SuggestScreen(),
  ];

  Widget _buildNavButton({
    required int index,
    required String label,
    required IconData icon,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final bool isSelected = _selectedIndex == index;
    final Color color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        debugPrint("Selected tab: $label (index: $index)");
        setState(() {
          _selectedIndex = index;
        });
      },

      child: SizedBox(
        width: 48,
        height: 48,

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 24,
              color: color,
            ),

            SizedBox(height: 4),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Color(0xFF58A29D);
    const Color inactiveColor = Color(0xFF9CA3AF);

    return Scaffold(
      extendBody: true,

      appBar: AppBar(
        backgroundColor: Color(0xFF58A29D),
        centerTitle: true,

        leading: const Padding(
          padding: EdgeInsets.only(left: 24),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Image(image: AssetImage("assets/logo.png")),
          ),
        ),

        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1.0,

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),

            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),

              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(32),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,

                  children: [
                    _buildNavButton(
                      index: 0,
                      label: "Início",
                      icon: Icons.home_outlined,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                    _buildNavButton(
                      index: 1,
                      label: "Guia",
                      icon: Icons.map_outlined,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                    _buildNavButton(
                      index: 2,
                      label: "Eventos",
                      icon: Icons.calendar_today_outlined,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                    _buildNavButton(
                      index: 3,
                      label: "Sugerir",
                      icon: Icons.add_location_alt_outlined,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
