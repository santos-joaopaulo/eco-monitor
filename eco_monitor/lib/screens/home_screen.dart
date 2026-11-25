import "dart:async";

import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:mapbox_maps_flutter/mapbox_maps_flutter.dart";
import "package:provider/provider.dart";

import "../data/app_data_sync.dart";
import "../data/collect_points_repository.dart";
import "../data/route_cache_store.dart";
import "../data/waste_search_analytics_repository.dart";
import "../domain/entities/brazil_state.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/waste_search_analytics_repository_contract.dart";
import "../domain/usecases/get_nearest_point_use_case.dart";
import "../domain/entities/campaign.dart";
import "../domain/entities/collection_point.dart";
import "../domain/entities/offline_package.dart";
import "../presentation/state/favorites_notifier.dart";
import "../services/location_service.dart";
import "../services/mapbox_token_provider.dart";
import "../services/offline_package_manager.dart";
import "../services/route_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "../utils/geo.dart";
import "../utils/point_filters.dart";
import "../utils/spatial_index.dart";
import "../widgets/campaign_details_sheet.dart";
import "../widgets/collect_point_sheet.dart";
import "../widgets/collect_points_layer.dart";
import "../widgets/collect_points_list_view.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/focused_campaign_sheet.dart";
import "../widgets/home_map_controls.dart";
import "../widgets/home_map_top_bar.dart";
import "../widgets/location_notice.dart";
import "../widgets/point_pin.dart";
import "../widgets/route_summary_card.dart";

part "home_screen_actions.dart";


// Home screen -------------------------------------------------------------- //


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
    this.onActiveSheetChanged,
    this.routeService,
    this.routeCacheStore,
    this.isSearchActive,
    this.onSearchActiveChanged,
    this.onListViewChanged,
    this.offlineBanner,
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

  /// Notifica quando um Bottom Sheet (detalhes do ponto, campanha ou rota) está ativo,
  /// permitindo que a barra de navegação seja sobreposta por completo.
  final ValueChanged<bool>? onActiveSheetChanged;

  /// Serviço de rotas viárias e navegação (RF04, RF05, T11.3).
  final RouteService? routeService;

  /// Armazenamento em cache LRU de rotas viárias offline (T11.3).
  final RouteCacheStore? routeCacheStore;

  /// Controla externamente se a busca textual rápida está aberta (expandida).
  final bool? isSearchActive;

  /// Notifica externamente quando o estado de busca é alterado.
  final ValueChanged<bool>? onSearchActiveChanged;

  /// Notifica externamente quando a lista de ecopontos é aberta ou fechada.
  final ValueChanged<bool>? onListViewChanged;

  /// Banner flutuante de status offline/sincronização exibido sem fundo sobre o mapa.
  final Widget? offlineBanner;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, _HomeScreenActions {


// Init --------------------------------------------------------------------- //


  bool _isSearching = false;

  void _setSearching(bool active) {
    if (_isSearching != active && mounted) {
      setState(() {
        _isSearching = active;
      });
      widget.onSearchActiveChanged?.call(active);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.dataSync?.addListener(_onSyncUpdated);
    _selectedWasteTypes = _selectionFor(widget.wasteFilter);
    _isSearching = widget.isSearchActive ?? false;
    _loadInitialPoints();
    unawaited(_checkLocationAvailability());

    if (widget.focusedCampaign != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focusedCampaign != null) {
          widget.onActiveSheetChanged?.call(true);
        }
      });
    }
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

    if (widget.isSearchActive != null &&
        widget.isSearchActive != oldWidget.isSearchActive &&
        widget.isSearchActive != _isSearching) {
      setState(() {
        _isSearching = widget.isSearchActive!;
      });
    }

    final Campaign? nextCampaign = widget.focusedCampaign;
    if (nextCampaign != null && nextCampaign != oldWidget.focusedCampaign) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focusedCampaign != null) {
          widget.onActiveSheetChanged?.call(true);
        }
      });
      unawaited(_flyToCampaign(nextCampaign));
    } else if (oldWidget.focusedCampaign != null &&
        nextCampaign == null &&
        _selectedPoint == null) {
      unawaited(_clearCampaignMarker());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.focusedCampaign == null &&
            _selectedPoint == null) {
          widget.onActiveSheetChanged?.call(false);
        }
      });
    }
  }

  void _handlePopInvoked(bool didPop, dynamic result) {
    if (didPop) {
      return;
    }
    if (_isSearching) {
      _setSearching(false);
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkLocationAvailability());
      unawaited(widget.dataSync?.connectivityService.checkNow());
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

    _campaignTapSubscription?.cancel();
    final PointAnnotationManager? campaignManager = _campaignAnnotationManager;
    if (campaignManager != null) {
      unawaited(campaignManager.deleteAll().catchError((Object _) {}));
    }

    super.dispose();
  }


// Methods ------------------------------------------------------------------ //


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


// Build -------------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final Campaign? focusedCampaign = widget.focusedCampaign;
    final List<CollectionPoint> visiblePoints = _filteredPoints;
    final Widget? locationNotice = _buildLocationNotice();
    final CollectionPoint? selectedPoint = _selectedPoint;
    final double navInset = CustomBottomNavBar.reservedBottomInset(context);
    final bool isListMode = _isEffectiveListView;
    final bool hideAuxiliaryButtons =
        _isSearching || (MediaQuery.viewInsetsOf(context).bottom > 0);

    final bool isNeutralState =
        selectedPoint == null &&
        focusedCampaign == null &&
        !_isListView &&
        !hideAuxiliaryButtons;

    Widget topBar({required bool isListMode}) {
      return HomeMapTopBar(
        selectedWasteTypes: _selectedWasteTypes,
        onFilterChanged: _handleFilterChanged,
        isFavoritesOnly: _isFavoritesOnly,
        onFavoritesToggle: _handleFavoritesToggle,
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
        selectedRadius: _selectedRadius,
        onRadiusChanged: _handleRadiusChanged,
        isRadiusEmpty: _isRadiusEmpty,
        onExpandRadius: _handleExpandRadius,
        offlineBanner: widget.offlineBanner,
      );
    }

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: _handlePopInvoked,

      child: Stack(
        children: [
          // O mapa permanece montado mesmo no modo de lista: a lista é uma
          // sobreposição opaca por cima. Remover e recriar a view nativa do mapa
          // (Offstage) deixa a tela em branco sem reiniciar o app.
          if (_accessToken.isNotEmpty)
            Positioned.fill(
              key: const ValueKey("home-map-layer"),
              child: MapWidget(
                key: const ValueKey("aracaju-map"),
                onMapCreated: _onMapCreated,
                onStyleLoadedListener: _onStyleLoaded,
                onCameraChangeListener: (CameraChangedEventData event) {
                  _pointsLayer?.updateCameraZoom(event.cameraState.zoom);
                },

                viewport: CameraViewportState(
                  center: Point(coordinates: Position(0, 20)),
                  zoom: 1.5,
                ),
              ),
            ),

          if (isListMode)
            Positioned.fill(
              key: const ValueKey("home-list-layer"),
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
              key: const ValueKey("home-top-bar-layer"),
              top: 0,
              left: 0,
              right: 0,

              child: topBar(isListMode: false),
            ),

          // Botões flutuantes inferiores no estado neutro (modo mapa)
          if (isNeutralState) ...[
            HomeSearchButton(
              bottom: navInset + 20,
              onPressed: () => _setSearching(true),
            ),

            HomeLocateButton(
              bottom: navInset + 20,
              distanceMeters: _nearestPointDistance,
              tooltip: _nearestPointDistance != null
                  ? "Ponto mais próximo (${formatDistance(_nearestPointDistance!)}) · Traçar rota"
                  : "Centralizar na minha localização",
              onPressed: () => unawaited(_handleQuickNearestPoint()),
            ),
          ],

          // Botão flutuante para alternar entre Mapa e Lista (visível tanto no mapa quanto na lista)
          if (selectedPoint == null &&
              focusedCampaign == null &&
              !hideAuxiliaryButtons &&
              _accessToken.isNotEmpty)
            HomeViewToggleButton(
              bottom: navInset + 20,
              isListMode: isListMode,
              onPressed: () {
                final bool next = !_isListView;
                setState(() {
                  _isListView = next;
                });
                widget.onListViewChanged?.call(next);
              },
            ),

          // Campanha focada exibida no padrão bottom sheet (RF09)
          if (focusedCampaign != null && selectedPoint == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,

              child: FocusedCampaignSheet(
                campaign: focusedCampaign,
                locationService: widget.locationService,
                distanceMeters: _userLocation != null
                    ? distanceInMeters(
                        _userLocation!.latitude,
                        _userLocation!.longitude,
                        focusedCampaign.latitude,
                        focusedCampaign.longitude,
                      )
                    : null,
                onClearCampaign: () {
                  unawaited(_clearCampaignMarker());
                  widget.onActiveSheetChanged?.call(false);
                  widget.onClearCampaign?.call();
                },
                onStartRoute: () =>
                    unawaited(_handleStartRouteToCampaign(focusedCampaign)),
              ),
            ),

          // Detalhes do ponto selecionado ou resumo da rota
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

          // Camada de busca expansível sobre o mapa (T8.2)
          if (_isSearching) ...[
            Positioned.fill(
              key: const ValueKey("home-search-backdrop"),

              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _setSearching(false);
                  FocusScope.of(context).unfocus();
                },

                child: Container(color: Colors.black.withAlpha(90)),
              ),
            ),

            Positioned(
              key: const ValueKey("home-search-overlay"),
              top: 0,
              left: 0,
              right: 0,

              child: SafeArea(
                bottom: false,

                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kEcoContentHorizontalPadding,
                    10,
                    kEcoContentHorizontalPadding,
                    0,
                  ),

                  child: HomeSearchBar(
                    autofocus: true,
                    onClose: () => _setSearching(false),
                    onSelectWasteType: (WasteType type) {
                      _setSearching(false);
                      unawaited(_handleResidueSearched(type));
                    },
                    onActiveChanged: (bool active) {
                      if (!active && _isSearching) {
                        _setSearching(false);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
