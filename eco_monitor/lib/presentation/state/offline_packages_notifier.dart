import "dart:async";

import "package:flutter/foundation.dart";

import "../../domain/entities/offline_package.dart";
import "../../services/location_service.dart";
import "../../services/offline_package_manager.dart";


// Notifier ----------------------------------------------------------------- //


/// Gerenciador reativo de estado dos pacotes de mapas e rotas offline (T14.3).
class OfflinePackagesNotifier extends ChangeNotifier {
  OfflinePackagesNotifier({
    required this.packageManager,
    UserLocation? initialLocation,
  }) : _userLocation = initialLocation;

  final IOfflinePackageManager packageManager;

  List<OfflinePackage> _packages = const <OfflinePackage>[];
  bool _isLoading = false;
  int _totalStorageBytes = 0;
  String _searchQuery = "";
  String? _selectedRegion;
  UserLocation? _userLocation;

  final Map<String, StreamSubscription<OfflinePackageProgress>> _subscriptions =
      <String, StreamSubscription<OfflinePackageProgress>>{};

  List<OfflinePackage> get packages => _packages;
  bool get isLoading => _isLoading;
  int get totalStorageBytes => _totalStorageBytes;
  String get searchQuery => _searchQuery;
  String? get selectedRegion => _selectedRegion;
  UserLocation? get userLocation => _userLocation;

  /// Retorna se há pacotes adicionais instalados além do pacote embutido de Sergipe.
  bool get hasExtraPackages => _packages.any(
        (OfflinePackage pkg) => pkg.isDownloaded && !pkg.isBuiltIn,
      );

  /// Retorna a lista de pacotes filtrada pela busca textual e pela região selecionada.
  List<OfflinePackage> get filteredPackages {
    return _packages.where((OfflinePackage pkg) {
      if (_selectedRegion != null &&
          _selectedRegion != "Todos" &&
          _selectedRegion!.isNotEmpty) {
        if (pkg.region.toLowerCase() != _selectedRegion!.toLowerCase()) {
          return false;
        }
      }

      if (_searchQuery.isNotEmpty) {
        final String query = _searchQuery.toLowerCase();
        final bool matchesName = pkg.name.toLowerCase().contains(query);
        final bool matchesCode = pkg.stateCode.toLowerCase().contains(query);
        if (!matchesName && !matchesCode) {
          return false;
        }
      }

      return true;
    }).toList(growable: false);
  }

  /// Identifica o pacote sugerido para o usuário com base na sua coordenada geográfica.
  OfflinePackage? get suggestedPackage {
    final UserLocation? loc = _userLocation;
    if (loc == null) {
      return null;
    }

    for (final OfflinePackage pkg in _packages) {
      if (pkg.containsCoordinate(loc.latitude, loc.longitude)) {
        return pkg;
      }
    }
    return null;
  }


// Methods ------------------------------------------------------------------ //


  /// Carrega o catálogo de pacotes e o total de armazenamento ocupado.
  Future<void> loadPackages() async {
    _isLoading = true;
    notifyListeners();

    try {
      _packages = await packageManager.getPackages();
      _totalStorageBytes = await packageManager.getTotalStorageUsedBytes();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Atualiza a localização atual do usuário para refinar o estado sugerido.
  void updateUserLocation(UserLocation? location) {
    if (_userLocation == location) {
      return;
    }
    _userLocation = location;
    notifyListeners();
  }

  /// Define o termo de busca textual.
  void setSearchQuery(String query) {
    final String trimmed = query.trim();
    if (_searchQuery == trimmed) {
      return;
    }
    _searchQuery = trimmed;
    notifyListeners();
  }

  /// Define a região selecionada para filtragem (ou "Todos" / null para todas).
  void setSelectedRegion(String? region) {
    if (_selectedRegion == region) {
      return;
    }
    _selectedRegion = (region == "Todos") ? null : region;
    notifyListeners();
  }

  /// Inicia o download de um pacote e escuta os eventos de progresso reativamente.
  Stream<OfflinePackageProgress> downloadPackage(String packageId) {
    _subscriptions[packageId]?.cancel();

    // Atualiza status otimista no estado local
    _updatePackageInList(
      packageId,
      status: OfflinePackageStatus.downloading,
      progress: 0.0,
    );

    final Stream<OfflinePackageProgress> stream =
        packageManager.downloadPackage(packageId);

    _subscriptions[packageId] = stream.listen(
      (OfflinePackageProgress event) {
        _updatePackageInList(
          packageId,
          status: event.status,
          progress: event.progress,
        );

        if (event.status == OfflinePackageStatus.downloaded) {
          _subscriptions.remove(packageId)?.cancel();
          unawaited(_refreshStorageAndPackages());
        }
      },
      onError: (_) {
        _subscriptions.remove(packageId)?.cancel();
        _updatePackageInList(
          packageId,
          status: OfflinePackageStatus.notDownloaded,
          progress: 0.0,
        );
      },
      cancelOnError: true,
    );

    return stream;
  }

  /// Remove um pacote baixado e atualiza a contagem de armazenamento.
  Future<void> deletePackage(String packageId) async {
    _subscriptions[packageId]?.cancel();
    _subscriptions.remove(packageId);

    await packageManager.deletePackage(packageId);
    await _refreshStorageAndPackages();
  }

  /// Remove todos os pacotes adicionais mantendo exclusivamente o pacote embutido de Sergipe.
  Future<void> clearExtraPackages() async {
    for (final OfflinePackage pkg in _packages) {
      if (pkg.isDownloaded && !pkg.isBuiltIn) {
        await packageManager.deletePackage(pkg.id);
      }
    }
    await _refreshStorageAndPackages();
  }

  void _updatePackageInList(
    String packageId, {
    required OfflinePackageStatus status,
    required double progress,
  }) {
    _packages = _packages.map((OfflinePackage p) {
      if (p.id == packageId) {
        return p.copyWith(status: status, downloadProgress: progress);
      }
      return p;
    }).toList(growable: false);

    _totalStorageBytes = _packages
        .where((OfflinePackage p) => p.isDownloaded)
        .fold(0, (int sum, OfflinePackage p) => sum + p.sizeBytes);

    notifyListeners();
  }

  Future<void> _refreshStorageAndPackages() async {
    _packages = await packageManager.getPackages();
    _totalStorageBytes = await packageManager.getTotalStorageUsedBytes();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final StreamSubscription<OfflinePackageProgress> sub
        in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
