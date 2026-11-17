import "package:flutter/material.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "../domain/entities/residue.dart";
import "../theme/eco_theme.dart";
import "../widgets/residue_style.dart";

// Home screen ------------------------------------------------------------- //

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.residueFilter, this.onClearFilter});

  /// Residue type received from the guide tab; shows the active filter.
  final ResidueType? residueFilter;
  final VoidCallback? onClearFilter;

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
            center: Point(coordinates: Position(-37.067, -10.95)),
            zoom: 10.7,
          ),
        ),

        // TODO: filter collection points by residue type.
        if (residueFilter != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Center(
              child: _ResidueFilterChip(
                type: residueFilter!,
                onClear: onClearFilter,
              ),
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

                // TODO: obtain the device location (RF14) and fly the camera
                // to the nearest collection point. Needs a location plugin
                // (ex. geolocator) plus the runtime permission on Android and
                // iOS.
                onPressed: null,

                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResidueFilterChip extends StatelessWidget {
  const _ResidueFilterChip({required this.type, this.onClear});

  final ResidueType type;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: EcoColors.surface,
      elevation: 3,
      shadowColor: Colors.black.withAlpha(40),
      borderRadius: BorderRadius.circular(24),

      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 20, color: type.color),
            const SizedBox(width: 8),
            Text(
              "Filtro: ${type.label}",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: EcoColors.textPrimary,
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: EcoColors.textSecondary,
                ),
                tooltip: "Limpar filtro",
              ),
          ],
        ),
      ),
    );
  }
}
