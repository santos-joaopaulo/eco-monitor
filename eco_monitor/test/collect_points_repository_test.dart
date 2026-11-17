import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/collect_points_repository.dart";
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
      (CollectionPoint point) => point.id == "ecoponto-sao-conrado",
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
}
