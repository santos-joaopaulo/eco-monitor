
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

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey("aracaju-map"),

          onMapCreated: (MapboxMap mapboxMap) async {
            await mapboxMap.scaleBar.updateSettings(
              ScaleBarSettings(enabled: false),
            );
          },

          viewport: CameraViewportState(
            center: Point(
              coordinates: Position(-37.067, -10.95),
            ),
            zoom: 10.7,
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: (80 + 32),
          child: Center(
            child: SizedBox(
              width: 72,
              height: 72,
              
              child: FloatingActionButton(
                backgroundColor: const Color(0xFF58A29D),
                shape: CircleBorder(),

                onPressed: () { debugPrint("Botão pressionado!"); },
                
                child: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                ),
              ),  
            ), 
          ),
        ),
      ],
    );
  }
}
