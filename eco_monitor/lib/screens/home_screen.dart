import "dart:async";

import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";
import "package:provider/provider.dart";

import "../data/app_data_sync.dart";
import "../data/collect_points_repository.dart";
import "../data/waste_search_analytics_repository.dart";
import "../domain/entities/waste_type.dart";
import "../domain/usecases/get_nearest_point_use_case.dart";
import "../models/campaign.dart";
import "../models/collection_point.dart";
import "../presentation/state/favorites_notifier.dart";
import "../services/location_service.dart";
import "../services/mapbox_token_provider.dart";
import "../services/route_service.dart";
import "../theme/app_colors.dart";
import "../utils/geo.dart";
import "../utils/point_filters.dart";
import "../widgets/collect_point_sheet.dart";
import "../widgets/collect_points_layer.dart";
import "../widgets/collect_points_list_view.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/home_map_controls.dart";
import "../widgets/home_map_top_bar.dart";
import "../widgets/location_notice.dart";
import "../widgets/route_summary_card.dart";

part "home_screen_actions.dart";


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

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, _HomeScreenActions {


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

  bool _isSearching = false;

  void _handlePopInvoked(bool didPop, dynamic result) {
    if (didPop) {
      return;
    }
    if (_isSearching) {
      setState(() {
        _isSearching = false;
      });
      FocusScope.of(context).unfocus();
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
    _cancelRouteSubscription();
    _pointsLayer?.dispose();

    final PolylineAnnotationManager? routeManager = _routeManager;
    if (routeManager != null) {
      unawaited(routeManager.deleteAll().catchError((Object _) {}));
    }

    super.dispose();
  }


  // Methods --------------------------------------------------------------- //


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

  double? get _nearestPointDistance {
    final UserLocation? location = _userLocation;
    if (location == null || _points.isEmpty) {
      return null;
    }

    final NearestPointResult? nearest = const GetNearestPointUseCase().execute(
      userLatitude: location.latitude,
      userLongitude: location.longitude,
      points: _points,
      selectedWasteTypes: _selectedWasteTypes,
    );

    return nearest?.distanceMeters;
  }


  // Build ----------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final Campaign? focusedCampaign = widget.focusedCampaign;
    final List<CollectionPoint> visiblePoints = _filteredPoints;
    final Widget? locationNotice = _buildLocationNotice();
    final CollectionPoint? selectedPoint = _selectedPoint;
    final double navInset = CustomBottomNavBar.reservedBottomInset(context);
    final bool isListMode = _isEffectiveListView;
    final bool hideAuxiliaryButtons = _isSearching ||
        (MediaQuery.viewInsetsOf(context).bottom > 0);

    Widget topBar({required bool isListMode}) {
      return HomeMapTopBar(
        selectedWasteTypes: _selectedWasteTypes,
        onFilterChanged: _handleFilterChanged,
        isFavoritesOnly: _isFavoritesOnly,
        onFavoritesToggle: _handleFavoritesToggle,
        focusedCampaign: focusedCampaign,
        onClearCampaign: widget.onClearCampaign,
        showMapboxTokenWarning: _accessToken.isEmpty,
        isLoadingPoints: _isLoadingPoints,
        isEmptyResult: visiblePoints.isEmpty && selectedPoint == null,
        emptyMessage: _isFavoritesOnly
            ? "Nenhum ponto favorito encontrado."
            : (_selectedWasteTypes.isEmpty
                ? "Nenhum ponto de coleta disponível."
                : "Nenhum ponto aceita esse resíduo por perto."),
        locationNotice: locationNotice,
        isListMode: isListMode,
        onQuickNearestPoint: () => unawaited(_handleQuickNearestPoint()),
        nearestDistanceMeters: _nearestPointDistance,
        onResidueSearched: (WasteType type) {
          setState(() {
            _isSearching = false;
          });
          unawaited(_handleResidueSearched(type));
        },
        showQuickAction: selectedPoint == null && !isListMode,
        isSearchActive: _isSearching,
        onSearchActiveChanged: (bool active) {
          if (_isSearching != active && mounted) {
            setState(() {
              _isSearching = active;
            });
          }
        },
      );
    }

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: _handlePopInvoked,

      child: Stack(
        children: [
          // O mapa permanece montado mesmo no modo de lista: a lista é um
          // sobreposição opaca por cima. Remover e recriar a view nativa do mapa
          // (Offstage) deixa a tela em branco sem reiniciar o app.
          if (_accessToken.isNotEmpty)
            Positioned.fill(
              child: MapWidget(
                key: const ValueKey("aracaju-map"),
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: _onStyleLoaded,

                viewport: CameraViewportState(
                  center: Point(coordinates: Position(0, 20)),
                  zoom: 1.5,
                ),
              ),
            ),

          if (_isSearching)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() {
                    _isSearching = false;
                  });
                  FocusScope.of(context).unfocus();
                },
              ),
            ),

          if (isListMode)
            Positioned.fill(
              child: Container(
                color: AppColors.background,

                child: Column(
                  children: [
                    topBar(isListMode: true),

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

              child: topBar(isListMode: false),
            ),

          if (selectedPoint == null && !_isListView && !hideAuxiliaryButtons)
            HomeLocateButton(
              bottom: navInset + 20,
              onPressed: _handleLocationAction,
            ),

          if (selectedPoint == null && _accessToken.isNotEmpty && !hideAuxiliaryButtons)
            HomeViewToggleButton(
              bottom: navInset + 20,
              isListMode: isListMode,
              onPressed: () {
                setState(() {
                  _isListView = !_isListView;
                });
              },
            ),

        if (selectedPoint != null)
          _isRouteActive
              ? Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,

                  child: RouteSummaryCard(
                    point: selectedPoint,
                    summary: _routeSummary,
                    activeTravelMode: _activeTravelMode,
                    onTravelModeChanged: _handleTravelModeChanged,
                    onOpenExternal: _handleOpenExternalNavigation,
                    onClose: () => unawaited(_dismissSelection()),
                  ),
                )
              : Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,

                  child: CollectPointSheet(
                    point: selectedPoint,
                    distanceMeters: _distanceToSelectedPoint,
                    activeFilter: _selectedWasteTypes,
                    isDataStale: widget.dataSync?.isStale ?? false,
                    onCancel: () => unawaited(_dismissSelection()),
                    onStartRoute: () => unawaited(_handleStartRoute()),
                  ),
                ),
        ],
      ),
    );
  }
}
