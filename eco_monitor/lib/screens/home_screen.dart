import "dart:async";

import "package:flutter/material.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "../data/app_data_sync.dart";
import "../data/collect_points_repository.dart";
import "../domain/entities/residue.dart";
import "../models/campaign.dart";
import "../models/collection_point.dart";
import "../services/location_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../widgets/location_notice.dart";
import "../widgets/residue_style.dart";

// Home screen ------------------------------------------------------------- //

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.residueFilter,
    this.onClearFilter,
    this.focusedCampaign,
    this.onClearCampaign,
    this.repository,
    this.dataSync,
    this.locationService = const LocationService(),
  });

  /// Residue type received from the guide tab; shows the active filter.
  final ResidueType? residueFilter;
  final VoidCallback? onClearFilter;

  /// Campaign received from the events tab to focus on the map (RF09).
  final Campaign? focusedCampaign;
  final VoidCallback? onClearCampaign;

  /// Offline-first repository for collection points (RF05, RNF11).
  final CollectPointsRepository? repository;

  /// Shared online/offline sync controller injected from the composition root.
  final AppDataSync? dataSync;

  /// Device location service used to show and follow the user position (RF14).
  final LocationService locationService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _accessToken = String.fromEnvironment("ACCESS_TOKEN");
  static const double _userZoom = 14;

  MapboxMap? _mapboxMap;
  List<CollectionPoint> _points = const <CollectionPoint>[];
  LocationPermissionState? _permissionState;
  UserLocation? _userLocation;
  bool _isLocating = false;
  bool _locationFailed = false;
  bool _cameraCenteredOnUser = false;

  // Init ------------------------------------------------------------------ //

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.dataSync?.addListener(_onSyncUpdated);
    _loadInitialPoints();
    unawaited(_checkLocationAvailability());
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSync != widget.dataSync) {
      oldWidget.dataSync?.removeListener(_onSyncUpdated);
      widget.dataSync?.addListener(_onSyncUpdated);
      _onSyncUpdated();
    }

    final Campaign? nextCampaign = widget.focusedCampaign;
    if (nextCampaign != null && nextCampaign != oldWidget.focusedCampaign) {
      unawaited(_flyToCampaign(nextCampaign));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkLocationAvailability());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.dataSync?.removeListener(_onSyncUpdated);
    super.dispose();
  }

  // Methods --------------------------------------------------------------- //

  Future<void> _flyToCampaign(Campaign campaign) async {
    final MapboxMap? map = _mapboxMap;
    if (map == null) {
      return;
    }

    await map.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(campaign.longitude, campaign.latitude),
        ),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 800),
    );
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

  Future<void> _checkLocationAvailability() async {
    final LocationPermissionState permission = await widget.locationService
        .currentPermission();

    if (!mounted) {
      return;
    }

    setState(() {
      _permissionState = permission;
      if (permission != LocationPermissionState.granted) {
        _locationFailed = false;
      }
    });

    if (permission == LocationPermissionState.granted) {
      await _locateUser();
    }
  }

  Future<void> _handleLocationAction() async {
    switch (_permissionState) {
      case LocationPermissionState.serviceDisabled:
      case LocationPermissionState.deniedForever:
        await widget.locationService.openAppSettings();
        return;
      case LocationPermissionState.denied:
        await _requestLocation();
        return;
      case LocationPermissionState.granted:
      case null:
        await _locateUser();
        return;
    }
  }

  Future<void> _requestLocation() async {
    final LocationPermissionState permission = await widget.locationService
        .requestPermission();

    if (!mounted) {
      return;
    }

    setState(() {
      _permissionState = permission;
      _locationFailed = false;
    });

    if (permission == LocationPermissionState.granted) {
      await _locateUser();
    }
  }

  Future<void> _locateUser() async {
    if (_isLocating) {
      return;
    }

    setState(() {
      _isLocating = true;
      _locationFailed = false;
    });

    final UserLocation? location = await widget.locationService
        .currentPosition();

    if (!mounted) {
      return;
    }

    if (location == null) {
      setState(() {
        _isLocating = false;
        _locationFailed = true;
      });
      return;
    }

    setState(() {
      _isLocating = false;
      _userLocation = location;
    });

    await _showUserLocation();
  }

  Future<void> _showUserLocation() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    final UserLocation? location = _userLocation;

    if (mapboxMap == null || location == null) {
      return;
    }

    try {
      await mapboxMap.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          pulsingColor: AppColors.userLocation.toARGB32(),
          showAccuracyRing: true,
          accuracyRingColor: AppColors.userLocation
              .withValues(alpha: 0.18)
              .toARGB32(),
          accuracyRingBorderColor: AppColors.userLocation.toARGB32(),
        ),
      );

      if (_cameraCenteredOnUser) {
        return;
      }

      _cameraCenteredOnUser = true;

      await mapboxMap.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          zoom: _userZoom,
        ),
        MapAnimationOptions(duration: 800),
      );
    } on Exception {
      if (mounted) {
        setState(() {
          _locationFailed = true;
        });
      }
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    final Campaign? focusedCampaign = widget.focusedCampaign;
    if (focusedCampaign != null) {
      await _flyToCampaign(focusedCampaign);
    }

    if (!mounted) {
      return;
    }

    if (_permissionState == LocationPermissionState.granted) {
      if (_userLocation == null) {
        await _locateUser();
      } else {
        await _showUserLocation();
      }
    }
  }

  Widget? _buildLocationNotice() {
    if (_isLocating) {
      return const LocationNotice(
        message: "Obtendo sua localização...",
        isLoading: true,
      );
    }

    if (_locationFailed) {
      return LocationNotice(
        message: "Não foi possível obter sua localização.",
        actionLabel: "Tentar novamente",
        onAction: _handleLocationAction,
      );
    }

    return switch (_permissionState) {
      LocationPermissionState.serviceDisabled => LocationNotice(
        message: "Ative a localização do aparelho para ver sua posição.",
        actionLabel: "Abrir configurações",
        onAction: _handleLocationAction,
      ),
      LocationPermissionState.denied => LocationNotice(
        message: "Permita o acesso à localização para ver sua posição.",
        actionLabel: "Permitir",
        onAction: _handleLocationAction,
      ),
      LocationPermissionState.deniedForever => LocationNotice(
        message: "A localização está bloqueada nas configurações do app.",
        actionLabel: "Abrir configurações",
        onAction: _handleLocationAction,
      ),
      LocationPermissionState.granted || null => null,
    };
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

  // Build ----------------------------------------------------------------- //

  @override
  Widget build(BuildContext context) {
    final Campaign? focusedCampaign = widget.focusedCampaign;

    if (_accessToken.isEmpty) {
      return Stack(
        children: [
          const Center(
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
          ),

          if (focusedCampaign != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,

              child: Center(
                child: _FocusedCampaignChip(
                  campaign: focusedCampaign,
                  onClear: widget.onClearCampaign,
                ),
              ),
            ),
        ],
      );
    }

    final List<CollectionPoint> visiblePoints = _filteredPoints;
    final Widget? locationNotice = _buildLocationNotice();
    final bool hasTopChip =
        focusedCampaign != null || widget.residueFilter != null;

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey("aracaju-map"),
          onMapCreated: _onMapCreated,

          viewport: CameraViewportState(
            center: Point(coordinates: Position(-37.067, -10.95)),
            zoom: 10.7,
          ),
        ),

        if (locationNotice != null)
          Positioned(
            top: hasTopChip ? 80 : 16,
            left: 16,
            right: 16,

            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: locationNotice,
              ),
            ),
          ),

        if (focusedCampaign != null)
          Positioned(
            top: 16,
            left: 16,
            right: 16,

            child: Center(
              child: _FocusedCampaignChip(
                campaign: focusedCampaign,
                onClear: widget.onClearCampaign,
              ),
            ),
          )
        else if (widget.residueFilter != null)
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
                tooltip: "Centralizar na minha localização",
                onPressed: _handleLocationAction,

                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Classes ----------------------------------------------------------------- //

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

class _FocusedCampaignChip extends StatelessWidget {
  const _FocusedCampaignChip({required this.campaign, this.onClear});

  final Campaign campaign;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth - 32),

      child: Material(
        color: EcoColors.surface,
        elevation: 4,
        shadowColor: Colors.black.withAlpha(45),
        borderRadius: BorderRadius.circular(18),

        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),

          child: Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 22,
                color: AppColors.primaryAccessible,
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: EcoColors.textPrimary,
                      ),
                    ),
                    Text(
                      campaign.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: EcoColors.textSecondary,
                      ),
                    ),
                  ],
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
                  tooltip: "Fechar campanha",
                ),
            ],
          ),
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
    ResidueType.electronics => WasteType.electronics,
    null => null,
  };
}
