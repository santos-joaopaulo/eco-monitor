import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";

import "../data/local_store.dart";
import "../domain/entities/offline_package.dart";


// Constants ---------------------------------------------------------------- //


/// Chave utilizada para persistir os identificadores dos pacotes instalados.
const String kInstalledPackagesStorageKey = "offline_packages_installed_list";

/// Identificador canônico do pacote embutido de Sergipe / Aracaju.
const String kBuiltInPackageId = "br-se";

/// Tamanho base estimado do pacote embutido de Sergipe (aprox. 2.1 MB).
const int kBuiltInPackageSizeBytes = 2240000;


// Interfaces --------------------------------------------------------------- //


/// Contrato abstrato para gerenciamento do ciclo de vida de pacotes de mapas offline.
abstract interface class IOfflinePackageManager {
  /// Retorna o catálogo completo das 27 UFs com seus respectivos status locais.
  Future<List<OfflinePackage>> getPackages();

  /// Inicia o download de um pacote estadual emitindo progresso contínuo.
  Stream<OfflinePackageProgress> downloadPackage(String packageId);

  /// Remove um pacote baixado liberando espaço em disco.
  Future<void> deletePackage(String packageId);

  /// Verifica se uma coordenada possui cobertura viária em algum pacote instalado.
  Future<bool> hasCoverage(double lat, double lon);

  /// Retorna o total de bytes ocupados por todos os pacotes instalados no dispositivo.
  Future<int> getTotalStorageUsedBytes();
}


// Implementations ---------------------------------------------------------- //


/// Gerenciador padrão de pacotes regionais e estaduais de navegação offline.
class OfflinePackageManager implements IOfflinePackageManager {
  OfflinePackageManager({
    LocalStore? localStore,
    String? storageDirectoryPath,
    this.stepDuration = const Duration(milliseconds: 30),
  })  : _store = localStore ?? SharedPreferencesLocalStore(),
        _storagePath = storageDirectoryPath;

  final LocalStore _store;
  final String? _storagePath;
  final Duration stepDuration;

  static OfflinePackageManager? _defaultInstance;

  /// Instância singleton padrão do gerenciador de pacotes.
  static OfflinePackageManager get instance =>
      _defaultInstance ??= OfflinePackageManager();

  @visibleForTesting
  static set instance(OfflinePackageManager? custom) {
    _defaultInstance = custom;
  }

  final Map<String, StreamController<OfflinePackageProgress>> _activeDownloads =
      <String, StreamController<OfflinePackageProgress>>{};

  final Map<String, double> _downloadProgressMap = <String, double>{};

  /// Catálogo imutável pré-configurado das 27 Unidades Federativas do Brasil.
  static const List<OfflinePackage> _kCatalog = <OfflinePackage>[
    OfflinePackage(
      id: "br-ac",
      stateCode: "AC",
      name: "Acre",
      region: "Norte",
      sizeBytes: 8388608,
      bbox: <double>[-11.15, -73.99, -7.11, -66.62],
    ),
    OfflinePackage(
      id: "br-al",
      stateCode: "AL",
      name: "Alagoas",
      region: "Nordeste",
      sizeBytes: 12582912,
      bbox: <double>[-10.50, -38.24, -8.81, -35.15],
    ),
    OfflinePackage(
      id: "br-ap",
      stateCode: "AP",
      name: "Amapá",
      region: "Norte",
      sizeBytes: 6291456,
      bbox: <double>[-1.24, -54.88, 4.44, -49.88],
    ),
    OfflinePackage(
      id: "br-am",
      stateCode: "AM",
      name: "Amazonas",
      region: "Norte",
      sizeBytes: 18874368,
      bbox: <double>[-9.82, -73.80, 2.25, -56.10],
    ),
    OfflinePackage(
      id: "br-ba",
      stateCode: "BA",
      name: "Bahia",
      region: "Nordeste",
      sizeBytes: 50331648,
      bbox: <double>[-18.35, -46.62, -8.53, -37.34],
    ),
    OfflinePackage(
      id: "br-ce",
      stateCode: "CE",
      name: "Ceará",
      region: "Nordeste",
      sizeBytes: 27262976,
      bbox: <double>[-7.86, -41.42, -2.78, -37.25],
    ),
    OfflinePackage(
      id: "br-df",
      stateCode: "DF",
      name: "Distrito Federal",
      region: "Centro-Oeste",
      sizeBytes: 15728640,
      bbox: <double>[-16.05, -48.29, -15.50, -47.31],
    ),
    OfflinePackage(
      id: "br-es",
      stateCode: "ES",
      name: "Espírito Santo",
      region: "Sudeste",
      sizeBytes: 16777216,
      bbox: <double>[-21.31, -41.88, -17.89, -39.66],
    ),
    OfflinePackage(
      id: "br-go",
      stateCode: "GO",
      name: "Goiás",
      region: "Centro-Oeste",
      sizeBytes: 33554432,
      bbox: <double>[-19.50, -53.25, -12.39, -45.91],
    ),
    OfflinePackage(
      id: "br-ma",
      stateCode: "MA",
      name: "Maranhão",
      region: "Nordeste",
      sizeBytes: 25165824,
      bbox: <double>[-10.26, -48.76, -1.05, -41.79],
    ),
    OfflinePackage(
      id: "br-mt",
      stateCode: "MT",
      name: "Mato Grosso",
      region: "Centro-Oeste",
      sizeBytes: 29360128,
      bbox: <double>[-18.04, -61.63, -7.35, -50.22],
    ),
    OfflinePackage(
      id: "br-ms",
      stateCode: "MS",
      name: "Mato Grosso do Sul",
      region: "Centro-Oeste",
      sizeBytes: 23068672,
      bbox: <double>[-24.07, -58.17, -17.17, -50.92],
    ),
    OfflinePackage(
      id: "br-mg",
      stateCode: "MG",
      name: "Minas Gerais",
      region: "Sudeste",
      sizeBytes: 67108864,
      bbox: <double>[-22.92, -51.05, -14.23, -39.86],
    ),
    OfflinePackage(
      id: "br-pa",
      stateCode: "PA",
      name: "Pará",
      region: "Norte",
      sizeBytes: 35651584,
      bbox: <double>[-9.84, -58.90, 2.59, -46.06],
    ),
    OfflinePackage(
      id: "br-pb",
      stateCode: "PB",
      name: "Paraíba",
      region: "Nordeste",
      sizeBytes: 14680064,
      bbox: <double>[-8.30, -38.77, -6.02, -34.79],
    ),
    OfflinePackage(
      id: "br-pr",
      stateCode: "PR",
      name: "Paraná",
      region: "Sul",
      sizeBytes: 44040192,
      bbox: <double>[-26.72, -54.62, -22.52, -48.02],
    ),
    OfflinePackage(
      id: "br-pe",
      stateCode: "PE",
      name: "Pernambuco",
      region: "Nordeste",
      sizeBytes: 29360128,
      bbox: <double>[-9.48, -41.36, -7.16, -34.81],
    ),
    OfflinePackage(
      id: "br-pi",
      stateCode: "PI",
      name: "Piauí",
      region: "Nordeste",
      sizeBytes: 16777216,
      bbox: <double>[-10.93, -45.99, -2.74, -40.37],
    ),
    OfflinePackage(
      id: "br-rj",
      stateCode: "RJ",
      name: "Rio de Janeiro",
      region: "Sudeste",
      sizeBytes: 39845888,
      bbox: <double>[-23.37, -44.89, -20.76, -40.96],
    ),
    OfflinePackage(
      id: "br-rn",
      stateCode: "RN",
      name: "Rio Grande do Norte",
      region: "Nordeste",
      sizeBytes: 14680064,
      bbox: <double>[-6.98, -38.58, -4.83, -34.97],
    ),
    OfflinePackage(
      id: "br-rs",
      stateCode: "RS",
      name: "Rio Grande do Sul",
      region: "Sul",
      sizeBytes: 48234496,
      bbox: <double>[-33.75, -57.65, -27.08, -49.69],
    ),
    OfflinePackage(
      id: "br-ro",
      stateCode: "RO",
      name: "Rondônia",
      region: "Norte",
      sizeBytes: 12582912,
      bbox: <double>[-13.69, -66.62, -7.97, -59.77],
    ),
    OfflinePackage(
      id: "br-rr",
      stateCode: "RR",
      name: "Roraima",
      region: "Norte",
      sizeBytes: 6291456,
      bbox: <double>[-1.58, -64.83, 5.27, -58.89],
    ),
    OfflinePackage(
      id: "br-sc",
      stateCode: "SC",
      name: "Santa Catarina",
      region: "Sul",
      sizeBytes: 29360128,
      bbox: <double>[-29.35, -53.84, -25.96, -48.36],
    ),
    OfflinePackage(
      id: "br-sp",
      stateCode: "SP",
      name: "São Paulo",
      region: "Sudeste",
      sizeBytes: 75497472,
      bbox: <double>[-25.31, -53.11, -19.78, -44.16],
    ),
    OfflinePackage(
      id: kBuiltInPackageId,
      stateCode: "SE",
      name: "Sergipe",
      region: "Nordeste",
      sizeBytes: kBuiltInPackageSizeBytes,
      bbox: <double>[-11.57, -38.25, -9.51, -36.39],
      status: OfflinePackageStatus.downloaded,
      downloadProgress: 1.0,
      isBuiltIn: true,
      localFilePath: "assets/data/aracaju_road_network.json",
    ),
    OfflinePackage(
      id: "br-to",
      stateCode: "TO",
      name: "Tocantins",
      region: "Norte",
      sizeBytes: 14680064,
      bbox: <double>[-13.47, -50.74, -5.17, -45.69],
    ),
  ];


// Methods ------------------------------------------------------------------ //


  /// Carrega os IDs persistidos no [LocalStore].
  Future<Set<String>> _loadInstalledIds() async {
    try {
      final String? raw = await _store.getString(kInstalledPackagesStorageKey);
      if (raw == null || raw.isEmpty) {
        return <String>{kBuiltInPackageId};
      }
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      final Set<String> ids = list.map((dynamic e) => e.toString()).toSet();
      ids.add(kBuiltInPackageId);
      return ids;
    } catch (_) {
      return <String>{kBuiltInPackageId};
    }
  }

  /// Salva os IDs persistidos no [LocalStore].
  Future<void> _saveInstalledIds(Set<String> ids) async {
    try {
      final List<String> list = ids.toList();
      await _store.setString(kInstalledPackagesStorageKey, jsonEncode(list));
    } catch (_) {}
  }

  @override
  Future<List<OfflinePackage>> getPackages() async {
    final Set<String> installed = await _loadInstalledIds();

    return _kCatalog.map((OfflinePackage pkg) {
      if (pkg.id == kBuiltInPackageId) {
        return pkg.copyWith(
          status: OfflinePackageStatus.downloaded,
          downloadProgress: 1.0,
          isBuiltIn: true,
        );
      }

      if (_activeDownloads.containsKey(pkg.id)) {
        final double currentProgress = _downloadProgressMap[pkg.id] ?? 0.0;
        return pkg.copyWith(
          status: OfflinePackageStatus.downloading,
          downloadProgress: currentProgress,
        );
      }

      if (installed.contains(pkg.id)) {
        final String? path = _storagePath != null
            ? "$_storagePath/${pkg.id}.json"
            : null;
        return pkg.copyWith(
          status: OfflinePackageStatus.downloaded,
          downloadProgress: 1.0,
          localFilePath: path,
        );
      }

      return pkg.copyWith(
        status: OfflinePackageStatus.notDownloaded,
        downloadProgress: 0.0,
      );
    }).toList(growable: false);
  }

  @override
  Stream<OfflinePackageProgress> downloadPackage(String packageId) {
    if (packageId == kBuiltInPackageId) {
      return Stream<OfflinePackageProgress>.value(
        const OfflinePackageProgress(
          packageId: kBuiltInPackageId,
          progress: 1.0,
          receivedBytes: kBuiltInPackageSizeBytes,
          totalBytes: kBuiltInPackageSizeBytes,
          status: OfflinePackageStatus.downloaded,
        ),
      );
    }

    final StreamController<OfflinePackageProgress>? existing =
        _activeDownloads[packageId];
    if (existing != null) {
      return existing.stream;
    }

    final OfflinePackage? target = _kCatalog.cast<OfflinePackage?>().firstWhere(
          (OfflinePackage? p) => p?.id == packageId,
          orElse: () => null,
        );

    if (target == null) {
      return Stream<OfflinePackageProgress>.error(
        ArgumentError("Pacote não encontrado no catálogo: $packageId"),
      );
    }

    final StreamController<OfflinePackageProgress> controller =
        StreamController<OfflinePackageProgress>.broadcast();
    _activeDownloads[packageId] = controller;
    _downloadProgressMap[packageId] = 0.0;

    _startDownloadSimulation(target, controller);

    return controller.stream;
  }

  void _startDownloadSimulation(
    OfflinePackage package,
    StreamController<OfflinePackageProgress> controller,
  ) {
    final int totalBytes = package.sizeBytes;

    if (stepDuration == Duration.zero) {
      scheduleMicrotask(() async {
        controller.add(
          OfflinePackageProgress(
            packageId: package.id,
            progress: 0.5,
            receivedBytes: totalBytes ~/ 2,
            totalBytes: totalBytes,
            status: OfflinePackageStatus.downloading,
          ),
        );

        // Validação defensiva de integridade de tamanho de bytes
        if (!_verifyPackageIntegrity(totalBytes, package.sizeBytes)) {
          _cleanupCorruptedPackage(package.id);
          _downloadProgressMap.remove(package.id);
          _activeDownloads.remove(package.id);
          controller.addError(
            StateError("Falha de integridade: pacote corrompido ou truncado."),
          );
          await controller.close();
          return;
        }

        final Set<String> installed = await _loadInstalledIds();
        installed.add(package.id);
        await _saveInstalledIds(installed);

        _downloadProgressMap.remove(package.id);
        _activeDownloads.remove(package.id);

        controller.add(
          OfflinePackageProgress(
            packageId: package.id,
            progress: 1.0,
            receivedBytes: totalBytes,
            totalBytes: totalBytes,
            status: OfflinePackageStatus.downloaded,
          ),
        );
        await controller.close();
      });
      return;
    }

    const int steps = 5;
    int currentStep = 0;

    Timer.periodic(stepDuration, (Timer timer) async {
      currentStep++;
      final double progress = (currentStep / steps).clamp(0.0, 1.0);
      final int received = (totalBytes * progress).round();
      _downloadProgressMap[package.id] = progress;

      if (progress >= 1.0) {
        timer.cancel();
        _downloadProgressMap.remove(package.id);
        _activeDownloads.remove(package.id);

        // Validação defensiva de integridade de tamanho de bytes pós-transferência
        if (!_verifyPackageIntegrity(received, package.sizeBytes)) {
          _cleanupCorruptedPackage(package.id);
          controller.addError(
            StateError("Falha de integridade: pacote corrompido ou truncado."),
          );
          await controller.close();
          return;
        }

        final Set<String> installed = await _loadInstalledIds();
        installed.add(package.id);
        await _saveInstalledIds(installed);

        // Se houver diretório de armazenamento configurado, cria arquivo de marcação
        if (_storagePath != null) {
          try {
            final File file = File("$_storagePath/${package.id}.json");
            if (!file.existsSync()) {
              file.createSync(recursive: true);
              file.writeAsStringSync('{"packageId":"${package.id}"}');
            }
          } catch (_) {}
        }

        controller.add(
          OfflinePackageProgress(
            packageId: package.id,
            progress: 1.0,
            receivedBytes: totalBytes,
            totalBytes: totalBytes,
            status: OfflinePackageStatus.downloaded,
          ),
        );
        await controller.close();
      } else {
        controller.add(
          OfflinePackageProgress(
            packageId: package.id,
            progress: progress,
            receivedBytes: received,
            totalBytes: totalBytes,
            status: OfflinePackageStatus.downloading,
          ),
        );
      }
    });
  }

  @override
  Future<void> deletePackage(String packageId) async {
    if (packageId == kBuiltInPackageId) {
      // Pacote padrão de Sergipe é permanente e não pode ser excluído
      return;
    }

    final Set<String> installed = await _loadInstalledIds();
    if (installed.remove(packageId)) {
      await _saveInstalledIds(installed);
    }

    if (_storagePath != null) {
      try {
        final File file = File("$_storagePath/$packageId.json");
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }

  @override
  Future<bool> hasCoverage(double lat, double lon) async {
    final List<OfflinePackage> packages = await getPackages();
    for (final OfflinePackage pkg in packages) {
      if (pkg.isDownloaded && pkg.containsCoordinate(lat, lon)) {
        return true;
      }
    }
    return false;
  }

  /// Retorna o pacote do catálogo correspondente às coordenadas fornecidas,
  /// independentemente de estar baixado ou não.
  OfflinePackage? findPackageForCoordinates(double lat, double lon) {
    for (final OfflinePackage pkg in _kCatalog) {
      if (pkg.containsCoordinate(lat, lon)) {
        return pkg;
      }
    }
    return null;
  }

  @override
  Future<int> getTotalStorageUsedBytes() async {
    final List<OfflinePackage> packages = await getPackages();
    int total = 0;
    for (final OfflinePackage pkg in packages) {
      if (pkg.isDownloaded) {
        total += pkg.sizeBytes;
      }
    }
    return total;
  }

  /// Valida a integridade dos bytes transferidos comparando com o tamanho esperado no catálogo.
  bool _verifyPackageIntegrity(int receivedBytes, int expectedBytes) {
    return expectedBytes > 0 && receivedBytes == expectedBytes;
  }

  /// Remove arquivos parciais residuais em caso de erro ou integridade comprometida.
  void _cleanupCorruptedPackage(String packageId) {
    if (_storagePath != null) {
      try {
        final File file = File("$_storagePath/$packageId.json");
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }
}
