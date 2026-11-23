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
    test("fornece distribuição base realista no primeiro uso", () async {
      final List<WasteSearchStat> stats = await repository.getRankedStats();

      expect(stats.length, WasteType.values.length);
      expect(stats.first.type, WasteType.medicines);
      expect(stats[1].type, WasteType.batteries);
      expect(stats[2].type, WasteType.sharps);
      expect(stats[3].type, WasteType.electronics);
      expect(stats[4].type, WasteType.glass);

      // Soma das porcentagens deve totalizar 100%
      final double totalPct = stats.fold(
        0.0,
        (double sum, WasteSearchStat s) => sum + s.percentage,
      );
      expect(totalPct, closeTo(100.0, 0.1));
    });

    test("incrementa contador ao registrar busca de resíduo", () async {
      final int initialGlass = await repository.getSearchCount(WasteType.glass);

      await repository.recordSearch(WasteType.glass);
      final int afterOne = await repository.getSearchCount(WasteType.glass);
      expect(afterOne, initialGlass + 1);

      await repository.recordSearch(WasteType.glass);
      final int afterTwo = await repository.getSearchCount(WasteType.glass);
      expect(afterTwo, initialGlass + 2);
    });

    test("recalcula percentuais e reordena ranking dinamicamente", () async {
      // Registra 100 buscas de vidro para ultrapassar remédios
      for (int i = 0; i < 100; i++) {
        await repository.recordSearch(WasteType.glass);
      }

      final List<WasteSearchStat> stats = await repository.getRankedStats();
      expect(stats.first.type, WasteType.glass);
      expect(stats.first.count, greaterThan(100));
      expect(stats.first.percentage, greaterThan(40.0));
    });

    test("clear limpa registros no LocalStore", () async {
      await repository.recordSearch(WasteType.medicines);
      await repository.clear();

      final int count = await repository.getSearchCount(WasteType.medicines);
      // Volta ao baseline de 45
      expect(count, 45);
    });
  });
}
