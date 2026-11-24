import "package:flutter_test/flutter_test.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/models/offline_package.dart";
import "package:eco_monitor/services/offline_package_manager.dart";


// Tests ------------------------------------------------------------------- //


void main() {
  group("OfflinePackageManager (T14.2)", () {
    late InMemoryLocalStore store;
    late OfflinePackageManager manager;

    setUp(() {
      store = InMemoryLocalStore();
      manager = OfflinePackageManager(localStore: store);
    });

    test("fornece o catálogo com exatamente 27 Unidades Federativas brasileiras", () async {
      final List<OfflinePackage> packages = await manager.getPackages();
      expect(packages.length, equals(27));

      final Set<String> ufs = packages.map((OfflinePackage p) => p.stateCode).toSet();
      expect(ufs.contains("SE"), isTrue);
      expect(ufs.contains("BA"), isTrue);
      expect(ufs.contains("SP"), isTrue);
      expect(ufs.contains("RJ"), isTrue);
      expect(ufs.contains("MG"), isTrue);
      expect(ufs.contains("AM"), isTrue);
      expect(ufs.contains("RS"), isTrue);
      expect(ufs.length, equals(27));
    });

    test("mantém o pacote base de Sergipe (Aracaju) sempre instalado e embutido", () async {
      final List<OfflinePackage> packages = await manager.getPackages();
      final OfflinePackage sergipe = packages.firstWhere((OfflinePackage p) => p.id == "br-se");

      expect(sergipe.isBuiltIn, isTrue);
      expect(sergipe.status, equals(OfflinePackageStatus.downloaded));
      expect(sergipe.downloadProgress, equals(1.0));

      // Tentativa de exclusão não deve remover Sergipe
      await manager.deletePackage("br-se");
      final List<OfflinePackage> afterDelete = await manager.getPackages();
      final OfflinePackage sergipeAfter = afterDelete.firstWhere((OfflinePackage p) => p.id == "br-se");
      expect(sergipeAfter.status, equals(OfflinePackageStatus.downloaded));
      expect(sergipeAfter.isBuiltIn, isTrue);
    });

    test("emite stream contínuo de progresso e persiste download no LocalStore", () async {
      final Stream<OfflinePackageProgress> stream = manager.downloadPackage("br-ba");

      final List<OfflinePackageProgress> progressEvents = <OfflinePackageProgress>[];
      await for (final OfflinePackageProgress event in stream) {
        progressEvents.add(event);
      }

      expect(progressEvents, isNotEmpty);
      expect(progressEvents.first.packageId, equals("br-ba"));
      expect(progressEvents.last.status, equals(OfflinePackageStatus.downloaded));
      expect(progressEvents.last.progress, equals(1.0));

      // Verifica status persistido
      final List<OfflinePackage> packages = await manager.getPackages();
      final OfflinePackage bahia = packages.firstWhere((OfflinePackage p) => p.id == "br-ba");
      expect(bahia.status, equals(OfflinePackageStatus.downloaded));
      expect(bahia.isDownloaded, isTrue);

      final String? rawStore = await store.getString(kInstalledPackagesStorageKey);
      expect(rawStore, contains("br-ba"));
    });

    test("remove pacote previamente instalado e atualiza LocalStore", () async {
      // Baixa Bahia
      await manager.downloadPackage("br-ba").drain<void>();

      List<OfflinePackage> packages = await manager.getPackages();
      expect(packages.firstWhere((OfflinePackage p) => p.id == "br-ba").isDownloaded, isTrue);

      // Deleta Bahia
      await manager.deletePackage("br-ba");

      packages = await manager.getPackages();
      final OfflinePackage bahia = packages.firstWhere((OfflinePackage p) => p.id == "br-ba");
      expect(bahia.status, equals(OfflinePackageStatus.notDownloaded));
      expect(bahia.isDownloaded, isFalse);

      final String? rawStore = await store.getString(kInstalledPackagesStorageKey);
      expect(rawStore?.contains("br-ba") ?? false, isFalse);
    });

    test("hasCoverage valida se a coordenada pertence a um pacote instalado", () async {
      // Aracaju/Sergipe: -10.92, -37.07 (coberto por Sergipe pré-instalado)
      expect(await manager.hasCoverage(-10.92, -37.07), isTrue);

      // Salvador/Bahia: -12.97, -38.50 (não instalado inicialmente)
      expect(await manager.hasCoverage(-12.97, -38.50), isFalse);

      // Baixa o pacote da Bahia
      await manager.downloadPackage("br-ba").drain<void>();

      // Agora Salvador/Bahia deve possuir cobertura
      expect(await manager.hasCoverage(-12.97, -38.50), isTrue);
    });

    test("getTotalStorageUsedBytes calcula a soma dos pacotes instalados", () async {
      final int initialBytes = await manager.getTotalStorageUsedBytes();
      expect(initialBytes, equals(kBuiltInPackageSizeBytes));

      // Baixa Alagoas
      await manager.downloadPackage("br-al").drain<void>();
      final int updatedBytes = await manager.getTotalStorageUsedBytes();

      expect(updatedBytes, greaterThan(initialBytes));
    });

    test("findPackageForCoordinates identifica a UF correspondente mesmo sem download", () {
      final OfflinePackage? se = manager.findPackageForCoordinates(-10.92, -37.07);
      expect(se?.stateCode, equals("SE"));

      final OfflinePackage? sp = manager.findPackageForCoordinates(-23.55, -46.63);
      expect(sp?.stateCode, equals("SP"));
    });
  });
}
