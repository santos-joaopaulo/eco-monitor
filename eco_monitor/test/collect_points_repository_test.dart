import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";


// Helpers ------------------------------------------------------------------ //


CollectionPoint testPoint(
  String id, {
  PointStatus status = PointStatus.active,
}) {
  return CollectionPoint(
    id: id,
    name: "Ponto $id",
    type: PointType.ecoPoint,
    latitude: -10.95,
    longitude: -37.067,
    address: "Rua de teste",
    acceptedWasteTypes: const {WasteType.batteries},
    hours: "Seg a sex, 8h às 18h",
    status: status,
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test("loadOffline reads and sorts the bundled asset", () async {
    final CollectPointsRepository repository = CollectPointsRepository();

    final List<CollectionPoint> points = await repository.loadOffline();
    final List<String> names = points
        .map((CollectionPoint point) => point.name)
        .toList();

    expect(points, isNotEmpty);
    expect(points.length, greaterThanOrEqualTo(10));
    expect(
      names,
      List<String>.of(names)..sort(
        (String first, String second) =>
            first.toLowerCase().compareTo(second.toLowerCase()),
      ),
    );
    expect(repository.lastUpdated, isNotNull);
    expect(repository.isStale, isFalse);
  });

  test("bundled asset keeps inactive points inactive", () async {
    final CollectPointsRepository repository = CollectPointsRepository();
    final List<CollectionPoint> points = await repository.loadOffline();

    final CollectionPoint inactive = points.firstWhere(
      (CollectionPoint point) => point.id == "ecoponto-bresser",
    );

    expect(inactive.status, PointStatus.inactive);
    expect(inactive.isActive, isFalse);
  });

  test("bundled asset has at least two points without medicines", () async {
    final CollectPointsRepository repository = CollectPointsRepository();
    final List<CollectionPoint> points = await repository.loadOffline();

    final int withoutMedicines = points
        .where((CollectionPoint point) => !point.accepts(WasteType.medicines))
        .length;

    expect(withoutMedicines, greaterThanOrEqualTo(2));
  });

  test("refresh without a fetcher keeps the local timestamp", () async {
    final CollectPointsRepository repository = CollectPointsRepository();

    await repository.loadOffline();
    final DateTime? firstTimestamp = repository.lastUpdated;

    final List<CollectionPoint> refreshed = await repository.refresh();

    expect(refreshed, isNotEmpty);
    expect(repository.lastUpdated, firstTimestamp);
  });

  test("refresh with a fetcher stores the cache and its timestamp", () async {
    final DateTime serverTime = DateTime.utc(2026, 11, 17, 12);
    final CollectPointsRepository repository = CollectPointsRepository(
      fetcher: () async => CollectPointsRemoteSnapshot(
        points: [testPoint("novo")],
        updatedAt: serverTime,
      ),
      clock: () => DateTime.utc(2026, 11, 18),
    );

    final List<CollectionPoint> refreshed = await repository.refresh();

    expect(refreshed.single.id, "novo");
    expect(repository.lastUpdated, serverTime);

    final CollectPointsRepository offlineRepository = CollectPointsRepository();
    final List<CollectionPoint> cached = await offlineRepository.loadOffline();

    expect(cached.single.id, "novo");
    expect(offlineRepository.lastUpdated, serverTime);
  });

  test("refresh uses the timestamp from the remote source", () async {
    final DateTime serverTime = DateTime.utc(2026, 11, 10, 8);
    final CollectPointsRepository repository = CollectPointsRepository(
      fetcher: () async => CollectPointsRemoteSnapshot(
        points: [testPoint("novo")],
        updatedAt: serverTime,
      ),
      clock: () => DateTime.utc(2026, 11, 17, 12),
    );

    await repository.refresh();

    expect(repository.lastUpdated, serverTime);
  });

  test("clearCache makes loadOffline fall back to the asset", () async {
    final DateTime serverTime = DateTime.utc(2026, 11, 17, 12);
    final CollectPointsRepository repository = CollectPointsRepository(
      fetcher: () async => CollectPointsRemoteSnapshot(
        points: [testPoint("novo")],
        updatedAt: serverTime,
      ),
      clock: () => serverTime,
    );

    await repository.refresh();
    await repository.clearCache();

    final List<CollectionPoint> points = await repository.loadOffline();

    expect(points.length, greaterThan(1));
    expect(points.any((CollectionPoint point) => point.id == "novo"), isFalse);
  });

  test("isStale becomes true after the maximum age", () async {
    final DateTime updatedAt = DateTime.utc(2026, 11, 1, 12);
    final CollectPointsRepository repository = CollectPointsRepository(
      fetcher: () async => CollectPointsRemoteSnapshot(
        points: [testPoint("novo")],
        updatedAt: updatedAt,
      ),
      clock: () => updatedAt,
    );

    await repository.refresh();

    final CollectPointsRepository staleRepository = CollectPointsRepository(
      clock: () =>
          updatedAt.add(kCollectPointsMaxAge + const Duration(days: 1)),
    );

    await staleRepository.loadOffline();

    expect(staleRepository.isStale, isTrue);
  });

  test("writes single versioned document with version, updatedAt and points", () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final DateTime serverTime = DateTime.utc(2026, 11, 20, 15, 30);
    final CollectPointsRepository repository = CollectPointsRepository(
      localStore: store,
      fetcher: () async => CollectPointsRemoteSnapshot(
        points: [testPoint("v1-test")],
        updatedAt: serverTime,
      ),
    );

    await repository.refresh();

    final String? rawCache = await store.getString("collect_points_json");
    expect(rawCache, isNotNull);

    final Map<String, dynamic> decoded =
        jsonDecode(rawCache!) as Map<String, dynamic>;
    expect(decoded["version"], 1);
    expect(decoded["updatedAt"], serverTime.toIso8601String());
    expect(decoded["points"], isList);
    expect((decoded["points"] as List).length, 1);
    expect(await store.getInt("collect_points_last_updated"), isNull);
  });

  test("migrates legacy dual-key cache to versioned single document on read", () async {
    final DateTime legacyTime = DateTime.utc(2026, 11, 15, 10, 0);
    final InMemoryLocalStore store = InMemoryLocalStore(<String, Object>{
      "collect_points_json": jsonEncode(<String, dynamic>{
        "points": [testPoint("legacy-point").toJson()],
      }),
      "collect_points_last_updated": legacyTime.millisecondsSinceEpoch,
    });

    final CollectPointsRepository repository = CollectPointsRepository(
      localStore: store,
    );

    final List<CollectionPoint> loaded = await repository.loadOffline();
    expect(loaded.single.id, "legacy-point");
    expect(repository.lastUpdated, legacyTime);
    expect(repository.sourceOrigin, DataSourceOrigin.localCache);

    final String? migratedRaw = await store.getString("collect_points_json");
    expect(migratedRaw, isNotNull);
    final Map<String, dynamic> migrated =
        jsonDecode(migratedRaw!) as Map<String, dynamic>;
    expect(migrated["version"], 1);
    expect(migrated["updatedAt"], legacyTime.toIso8601String());
    expect(await store.getInt("collect_points_last_updated"), isNull);
  });

  test("falls back to bundled asset when cache is corrupted JSON", () async {
    final InMemoryLocalStore store = InMemoryLocalStore(<String, Object>{
      "collect_points_json": "[[corrupted-json-payload{{",
      "collect_points_last_updated": 123456789,
    });

    final CollectPointsRepository repository = CollectPointsRepository(
      localStore: store,
    );

    final List<CollectionPoint> loaded = await repository.loadOffline();
    expect(loaded.length, greaterThanOrEqualTo(10));
    expect(repository.sourceOrigin, DataSourceOrigin.bundledAsset);
  });

  test("falls back to bundled asset on unknown cache version", () async {
    final InMemoryLocalStore store = InMemoryLocalStore(<String, Object>{
      "collect_points_json": jsonEncode(<String, dynamic>{
        "version": 999,
        "updatedAt": "2026-11-20T10:00:00.000Z",
        "points": [testPoint("future-point").toJson()],
      }),
    });

    final CollectPointsRepository repository = CollectPointsRepository(
      localStore: store,
    );

    final List<CollectionPoint> loaded = await repository.loadOffline();
    expect(loaded.length, greaterThanOrEqualTo(10));
    expect(repository.sourceOrigin, DataSourceOrigin.bundledAsset);
  });
}
