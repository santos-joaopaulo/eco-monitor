import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/waste_search_analytics_repository.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/domain/repositories/waste_search_analytics_repository_contract.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  late InMemoryLocalStore store;
  late WasteSearchAnalyticsRepository repository;

  setUp(() {
    store = InMemoryLocalStore();
    repository = WasteSearchAnalyticsRepository(localStore: store);
  });

  group("WasteSearchAnalyticsRepository", () {
    test("inicia zerado sem dados simulados no primeiro uso", () async {
      final List<WasteSearchStat> stats = await repository.getRankedStats();

      expect(stats.length, WasteType.values.length);
      for (final WasteSearchStat stat in stats) {
        expect(stat.count, 0);
        expect(stat.percentage, 0.0);
      }
    });

    test("incrementa contador ao registrar busca de resíduo", () async {
      expect(await repository.getSearchCount(WasteType.glass), 0);

      await repository.recordSearch(WasteType.glass);
      expect(await repository.getSearchCount(WasteType.glass), 1);

      await repository.recordSearch(WasteType.glass);
      expect(await repository.getSearchCount(WasteType.glass), 2);
    });

    test("recalcula percentuais e reordena ranking dinamicamente", () async {
      await repository.recordSearch(WasteType.medicines);
      await repository.recordSearch(WasteType.glass);
      await repository.recordSearch(WasteType.glass);
      await repository.recordSearch(WasteType.glass);

      final List<WasteSearchStat> stats = await repository.getRankedStats();
      expect(stats.first.type, WasteType.glass);
      expect(stats.first.count, 3);
      expect(stats.first.percentage, closeTo(75.0, 0.1));
      expect(stats[1].type, WasteType.medicines);
      expect(stats[1].count, 1);
      expect(stats[1].percentage, closeTo(25.0, 0.1));
    });

    test("segmenta ranking por estado (UF) e agrega no total nacional", () async {
      await repository.recordSearch(WasteType.medicines, stateCode: "se");
      await repository.recordSearch(WasteType.batteries, stateCode: "SP");
      await repository.recordSearch(WasteType.batteries, stateCode: "SP");

      final List<WasteSearchStat> national = await repository.getRankedStats();
      expect(national.first.type, WasteType.batteries);
      expect(national.first.count, 2);
      expect(national[1].type, WasteType.medicines);
      expect(national[1].count, 1);

      final List<WasteSearchStat> sergipe = await repository.getRankedStats(
        stateCode: "SE",
      );
      expect(sergipe.first.type, WasteType.medicines);
      expect(sergipe.first.count, 1);
      expect(sergipe.first.percentage, closeTo(100.0, 0.1));

      final List<WasteSearchStat> bahia = await repository.getRankedStats(
        stateCode: "BA",
      );
      expect(bahia.every((WasteSearchStat s) => s.count == 0), isTrue);
    });

    test(
      "enfileira offline, sincroniza com backend remoto e consome dados da nuvem",
      () async {
        bool isOnline = false;
        final Map<String, Map<WasteType, int>> remoteDb =
            <String, Map<WasteType, int>>{
              kGlobalAnalyticsScope: <WasteType, int>{
                WasteType.electronics: 4,
              },
              "SE": <WasteType, int>{WasteType.electronics: 2},
            };

        final WasteSearchAnalyticsRepository syncedRepo =
            WasteSearchAnalyticsRepository(
              localStore: store,
              isOnlineChecker: () async => isOnline,
              sender: (String scope, Map<WasteType, int> increments) async {
                final Map<WasteType, int> doc = remoteDb.putIfAbsent(
                  scope,
                  () => <WasteType, int>{},
                );
                increments.forEach((WasteType type, int delta) {
                  doc[type] = (doc[type] ?? 0) + delta;
                });
              },
              fetcher: (String scope) async {
                return Map<WasteType, int>.from(
                  remoteDb[scope] ?? const <WasteType, int>{},
                );
              },
            );

        // Registra offline: fica na fila local
        await syncedRepo.recordSearch(WasteType.glass, stateCode: "SE");
        expect(await syncedRepo.pendingCount(), 1);
        final List<WasteSearchStat> offlineStats =
            await syncedRepo.getRankedStats(stateCode: "SE");
        expect(offlineStats.first.type, WasteType.glass);
        expect(offlineStats.first.count, 1);

        // Fica online: flush + fetch traz o agregado completo da nuvem
        isOnline = true;
        final List<WasteSearchStat> onlineSe = await syncedRepo.getRankedStats(
          stateCode: "SE",
        );
        expect(await syncedRepo.pendingCount(), 0);
        expect(onlineSe.first.type, WasteType.electronics);
        expect(onlineSe.first.count, 2);
        expect(onlineSe[1].type, WasteType.glass);
        expect(onlineSe[1].count, 1);

        final List<WasteSearchStat> onlineAll =
            await syncedRepo.getRankedStats();
        expect(onlineAll.first.type, WasteType.electronics);
        expect(onlineAll.first.count, 4);
        expect(onlineAll[1].type, WasteType.glass);
        expect(onlineAll[1].count, 1);
      },
    );

    test("clear limpa registros locais e fila pendente", () async {
      await repository.recordSearch(WasteType.medicines, stateCode: "SE");
      await repository.clear();

      expect(await repository.getSearchCount(WasteType.medicines), 0);
      expect(
        await repository.getSearchCount(WasteType.medicines, stateCode: "SE"),
        0,
      );
    });
  });
}
