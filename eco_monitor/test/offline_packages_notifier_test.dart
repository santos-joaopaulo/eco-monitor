import "package:flutter_test/flutter_test.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/models/offline_package.dart";
import "package:eco_monitor/presentation/state/offline_packages_notifier.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/services/offline_package_manager.dart";


// Tests ------------------------------------------------------------------- //


void main() {
  group("OfflinePackagesNotifier (T14.3)", () {
    late InMemoryLocalStore store;
    late OfflinePackageManager manager;
    late OfflinePackagesNotifier notifier;

    setUp(() async {
      store = InMemoryLocalStore();
      manager = OfflinePackageManager(localStore: store);
      notifier = OfflinePackagesNotifier(packageManager: manager);
      await notifier.loadPackages();
    });

    tearDown(() {
      notifier.dispose();
    });

    test("carrega o catálogo de 27 pacotes e calcula armazenamento inicial", () {
      expect(notifier.packages.length, equals(27));
      expect(notifier.totalStorageBytes, equals(kBuiltInPackageSizeBytes));
      expect(notifier.hasExtraPackages, isFalse);
    });

    test("filtra pacotes por texto através do setSearchQuery", () {
      notifier.setSearchQuery("São Paulo");
      expect(notifier.filteredPackages.length, equals(1));
      expect(notifier.filteredPackages.first.stateCode, equals("SP"));

      notifier.setSearchQuery("Bahia");
      expect(notifier.filteredPackages.length, equals(1));
      expect(notifier.filteredPackages.first.name, equals("Bahia"));

      notifier.setSearchQuery("inexistente");
      expect(notifier.filteredPackages, isEmpty);

      notifier.setSearchQuery("");
      expect(notifier.filteredPackages.length, equals(27));
    });

    test("filtra pacotes por região através do setSelectedRegion", () {
      notifier.setSelectedRegion("Sudeste");
      expect(notifier.filteredPackages.length, equals(4)); // SP, RJ, MG, ES
      for (final OfflinePackage pkg in notifier.filteredPackages) {
        expect(pkg.region, equals("Sudeste"));
      }

      notifier.setSelectedRegion("Sul");
      expect(notifier.filteredPackages.length, equals(3)); // PR, SC, RS

      notifier.setSelectedRegion("Todos");
      expect(notifier.filteredPackages.length, equals(27));
    });

    test("identifica o pacote sugerido com base na coordenada geográfica do usuário", () {
      expect(notifier.suggestedPackage, isNull);

      // Usuário em Aracaju / Sergipe
      notifier.updateUserLocation(
        const UserLocation(latitude: -10.92, longitude: -37.07),
      );
      expect(notifier.suggestedPackage?.stateCode, equals("SE"));

      // Usuário na capital de São Paulo
      notifier.updateUserLocation(
        const UserLocation(latitude: -23.55, longitude: -46.63),
      );
      expect(notifier.suggestedPackage?.stateCode, equals("SP"));
    });

    test("escuta o stream de download e atualiza status para downloaded", () async {
      expect(
        notifier.packages.firstWhere((OfflinePackage p) => p.id == "br-ba").status,
        equals(OfflinePackageStatus.notDownloaded),
      );

      final Stream<OfflinePackageProgress> stream = notifier.downloadPackage("br-ba");
      await stream.drain<void>();

      final OfflinePackage bahia =
          notifier.packages.firstWhere((OfflinePackage p) => p.id == "br-ba");
      expect(bahia.status, equals(OfflinePackageStatus.downloaded));
      expect(bahia.isDownloaded, isTrue);
      expect(notifier.hasExtraPackages, isTrue);
      expect(notifier.totalStorageBytes, greaterThan(kBuiltInPackageSizeBytes));
    });

    test("exclui pacote baixado e atualiza contagem de armazenamento", () async {
      await notifier.downloadPackage("br-ba").drain<void>();
      expect(notifier.hasExtraPackages, isTrue);

      await notifier.deletePackage("br-ba");
      final OfflinePackage bahia =
          notifier.packages.firstWhere((OfflinePackage p) => p.id == "br-ba");
      expect(bahia.status, equals(OfflinePackageStatus.notDownloaded));
      expect(notifier.hasExtraPackages, isFalse);
    });

    test("clearExtraPackages limpa todos os pacotes extras preservando Sergipe", () async {
      await notifier.downloadPackage("br-ba").drain<void>();
      await notifier.downloadPackage("br-al").drain<void>();
      expect(notifier.hasExtraPackages, isTrue);

      await notifier.clearExtraPackages();

      expect(notifier.hasExtraPackages, isFalse);
      final OfflinePackage sergipe =
          notifier.packages.firstWhere((OfflinePackage p) => p.id == "br-se");
      expect(sergipe.isDownloaded, isTrue);
      expect(sergipe.isBuiltIn, isTrue);
    });
  });
}
