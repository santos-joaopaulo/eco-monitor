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
import "../utils/point_filters.dart";
import "../widgets/collect_points_layer.dart";
import "../widgets/filter_bar.dart";
import "../widgets/location_notice.dart";

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
    this.isActive = true,
  });

  /// Residue type received from the guide tab; starts the map filter.
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

  /// Whether the map tab is currently visible.
  final bool isActive;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _accessToken = String.fromEnvironment("ACCESS_TOKEN");
  static const double _userZoom = 14;

  MapboxMap? _mapboxMap;
  CollectPointsLayer? _pointsLayer;

  List<CollectionPoint> _points = const <CollectionPoint>[];
  Set<WasteType> _selectedWasteTypes = const <WasteType>{};
  CollectionPoint? _selectedPoint;
  bool _isLoadingPoints = true;

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
    _selectedWasteTypes = _selectionForResidue(widget.residueFilter);
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

    if (oldWidget.residueFilter != widget.residueFilter) {
      _applyWasteSelection(_selectionForResidue(widget.residueFilter));
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
    _pointsLayer?.dispose();
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
      _isLoadingPoints = false;
    });
    _syncPointsLayer();
  }

  Future<void> _loadInitialPoints() async {
    final AppDataSync? sync = widget.dataSync;
    if (sync != null) {
      setState(() {
        _points = sync.points;
        _isLoadingPoints = false;
      });
      _syncPointsLayer();
      return;
    }

    final CollectPointsRepository? repository = widget.repository;
    if (repository == null) {
      if (mounted) {
        setState(() {
          _isLoadingPoints = false;
        });
      }
      return;
    }

    final List<CollectionPoint> offline = await repository.loadOffline();
    if (!mounted) {
      return;
    }

    setState(() {
      _points = offline;
      _isLoadingPoints = false;
    });
    _syncPointsLayer();

    if (repository.hasRemoteSource) {
      final List<CollectionPoint> refreshed = await repository.refresh();
      if (mounted) {
        setState(() {
          _points = refreshed;
        });
        _syncPointsLayer();
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

    final CollectPointsLayer? layer = await CollectPointsLayer.create(
      mapboxMap: mapboxMap,
      onPointSelected: _handlePointSelected,
    );

    if (!mounted) {
      layer?.dispose();
      return;
    }

    _pointsLayer = layer;
    layer?.update(_filteredPoints, selectedId: _selectedPoint?.id);

    final Campaign? focusedCampaign = widget.focusedCampaign;
    if (focusedCampaign != null) {
      await _flyToCampaign(focusedCampaign);
    }

    if (_permissionState == LocationPermissionState.granted) {
      if (_userLocation == null) {
        await _locateUser();
      } else {
        await _showUserLocation();
      }
    }
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData event) async {
    final MapboxMap? map = _mapboxMap;
    if (map != null) {
      await CollectPointsLayer.hideDefaultPois(map);
    }
  }

  void _handlePointSelected(CollectionPoint point) {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPoint = point;
    });
    _syncPointsLayer();
  }

  void _handleFilterChanged(Set<WasteType> selection) {
    final bool clearingGuideFilter =
        selection.isEmpty && widget.residueFilter != null;

    _applyWasteSelection(selection);

    if (clearingGuideFilter) {
      widget.onClearFilter?.call();
    }
  }

  void _applyWasteSelection(Set<WasteType> selection) {
    final CollectionPoint? point = _selectedPoint;
    final bool hideSelection = point != null && !point.acceptsAny(selection);

    setState(() {
      _selectedWasteTypes = Set<WasteType>.unmodifiable(selection);

      if (hideSelection) {
        _selectedPoint = null;
      }
    });

    _syncPointsLayer();
  }

  void _syncPointsLayer() {
    final CollectPointsLayer? layer = _pointsLayer;
    if (layer == null) {
      return;
    }

    layer.update(_filteredPoints, selectedId: _selectedPoint?.id);
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

  Set<WasteType> _selectionForResidue(ResidueType? residue) {
    final WasteType? type = _wasteTypeFor(residue);
    if (type == null) {
      return const <WasteType>{};
    }

    return <WasteType>{type};
  }

  List<CollectionPoint> get _filteredPoints {
    return filterCollectionPoints(_points, _selectedWasteTypes);
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

    return Stack(
      children: [
        MapWidget(
          key: const ValueKey("aracaju-map"),
          onMapCreated: _onMapCreated,
          onStyleLoadedListener: _onStyleLoaded,

          viewport: CameraViewportState(
            center: Point(coordinates: Position(-37.067, -10.95)),
            zoom: 10.7,
          ),
        ),

        Positioned(
          top: 0,
          left: 0,
          right: 0,

          child: SafeArea(
            bottom: false,

            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (focusedCampaign != null) ...[
                    _FocusedCampaignChip(
                      campaign: focusedCampaign,
                      onClear: widget.onClearCampaign,
                    ),
                    const SizedBox(height: 8),
                  ],

                  FilterBar(
                    selectedTypes: _selectedWasteTypes,
                    visibleCount: visiblePoints.length,
                    onChanged: _handleFilterChanged,
                  ),

                  if (_isLoadingPoints) ...[
                    const SizedBox(height: 8),
                    const _MapStatusPill(
                      message: "Carregando pontos...",
                      isLoading: true,
                    ),
                  ] else if (visiblePoints.isEmpty) ...[
                    const SizedBox(height: 8),

                    _MapStatusPill(
                      message: _selectedWasteTypes.isEmpty
                          ? "Nenhum ponto de coleta disponível."
                          : "Nenhum ponto aceita esse resíduo por perto.",
                      icon: Icons.location_off_outlined,
                    ),
                  ],

                  if (locationNotice != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: locationNotice,
                      ),
                    ),
                  ],
                ],
              ),
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

class _MapStatusPill extends StatelessWidget {
  const _MapStatusPill({
    required this.message,
    this.icon,
    this.isLoading = false,
  });

  final String message;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface.withValues(alpha: 0.95),
      elevation: 2,
      shadowColor: Colors.black.withAlpha(30),
      borderRadius: BorderRadius.circular(20),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                icon ?? Icons.info_outline,
                size: 18,
                color: AppColors.textSecondary,
              ),

            const SizedBox(width: 8),

            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
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
    ResidueType.electronics => WasteType.electronics,
    null => null,
  };
}
