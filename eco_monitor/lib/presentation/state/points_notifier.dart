import "package:flutter/foundation.dart";

import "../../data/app_data_sync.dart";
import "../../domain/entities/collection_point.dart";
import "../../domain/entities/waste_type.dart";
import "../../domain/repositories/collect_points_repository_contract.dart";
import "../../domain/usecases/filter_points_use_case.dart";
import "../../domain/usecases/get_nearest_point_use_case.dart";


// Notifiers --------------------------------------------------------------- //


/// Gerenciador de estado reativo para os pontos de coleta e filtros (Presentation).
class PointsNotifier extends ChangeNotifier {
  PointsNotifier({
    this.repository,
    AppDataSync? dataSync,
    FilterPointsUseCase? filterUseCase,
    GetNearestPointUseCase? nearestUseCase,
    List<CollectionPoint> initialPoints = const <CollectionPoint>[],
  }) : _dataSync = dataSync,
       _filterUseCase = filterUseCase ?? const FilterPointsUseCase(),
       _nearestUseCase = nearestUseCase ?? const GetNearestPointUseCase(),
       _points = initialPoints.isNotEmpty
           ? initialPoints
           : (dataSync?.points ?? const <CollectionPoint>[]),
       _isLoading =
           initialPoints.isEmpty && (dataSync?.points.isEmpty ?? true) {
    _dataSync?.addListener(_onSyncChanged);
  }

  final ICollectPointsRepository? repository;
  final AppDataSync? _dataSync;
  final FilterPointsUseCase _filterUseCase;
  final GetNearestPointUseCase _nearestUseCase;

  List<CollectionPoint> _points;
  Set<WasteType> _selectedWasteTypes = const <WasteType>{};
  CollectionPoint? _selectedPoint;
  bool _isLoading;
  bool _isListView = false;

  List<CollectionPoint> get points => _points;

  List<CollectionPoint> get filteredPoints => _filterUseCase.execute(
    points: _points,
    selectedWasteTypes: _selectedWasteTypes,
  );

  Set<WasteType> get selectedWasteTypes => _selectedWasteTypes;

  CollectionPoint? get selectedPoint => _selectedPoint;

  bool get isLoading => _isLoading;

  bool get isListView => _isListView;

  bool get isEmpty => filteredPoints.isEmpty && _selectedPoint == null;


  // Methods --------------------------------------------------------------- //


  void _onSyncChanged() {
    final AppDataSync? sync = _dataSync;
    if (sync != null) {
      _points = sync.points;
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dataSync?.removeListener(_onSyncChanged);
    super.dispose();
  }


  /// Atualiza o conjunto de pontos em memória e notifica a árvore de widgets.
  void setPoints(List<CollectionPoint> points) {
    _points = points;
    _isLoading = false;
    notifyListeners();
  }

  /// Carrega os pontos do cache offline via repositório.
  Future<void> loadOffline() async {
    final ICollectPointsRepository? repo = repository;
    if (repo == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = _points.isEmpty;
    notifyListeners();

    try {
      final List<CollectionPoint> offline = await repo.loadOffline();
      _points = offline;
      _isLoading = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atualiza os pontos buscando da fonte remota.
  Future<void> refresh() async {
    final ICollectPointsRepository? repo = repository;
    if (repo == null || !repo.hasRemoteSource) {
      return;
    }

    try {
      final List<CollectionPoint> refreshed = await repo.refresh();
      _points = refreshed;
      notifyListeners();
    } catch (_) {
      // Falhas silenciosas de rede mantêm os dados de cache.
    }
  }

  /// Define o filtro de resíduo único ou limpa caso nulo.
  void setWasteFilter(WasteType? wasteType) {
    _selectedWasteTypes = wasteType == null
        ? const <WasteType>{}
        : <WasteType>{wasteType};
    notifyListeners();
  }

  /// Alterna a presença de um tipo de resíduo no filtro múltiplo.
  void toggleWasteFilter(WasteType type) {
    final Set<WasteType> updated = Set<WasteType>.from(_selectedWasteTypes);
    if (updated.contains(type)) {
      updated.remove(type);
    } else {
      updated.add(type);
    }
    _selectedWasteTypes = Set<WasteType>.unmodifiable(updated);
    notifyListeners();
  }

  /// Limpa todos os filtros de resíduos aplicados.
  void clearWasteFilter() {
    if (_selectedWasteTypes.isNotEmpty) {
      _selectedWasteTypes = const <WasteType>{};
      notifyListeners();
    }
  }

  /// Define o ponto atualmente selecionado para inspeção no mapa/card.
  void selectPoint(CollectionPoint? point) {
    if (_selectedPoint != point) {
      _selectedPoint = point;
      notifyListeners();
    }
  }

  /// Alterna entre modo mapa e modo lista.
  void toggleListView() {
    _isListView = !_isListView;
    notifyListeners();
  }

  /// Define explicitamente a exibição em modo lista ou mapa.
  void setListView(bool isListView) {
    if (_isListView != isListView) {
      _isListView = isListView;
      notifyListeners();
    }
  }

  /// Encontra o ecoponto ativo mais próximo utilizando o caso de uso.
  NearestPointResult? findNearestPoint({
    required double latitude,
    required double longitude,
    double? maxDistanceMeters,
  }) {
    return _nearestUseCase.execute(
      userLatitude: latitude,
      userLongitude: longitude,
      points: _points,
      selectedWasteTypes: _selectedWasteTypes,
      maxDistanceMeters: maxDistanceMeters,
    );
  }
}
