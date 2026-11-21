part of "home_screen.dart";


// Constants --------------------------------------------------------------- //


const String _accessToken = String.fromEnvironment("ACCESS_TOKEN");
const double _userZoom = 14;


// Actions ----------------------------------------------------------------- //


/// Ciclo de mapa, localização, sincronização e rota do [HomeScreen].
///
/// Mantido como mixin privado para separar a lógica do mapa da composição
/// visual, sem expor esses detalhes fora da biblioteca da tela.
mixin _HomeScreenActions on State<HomeScreen> {
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

  List<CollectionPoint> get _filteredPoints {
    return filterCollectionPoints(_points, _selectedWasteTypes);
  }

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
}
