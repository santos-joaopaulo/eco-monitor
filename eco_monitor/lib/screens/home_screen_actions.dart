part of "home_screen.dart";


// Constants ---------------------------------------------------------------- //


const double _userZoom = 14;


// Actions ------------------------------------------------------------------ //


/// Ciclo de mapa, localização, sincronização e rota do [HomeScreen].
///
/// Mantido como mixin privado para separar a lógica do mapa da composição
/// visual, sem expor esses detalhes fora da biblioteca da tela.
mixin _HomeScreenActions on State<HomeScreen> {
  late final RouteService _routeService =
      widget.routeService ?? RouteService(cacheStore: widget.routeCacheStore);

  MapboxMap? _mapboxMap;
  CollectPointsLayer? _pointsLayer;
  PolylineAnnotationManager? _routeManager;
  PointAnnotationManager? _campaignAnnotationManager;
  Cancelable? _campaignTapSubscription;
  PointAnnotation? _campaignAnnotation;

  List<CollectionPoint> _points = const <CollectionPoint>[];
  Set<WasteType> _selectedWasteTypes = const <WasteType>{};
  CollectionPoint? _selectedPoint;
  RouteSummary? _routeSummary;
  TravelMode _activeTravelMode = TravelMode.walking;
  StreamSubscription<UserLocation>? _routePositionSubscription;
  bool _isRouteActive = false;
  bool _isLoadingPoints = true;

  LocationPermissionState? _permissionState;
  UserLocation? _userLocation;
  bool _isLocating = false;
  bool _locationFailed = false;
  bool _isListView = false;
  bool _isFavoritesOnly = false;
  ProximityRadius _selectedRadius = ProximityRadius.fiveKm;
  final CollectionPointSpatialIndex _spatialIndex =
      CollectionPointSpatialIndex();

  /// Token do Mapbox resolvido na inicialização (main.dart).
  String get _accessToken => MapboxTokenProvider.token;

  bool get _isEffectiveListView => _isListView || _accessToken.isEmpty;

  List<CollectionPoint> get _filteredPoints {
    Set<String> favIds = const <String>{};
    if (mounted) {
      try {
        favIds = Provider.of<FavoritesNotifier>(
          context,
          listen: false,
        ).favoriteIds;
      } catch (_) {
        favIds = const <String>{};
      }
    }
    final List<CollectionPoint> base = filterCollectionPoints(
      _points,
      _selectedWasteTypes,
      onlyFavorites: _isFavoritesOnly,
      favoriteIds: favIds,
    );

    final UserLocation? location = _userLocation;
    final double? radiusMeters = _selectedRadius.meters;

    // Se não há coordenadas de GPS ou o raio é irrestrito, retorna o conjunto base
    if (location == null || radiusMeters == null) {
      return base;
    }

    // Consulta espacial otimizada em O(log n) via SpatialIndex (T11.1)
    _spatialIndex.load(base);
    return _spatialIndex.queryRadius(
      latitude: location.latitude,
      longitude: location.longitude,
      radiusMeters: radiusMeters,
    );
  }

  bool get _isRadiusEmpty {
    final UserLocation? location = _userLocation;
    final double? radiusMeters = _selectedRadius.meters;
    if (location == null || radiusMeters == null) {
      return false;
    }

    Set<String> favIds = const <String>{};
    if (mounted) {
      try {
        favIds = Provider.of<FavoritesNotifier>(
          context,
          listen: false,
        ).favoriteIds;
      } catch (_) {
        favIds = const <String>{};
      }
    }
    final List<CollectionPoint> base = filterCollectionPoints(
      _points,
      _selectedWasteTypes,
      onlyFavorites: _isFavoritesOnly,
      favoriteIds: favIds,
    );

    return base.isNotEmpty && _filteredPoints.isEmpty;
  }

  void _handleRadiusChanged(ProximityRadius nextRadius) {
    setState(() {
      _selectedRadius = nextRadius;
    });
    _syncPointsLayer();
  }

  void _handleExpandRadius() {
    setState(() {
      _selectedRadius = _selectedRadius.expandNext;
    });
    _syncPointsLayer();
  }

  void _handleFavoritesToggle() {
    setState(() {
      _isFavoritesOnly = !_isFavoritesOnly;
    });
    _syncPointsLayer();
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
        zoom: 15.5,
      ),
      MapAnimationOptions(duration: 800),
    );

    await _plotCampaignPin(campaign);
  }

  Future<void> _plotCampaignPin(Campaign campaign) async {
    final MapboxMap? map = _mapboxMap;
    if (map == null || kIsWeb) {
      return;
    }

    try {
      if (_campaignAnnotationManager == null) {
        final PointAnnotationManager manager =
            await map.annotations.createPointAnnotationManager();
        await manager.setIconAllowOverlap(true);
        await manager.setIconIgnorePlacement(true);
        _campaignTapSubscription = manager.tapEvents(
          onTap: (PointAnnotation annotation) {
            _handleCampaignPinTapped(campaign);
          },
        );
        _campaignAnnotationManager = manager;
      }

      final PointAnnotationManager? manager = _campaignAnnotationManager;
      if (manager == null) {
        return;
      }

      if (_campaignAnnotation != null) {
        try {
          await manager.delete(_campaignAnnotation!);
        } catch (_) {}
        _campaignAnnotation = null;
      }

      final Uint8List pinBytes = await PointPin.renderCampaign();
      _campaignAnnotation = await manager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(campaign.longitude, campaign.latitude),
          ),
          image: pinBytes,
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: 1.0,
          symbolSortKey: 300,
        ),
      );
    } catch (_) {
      // Silencia falhas no mapa mantendo a interface reativa.
    }
  }

  void _handleCampaignPinTapped(Campaign campaign) {
    unawaited(
      showCampaignDetailsSheet(
        context: context,
        campaign: campaign,
        onViewLocation: () {
          // O mapa já se encontra focado na localização desta campanha.
        },
      ),
    );
  }

  Future<void> _clearCampaignMarker() async {
    final PointAnnotation? annotation = _campaignAnnotation;
    final PointAnnotationManager? manager = _campaignAnnotationManager;
    if (annotation != null && manager != null) {
      try {
        await manager.delete(annotation);
      } catch (_) {}
      _campaignAnnotation = null;
    }
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

    if (sync.isOnline && (_routeSummary?.isOfflineFallback ?? false)) {
      final CollectionPoint? point = _selectedPoint;
      if (point != null) {
        unawaited(_refreshActiveRouteOnline(point));
      }
    }
  }

  Future<void> _refreshActiveRouteOnline(CollectionPoint point) async {
    final UserLocation? userLocation = _userLocation;
    if (userLocation == null || !mounted) {
      return;
    }

    final RouteSummary summary = await _routeService.fetchRoute(
      origin: userLocation,
      destination: point,
      travelMode: _activeTravelMode,
      isOnline: true,
      accessToken: _accessToken,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _routeSummary = summary;
    });

    await _drawRouteLine(point, coordinates: summary.routeCoordinates);
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
      _permissionState = LocationPermissionState.granted;
    });

    await _showUserLocation(flyCamera: true);
  }

  Future<void> _showUserLocation({bool flyCamera = true}) async {
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

      if (flyCamera) {
        await mapboxMap.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(location.longitude, location.latitude),
            ),
            zoom: _userZoom,
          ),
          MapAnimationOptions(duration: 800),
        );
      }
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

    _cancelRouteSubscription();
    await _clearRouteLine();
    if (!mounted) {
      return;
    }

    setState(() {
      _isListView = false;
      _selectedPoint = point;
      _routeSummary = null;
      _isRouteActive = false;
    });
    widget.onListViewChanged?.call(false);
    widget.onActiveSheetChanged?.call(true);
    _syncPointsLayer();

    await _focusPoint(point);

    if (_userLocation == null) {
      unawaited(_fetchLocationForDistance());
    }
  }

  Future<void> _fetchLocationForDistance() async {
    try {
      final LocationPermissionState permission = await widget.locationService
          .currentPermission();
      if (permission == LocationPermissionState.granted) {
        final UserLocation? loc = await widget.locationService
            .currentPosition();
        if (loc != null && mounted) {
          setState(() {
            _userLocation = loc;
          });
        }
      }
    } catch (_) {}
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

  void _cancelRouteSubscription() {
    _routePositionSubscription?.cancel();
    _routePositionSubscription = null;
  }

  Future<void> _dismissSelection() async {
    if (!mounted) {
      return;
    }

    _cancelRouteSubscription();
    setState(() {
      _selectedPoint = null;
      _routeSummary = null;
      _isRouteActive = false;
    });
    widget.onActiveSheetChanged?.call(false);
    _syncPointsLayer();
    await _clearRouteLine();
    await _clearCampaignMarker();
  }

  Future<void> _handleStartRoute() async {
    final CollectionPoint? point = _selectedPoint;
    if (point == null) {
      return;
    }

    if (_userLocation == null) {
      await _locateUser();
    }

    final UserLocation? userLocation = _userLocation;
    final bool isOnline = widget.dataSync?.isOnline ?? true;

    final RouteSummary summary;
    if (userLocation != null) {
      summary = await _routeService.fetchRoute(
        origin: userLocation,
        destination: point,
        travelMode: _activeTravelMode,
        isOnline: isOnline,
        accessToken: _accessToken,
      );
    } else {
      summary = RouteSummary(
        distanceMeters: 0,
        estimatedMinutes: 0,
        travelMode: _activeTravelMode,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isRouteActive = true;
      _routeSummary = summary;
    });

    await _drawRouteLine(point, coordinates: summary.routeCoordinates);
    _startRouteTracking(point);

    if (!isOnline && userLocation != null) {
      await _checkAndWarnOutOfCoverage(userLocation, point);
    }
  }

  Future<void> _checkAndWarnOutOfCoverage(
    UserLocation origin,
    CollectionPoint destination,
  ) async {
    final OfflinePackageManager manager = OfflinePackageManager.instance;
    final bool originCovered =
        await manager.hasCoverage(origin.latitude, origin.longitude);
    final bool destCovered =
        await manager.hasCoverage(destination.latitude, destination.longitude);

    if (!originCovered || !destCovered) {
      final OfflinePackage? targetPackage = manager.findPackageForCoordinates(
            destination.latitude,
            destination.longitude,
          ) ??
          manager.findPackageForCoordinates(
            origin.latitude,
            origin.longitude,
          );
      final String stateName = targetPackage?.name ?? "seu estado";

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              "Navegação aproximada: pacote de $stateName não instalado.",
            ),
          ),
        );
    }
  }

  void _startRouteTracking(CollectionPoint point) {
    _cancelRouteSubscription();
    _routePositionSubscription = widget.locationService
        .positionStream(distanceFilter: 5)
        .listen(
          (UserLocation newLocation) =>
              _onRoutePositionUpdated(point, newLocation),
          onError: (_) {},
        );
  }

  void _onRoutePositionUpdated(
    CollectionPoint point,
    UserLocation newLocation,
  ) {
    if (!mounted || !_isRouteActive) {
      return;
    }

    setState(() {
      _userLocation = newLocation;
      _routeSummary = _routeService.buildUpdatedSummary(
        newLocation,
        point,
        _activeTravelMode,
        previousSummary: _routeSummary,
      );
    });

    if (_routeSummary?.isOfflineFallback ?? true) {
      unawaited(
        _drawRouteLine(
          point,
          coordinates: _routeSummary?.routeCoordinates,
        ),
      );
    }
  }

  Future<void> _handleTravelModeChanged(TravelMode mode) async {
    final CollectionPoint? point = _selectedPoint;
    final UserLocation? userLocation = _userLocation;
    if (point == null) {
      return;
    }

    setState(() {
      _activeTravelMode = mode;
    });

    if (userLocation != null) {
      final bool isOnline = widget.dataSync?.isOnline ?? true;
      final RouteSummary summary = await _routeService.fetchRoute(
        origin: userLocation,
        destination: point,
        travelMode: mode,
        isOnline: isOnline,
        accessToken: _accessToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routeSummary = summary;
      });

      await _drawRouteLine(point, coordinates: summary.routeCoordinates);

      if (!isOnline) {
        await _checkAndWarnOutOfCoverage(userLocation, point);
      }
    }
  }

  Future<void> _handleOpenExternalNavigation() async {
    final CollectionPoint? point = _selectedPoint;
    if (point == null) {
      return;
    }

    final bool opened = await _routeService.openNavigation(point);
    if (!mounted) {
      return;
    }

    if (!opened) {
      _showMessage("Não foi possível abrir o app de mapas.");
    }
  }

  Future<void> _drawRouteLine(
    CollectionPoint point, {
    List<List<double>>? coordinates,
  }) async {
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

      final List<Position> positions;
      if (coordinates != null && coordinates.length >= 2) {
        positions = coordinates
            .map((List<double> c) => Position(c[0], c[1]))
            .toList();
      } else {
        positions = <Position>[
          Position(userLocation.longitude, userLocation.latitude),
          Position(point.longitude, point.latitude),
        ];
      }

      await manager.deleteAll();
      await manager.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: positions),
          lineColor: AppColors.routeLine.toARGB32(),
          lineWidth: 5.5,
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


// Methods ------------------------------------------------------------------ //


  /// Inicia navegação e traçado de rota diretamente para o local da campanha.
  Future<void> _handleStartRouteToCampaign(Campaign campaign) async {
    final CollectionPoint campaignPoint = CollectionPoint(
      id: "campaign_${campaign.id}",
      name: campaign.title,
      type: PointType.ecoPoint,
      latitude: campaign.latitude,
      longitude: campaign.longitude,
      address: campaign.address.isNotEmpty
          ? campaign.address
          : campaign.locationName,
      acceptedWasteTypes: campaign.wasteTypes,
      hours: "",
      status: PointStatus.active,
    );

    await _handlePointSelected(campaignPoint);
    widget.onClearCampaign?.call();
    await _handleStartRoute();
  }

  void _applyWasteSelection(Set<WasteType> selection) {
    final CollectionPoint? point = _selectedPoint;
    final bool hideSelection = point != null && !point.acceptsAny(selection);

    setState(() {
      _selectedWasteTypes = Set<WasteType>.unmodifiable(selection);

      if (hideSelection) {
        _cancelRouteSubscription();
        _selectedPoint = null;
        _routeSummary = null;
        _isRouteActive = false;
        widget.onActiveSheetChanged?.call(false);
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

  /// Conduz o fluxo rápido "Ponto mais próximo" em 1 toque (T8.1).
  Future<void> _handleQuickNearestPoint() async {
    if (_userLocation == null) {
      await _handleLocationAction();
    }

    final UserLocation? userLocation = _userLocation;
    if (userLocation == null) {
      if (mounted) {
        _showMessage(
          "Permita o acesso à localização para ver o ponto mais próximo.",
        );
      }
      return;
    }

    final NearestPointResult? nearest = const GetNearestPointUseCase().execute(
      userLatitude: userLocation.latitude,
      userLongitude: userLocation.longitude,
      points: _points,
      selectedWasteTypes: _selectedWasteTypes,
    );

    if (nearest == null) {
      if (mounted) {
        _showMessage("Nenhum ponto de coleta ativo encontrado por perto.");
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isListView = false;
      _selectedPoint = nearest.point;
      _routeSummary = null;
      _isRouteActive = false;
    });
    widget.onListViewChanged?.call(false);
    widget.onActiveSheetChanged?.call(true);
    _syncPointsLayer();

    await _focusPoint(nearest.point);
    await _handleStartRoute();
  }

  Future<void> _recordAnalyticsSearch(
    IWasteSearchAnalyticsRepository analytics,
    WasteType type,
    String? stateCode,
  ) async {
    final int pendingBefore = await analytics.pendingCount();
    await analytics.recordSearch(type, stateCode: stateCode);
    final int pendingAfter = await analytics.pendingCount();
    if (pendingAfter > pendingBefore && mounted) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(kOfflineQueuedMessage),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  /// Aplica busca textual rápida de resíduo e foca o ecoponto compatível mais próximo (T8.2).
  Future<void> _handleResidueSearched(WasteType type) async {
    _handleFilterChanged(<WasteType>{type});

    final UserLocation? userLocation = _userLocation;
    final String? stateCode = userLocation != null
        ? BrazilStates.findCodeByCoordinates(
            userLocation.latitude,
            userLocation.longitude,
          )
        : null;
    final IWasteSearchAnalyticsRepository analytics =
        widget.dataSync?.analyticsRepository ??
        WasteSearchAnalyticsRepository();
    unawaited(_recordAnalyticsSearch(analytics, type, stateCode));

    if (userLocation != null) {
      final NearestPointResult? nearest = const GetNearestPointUseCase()
          .execute(
            userLatitude: userLocation.latitude,
            userLongitude: userLocation.longitude,
            points: _points,
            selectedWasteTypes: <WasteType>{type},
          );

      if (nearest != null) {
        await _handlePointSelected(nearest.point);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }
}
