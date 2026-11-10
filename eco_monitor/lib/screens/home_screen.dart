import "package:flutter/material.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

// Home screen ------------------------------------------------------------- //

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _accessToken = String.fromEnvironment("ACCESS_TOKEN");

  @override
  Widget build(BuildContext context) {
    if (_accessToken.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 56, color: Color(0xFF58A29D)),
              SizedBox(height: 16),
              Text(
                "Configure o token do Mapbox",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                "Execute o app passando --dart-define=ACCESS_TOKEN=seu_token_publico.",
                style: TextStyle(color: Color(0xFF6B7280)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return MapWidget(
      key: const ValueKey("aracaju-map"),
      viewport: CameraViewportState(
        center: Point(coordinates: Position(-37.067, -10.95)),
        zoom: 10.7,
      ),
    );
  }
}
