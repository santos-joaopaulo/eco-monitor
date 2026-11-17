import "package:flutter/material.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "../data/app_data_sync.dart";
import "../data/collect_points_repository.dart";
import "../domain/entities/residue.dart";
import "../models/collection_point.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../widgets/residue_style.dart";

// Home screen ------------------------------------------------------------- //

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.residueFilter,
    this.onClearFilter,
    this.repository,
    this.dataSync,
  });

  /// Residue type received from the guide tab; shows the active filter.
  final ResidueType? residueFilter;
  final VoidCallback? onClearFilter;

  /// Offline-first repository for collection points (RF05, RNF11).
  final CollectPointsRepository? repository;

  /// Shared online/offline sync controller injected from the composition root.
  final AppDataSync? dataSync;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _accessToken = String.fromEnvironment("ACCESS_TOKEN");

  List<CollectionPoint> _points = const <CollectionPoint>[];

  @override
  void initState() {
    super.initState();
    widget.dataSync?.addListener(_onSyncUpdated);
    _loadInitialPoints();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSync != widget.dataSync) {
      oldWidget.dataSync?.removeListener(_onSyncUpdated);
      widget.dataSync?.addListener(_onSyncUpdated);
      _onSyncUpdated();
    }
  }

  @override
  void dispose() {
    widget.dataSync?.removeListener(_onSyncUpdated);
    super.dispose();
  }

  void _onSyncUpdated() {
    final AppDataSync? sync = widget.dataSync;
    if (sync == null || !mounted) {
      return;
    }

    setState(() {
      _points = sync.points;
    });
  }

  Future<void> _loadInitialPoints() async {
    final AppDataSync? sync = widget.dataSync;
    if (sync != null) {
      if (sync.points.isNotEmpty) {
        setState(() {
          _points = sync.points;
        });
      }
      return;
    }

    final CollectPointsRepository? repository = widget.repository;
    if (repository == null) {
      return;
    }

    final List<CollectionPoint> offline = await repository.loadOffline();
    if (mounted) {
      setState(() {
        _points = offline;
      });
    }

    if (repository.hasRemoteSource) {
      final List<CollectionPoint> refreshed = await repository.refresh();
      if (mounted) {
        setState(() {
          _points = refreshed;
        });
      }
    }
  }

  List<CollectionPoint> get _filteredPoints {
    final WasteType? wasteType = _wasteTypeFor(widget.residueFilter);
    if (wasteType == null) {
      return _points;
    }

    return _points
        .where((CollectionPoint point) => point.accepts(wasteType))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_accessToken.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(Icons.map_outlined, size: 56, color: AppColors.primary),

              SizedBox(height: 16),

              Text(
                "Configure o token do Mapbox",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 8),

              Text(
                "Execute o app passando --dart-define=ACCESS_TOKEN=seu_token_publico.",
                style: TextStyle(color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final List<CollectionPoint> visiblePoints = _filteredPoints;

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

        if (widget.residueFilter != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Center(
              child: _ResidueFilterChip(
                type: widget.residueFilter!,
                matchCount: visiblePoints.length,
                onClear: widget.onClearFilter,
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
                backgroundColor: AppColors.primary,
                shape: const CircleBorder(),

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
  const _ResidueFilterChip({
    required this.type,
    required this.matchCount,
    this.onClear,
  });

  final ResidueType type;
  final int matchCount;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final String countSuffix = matchCount > 0 ? " ($matchCount)" : "";

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
              "Filtro: ${type.label}$countSuffix",
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

// Methods ----------------------------------------------------------------- //

WasteType? _wasteTypeFor(ResidueType? residue) {
  return switch (residue) {
    ResidueType.medicine => WasteType.medicines,
    ResidueType.battery => WasteType.batteries,
    ResidueType.sharps => WasteType.sharps,
    null => null,
  };
}
