import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";

import "../data/app_data_sync.dart";
import "../data/collect_points_repository.dart";
import "../domain/entities/waste_type.dart";
import "../models/campaign.dart";
import "../models/collection_point.dart";
import "../services/location_service.dart";
import "../services/route_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/geo.dart";
import "../utils/point_filters.dart";
import "../widgets/collect_point_sheet.dart";
import "../widgets/collect_points_layer.dart";
import "../widgets/collect_points_list_view.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/filter_bar.dart";
import "../widgets/location_notice.dart";
import "../widgets/route_summary_card.dart";


// Home screen ------------------------------------------------------------- //


class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.wasteFilter,
    this.onClearFilter,
    this.focusedCampaign,
    this.onClearCampaign,
    this.repository,
    this.dataSync,
    this.locationService = const LocationService(),
    this.isActive = true,
  });

  /// Tipo de resíduo recebido da aba do guia; inicializa o filtro do mapa.
  final WasteType? wasteFilter;
  final VoidCallback? onClearFilter;

  /// Campanha recebida da aba de eventos para focar no mapa (RF09).
  final Campaign? focusedCampaign;
  final VoidCallback? onClearCampaign;

  /// Repositório offline-first para pontos de coleta (RF05, RNF11).
  final CollectPointsRepository? repository;

  /// Controlador compartilhado de sincronização online/offline injetado da raiz de composição.
  final AppDataSync? dataSync;

  /// Serviço de localização do dispositivo usado para obter e seguir a posição do usuário (RF14).
  final LocationService locationService;

  /// Indica se a aba do mapa está visível no momento.
  final bool isActive;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _accessToken = String.fromEnvironment("ACCESS_TOKEN");
  static const double _userZoom = 14;

  final RouteService _routeService = const RouteService();

  MapboxMap? _mapboxMap;
  CollectPointsLayer? _pointsLayer;
  PolylineAnnotationManager? _routeManager;

  List<CollectionPoint> _points = const <CollectionPoint>[];
  Set<WasteType> _selectedWasteTypes = const <WasteType>{};
  CollectionPoint? _selectedPoint;
  RouteSummary? _routeSummary;
  bool _isRouteActive = false;
  bool _isLoadingPoints = true;

  LocationPermissionState? _permissionState;
  UserLocation? _userLocation;
  bool _isLocating = false;
  bool _locationFailed = false;
  bool _cameraCenteredOnUser = false;
  bool _isListView = false;

  bool get _isEffectiveListView => _isListView || _accessToken.isEmpty;


  // Init ------------------------------------------------------------------ //


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.dataSync?.addListener(_onSyncUpdated);
    _selectedWasteTypes = _selectionFor(widget.wasteFilter);
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

    if (oldWidget.isActive && !widget.isActive) {
      unawaited(_dismissSelection());
    }

    if (oldWidget.wasteFilter != widget.wasteFilter) {
      _applyWasteSelection(_selectionFor(widget.wasteFilter));
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

    final PolylineAnnotationManager? routeManager = _routeManager;
    if (routeManager != null) {
      unawaited(routeManager.deleteAll().catchError((Object _) {}));
    }

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

  Future<void> _handlePointSelected(CollectionPoint point) async {
    if (!mounted) {
      return;
    }

    await _clearRouteLine();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPoint = point;
      _routeSummary = null;
      _isRouteActive = false;
    });
    _syncPointsLayer();

    if (!_isEffectiveListView) {
      await _focusPoint(point);
    }
  }

  Future<void> _focusPoint(CollectionPoint point) async {
    final MapboxMap? map = _mapboxMap;
    if (map == null || !mounted) {
      return;
    }

    final double bottomPadding =
        CustomBottomNavBar.reservedBottomInset(context) + 240;

    await map.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(point.longitude, point.latitude)),
        zoom: 15.5,
        padding: MbxEdgeInsets(
          top: 96,
          left: 24,
          bottom: bottomPadding,
          right: 24,
        ),
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _dismissSelection() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedPoint = null;
      _routeSummary = null;
      _isRouteActive = false;
    });
    _syncPointsLayer();
    await _clearRouteLine();
  }

  Future<void> _handleStartRoute() async {
    final CollectionPoint? point = _selectedPoint;
    if (point == null) {
      return;
    }

    final AppDataSync? sync = widget.dataSync;
    if (sync != null && !sync.isOnline) {
      _showMessage("A rota exige conexão com a internet.");
      return;
    }

    final UserLocation? userLocation = _userLocation;
    final RouteSummary? summary = userLocation == null
        ? null
        : _routeService.buildRouteSummary(userLocation, point);

    setState(() {
      _isRouteActive = true;
      _routeSummary = summary;
    });

    await _drawRouteLine(point);

    final bool opened = await _routeService.openNavigation(point);
    if (!mounted) {
      return;
    }

    if (!opened) {
      _showMessage("Não foi possível abrir o app de mapas.");
    }
  }

  Future<void> _drawRouteLine(CollectionPoint point) async {
    final MapboxMap? map = _mapboxMap;
    final UserLocation? userLocation = _userLocation;

    if (kIsWeb || map == null || userLocation == null) {
      return;
    }

    try {
      _routeManager ??= await map.annotations.createPolylineAnnotationManager();
      final PolylineAnnotationManager? manager = _routeManager;
      if (manager == null) {
        return;
      }

      await manager.deleteAll();
      await manager.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: <Position>[
              Position(userLocation.longitude, userLocation.latitude),
              Position(point.longitude, point.latitude),
            ],
          ),
          lineColor: AppColors.primary.toARGB32(),
          lineWidth: 5,
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 3,
          lineJoin: LineJoin.ROUND,
        ),
      );
    } catch (_) {
      // O painel da rota ainda informa o usuário quando a linha não puder ser desenhada.
    }
  }

  Future<void> _clearRouteLine() async {
    final PolylineAnnotationManager? manager = _routeManager;
    if (manager == null) {
      return;
    }

    try {
      await manager.deleteAll();
    } catch (_) {
      // Nada a limpar quando o mapa não estiver pronto.
    }
  }

  void _handleFilterChanged(Set<WasteType> selection) {
    final bool clearingGuideFilter =
        selection.isEmpty && widget.wasteFilter != null;

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
        _routeSummary = null;
        _isRouteActive = false;
      }
    });

    if (hideSelection) {
      unawaited(_clearRouteLine());
    }

    _syncPointsLayer();
  }

  void _syncPointsLayer() {
    final CollectPointsLayer? layer = _pointsLayer;
    if (layer == null) {
      return;
    }

    layer.update(_filteredPoints, selectedId: _selectedPoint?.id);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  Set<WasteType> _selectionFor(WasteType? waste) {
    if (waste == null) {
      return const <WasteType>{};
    }

    return <WasteType>{waste};
  }

  List<CollectionPoint> get _filteredPoints {
    return filterCollectionPoints(_points, _selectedWasteTypes);
  }

  double? get _distanceToSelectedPoint {
    final CollectionPoint? point = _selectedPoint;
    final UserLocation? location = _userLocation;
    if (point == null || location == null) {
      return null;
    }

    return distanceInMeters(
      location.latitude,
      location.longitude,
      point.latitude,
      point.longitude,
    );
  }


  // Build ----------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final Campaign? focusedCampaign = widget.focusedCampaign;
    final List<CollectionPoint> visiblePoints = _filteredPoints;
    final Widget? locationNotice = _buildLocationNotice();
    final CollectionPoint? selectedPoint = _selectedPoint;
    final double cardBottom =
        CustomBottomNavBar.reservedBottomInset(context) + 8;
    final bool isListMode = _isEffectiveListView;

    return Stack(
      children: [
        if (_accessToken.isNotEmpty)
          Offstage(
            offstage: isListMode,

            child: MapWidget(
              key: const ValueKey("aracaju-map"),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,

              viewport: CameraViewportState(
                center: Point(coordinates: Position(-37.067, -10.95)),
                zoom: 10.7,
              ),
            ),
          ),

        if (isListMode)
          Positioned.fill(
            child: Container(
              color: AppColors.background,

              child: Column(
                children: [
                  _buildTopBar(
                    visiblePoints: visiblePoints,
                    focusedCampaign: focusedCampaign,
                    locationNotice: locationNotice,
                    isListMode: true,
                  ),

                  Expanded(
                    child: CollectPointsListView(
                      points: visiblePoints,
                      userLocation: _userLocation,
                      activeFilter: _selectedWasteTypes,
                      isDataStale: widget.dataSync?.isStale ?? false,
                      onPointSelected: _handlePointSelected,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Positioned(
            top: 0,
            left: 0,
            right: 0,

            child: _buildTopBar(
              visiblePoints: visiblePoints,
              focusedCampaign: focusedCampaign,
              locationNotice: locationNotice,
              isListMode: false,
            ),
          ),

        if (selectedPoint == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: (80 + 32),

            child: Center(
              child: SizedBox(
                width: 72,
                height: 72,

                child: FloatingActionButton(
                  heroTag: "home_locate_fab",
                  backgroundColor: AppColors.primary,
                  shape: const CircleBorder(),
                  tooltip: "Centralizar na minha localização",
                  onPressed: _handleLocationAction,

                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ),
            ),
          ),

        if (selectedPoint == null && _accessToken.isNotEmpty)
          Positioned(
            right: 16,
            bottom: (80 + 32 + 12),

            child: FloatingActionButton(
              heroTag: "home_toggle_view_fab",
              mini: true,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primaryAccessible,
              elevation: 4,
              tooltip: isListMode
                  ? "Visualização em mapa"
                  : "Visualização em lista",
              onPressed: () {
                setState(() {
                  _isListView = !_isListView;
                });
              },

              child: Icon(
                isListMode
                    ? Icons.map_outlined
                    : Icons.view_list_rounded,
                size: 22,
                color: AppColors.primaryAccessible,
              ),
            ),
          ),

        if (selectedPoint != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: cardBottom,

            child: _isRouteActive
                ? RouteSummaryCard(
                    point: selectedPoint,
                    summary: _routeSummary,
                    onClose: () => unawaited(_dismissSelection()),
                  )
                : CollectPointSheet(
                    point: selectedPoint,
                    distanceMeters: _distanceToSelectedPoint,
                    activeFilter: _selectedWasteTypes,
                    isDataStale: widget.dataSync?.isStale ?? false,
                    onCancel: () => unawaited(_dismissSelection()),
                    onStartRoute: () => unawaited(_handleStartRoute()),
                  ),
          ),
      ],
    );
  }

  Widget _buildTopBar({
    required List<CollectionPoint> visiblePoints,
    required Campaign? focusedCampaign,
    required Widget? locationNotice,
    required bool isListMode,
  }) {
    return SafeArea(
      bottom: false,

      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kEcoContentHorizontalPadding,
          12,
          kEcoContentHorizontalPadding,
          0,
        ),

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
              onChanged: _handleFilterChanged,
            ),

            if (_accessToken.isEmpty) ...[
              const SizedBox(height: 8),
              const _MapStatusPill(
                message: "Configure o token do Mapbox",
                icon: Icons.info_outline,
              ),
            ],

            if (_isLoadingPoints) ...[
              const SizedBox(height: 8),
              const _MapStatusPill(
                message: "Carregando pontos...",
                isLoading: true,
              ),
            ] else if (!isListMode &&
                visiblePoints.isEmpty &&
                _selectedPoint == null) ...[
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
                  constraints: const BoxConstraints(
                    maxWidth: kEcoMaxContentWidth,
                  ),
                  child: locationNotice,
                ),
              ),
            ],
          ],
        ),
      ),
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
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

      child: Material(
        color: AppColors.surface,
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      campaign.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
                    color: AppColors.textSecondary,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

      child: Material(
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
      ),
    );
  }
}
