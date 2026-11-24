import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:eco_monitor/data/app_data_sync.dart";
import "package:eco_monitor/data/campaigns_repository.dart";
import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/connectivity_service.dart";
import "package:eco_monitor/data/disposal_guide_repository_synced.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";


CollectionPoint _point({
  required String id,
  required String name,
  PointStatus status = PointStatus.active,
  double lat = -10.9100,
  double lon = -37.0500,
}) {
  return CollectionPoint(
    id: id,
    name: name,
    type: PointType.pharmacy,
    latitude: lat,
    longitude: lon,
    address: "Endereço $name",
    acceptedWasteTypes: const <WasteType>{WasteType.medicines},
    hours: "08:00 - 18:00",
    status: status,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Delta Sync & Incremental Updates (T11.4)", () {
    late InMemoryLocalStore store;
    late DateTime now;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = InMemoryLocalStore();
      now = DateTime.utc(2026, 11, 23, 10, 0, 0);
    });

    test("incremental delta merges modified and new points into local store", () async {
      final CollectionPoint p1 = _point(id: "p1", name: "Farmácia Antiga");
      final CollectionPoint p2 = _point(id: "p2", name: "UBS Bairro");

      // Carga inicial no cache local
      final CollectPointsRepository repo = CollectPointsRepository(
        localStore: store,
        clock: () => now,
        deltaFetcher: (DateTime? since) async {
          if (since != null) {
            // Delta: atualiza p1 e adiciona p3
            return CollectPointsRemoteSnapshot(
              points: [
                _point(id: "p1", name: "Farmácia Atualizada"),
                _point(id: "p3", name: "Novo Ecoponto"),
              ],
              updatedAt: DateTime.utc(2026, 11, 23, 11, 0, 0),
              isDelta: true,
            );
          }
          return CollectPointsRemoteSnapshot(
            points: [p1, p2],
            updatedAt: now,
            isDelta: false,
          );
        },
      );

      // Sincronização inicial completa
      final List<CollectionPoint> initial = await repo.refreshFull();
      expect(initial.length, equals(2));
      expect(initial.map((p) => p.name), containsAll(["Farmácia Antiga", "UBS Bairro"]));

      // Agora executa refresh incremental (delta)
      final List<CollectionPoint> updated = await repo.refresh();
      expect(updated.length, equals(3));

      final Map<String, CollectionPoint> map = {
        for (final CollectionPoint p in updated) p.id: p,
      };

      // p1 foi atualizado
      expect(map["p1"]?.name, equals("Farmácia Atualizada"));
      // p2 foi preservado
      expect(map["p2"]?.name, equals("UBS Bairro"));
      // p3 foi adicionado
      expect(map["p3"]?.name, equals("Novo Ecoponto"));
    });

    test("removes inactive points and tombstones during delta merge", () async {
      final CollectionPoint p1 = _point(id: "p1", name: "Ponto A");
      final CollectionPoint p2 = _point(id: "p2", name: "Ponto B");
      final CollectionPoint p3 = _point(id: "p3", name: "Ponto C");

      final CollectPointsRepository repo = CollectPointsRepository(
        localStore: store,
        clock: () => now,
        deltaFetcher: (DateTime? since) async {
          if (since != null) {
            // Delta: p1 marcado como inativo, p2 excluído por tombstone
            return CollectPointsRemoteSnapshot(
              points: [
                _point(id: "p1", name: "Ponto A", status: PointStatus.inactive),
              ],
              deletedIds: ["p2"],
              updatedAt: DateTime.utc(2026, 11, 23, 12, 0, 0),
              isDelta: true,
            );
          }
          return CollectPointsRemoteSnapshot(
            points: [p1, p2, p3],
            updatedAt: now,
            isDelta: false,
          );
        },
      );

      await repo.refreshFull();
      expect((await repo.loadOffline()).length, equals(3));

      final List<CollectionPoint> postDelta = await repo.refresh();
      expect(postDelta.length, equals(1));
      expect(postDelta.single.id, equals("p3"));
    });

    test("empty delta preserves all local points and updates timestamp", () async {
      final CollectionPoint p1 = _point(id: "p1", name: "Ponto A");
      final DateTime deltaTimestamp = DateTime.utc(2026, 11, 23, 15, 0, 0);

      final CollectPointsRepository repo = CollectPointsRepository(
        localStore: store,
        clock: () => now,
        deltaFetcher: (DateTime? since) async {
          if (since != null) {
            // Nenhuma alteração no servidor desde a última checagem
            return CollectPointsRemoteSnapshot(
              points: const [],
              updatedAt: deltaTimestamp,
              isDelta: true,
            );
          }
          return CollectPointsRemoteSnapshot(
            points: [p1],
            updatedAt: now,
            isDelta: false,
          );
        },
      );

      await repo.refreshFull();
      final List<CollectionPoint> refreshed = await repo.refresh();

      expect(refreshed.length, equals(1));
      expect(refreshed.single.name, equals("Ponto A"));
      expect(repo.lastUpdated, equals(deltaTimestamp));
    });

    test("AppDataSync periodic timer checks deltas silently in background", () async {
      int deltaCheckCount = 0;
      final Completer<void> deltaCompleter = Completer<void>();

      final CollectPointsRepository repo = CollectPointsRepository(
        localStore: store,
        deltaFetcher: (DateTime? since) async {
          deltaCheckCount++;
          if (deltaCheckCount >= 2 && !deltaCompleter.isCompleted) {
            deltaCompleter.complete();
          }
          return CollectPointsRemoteSnapshot(
            points: const [],
            updatedAt: DateTime.utc(2026, 11, 23, 10, 0),
            isDelta: since != null,
          );
        },
      );

      final ConnectivityService connectivity = ConnectivityService(
        connectivityStream: Stream<List<ConnectivityResult>>.value([ConnectivityResult.wifi]),
        checkConnectivity: () async => [ConnectivityResult.wifi],
      );

      final AppDataSync sync = AppDataSync(
        collectPointsRepository: repo,
        campaignsRepository: CampaignsRepository(localStore: store),
        suggestionsRepository: PointSuggestionsRepository(localStore: store),
        guideRepository: DisposalGuideRepositorySynced(),
        connectivityService: connectivity,
        syncInterval: const Duration(milliseconds: 50),
      );

      await sync.initialize();

      // Aguarda os ciclos silenciosos do timer periódico
      await deltaCompleter.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );

      expect(deltaCheckCount, greaterThanOrEqualTo(2));

      sync.dispose();
    });
  });
}
