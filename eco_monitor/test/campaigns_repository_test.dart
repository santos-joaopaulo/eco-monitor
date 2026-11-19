import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/campaigns_repository.dart";
import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/models/collection_point.dart";


// Helpers ------------------------------------------------------------------ //


Campaign testCampaign(
  String id, {
  CampaignStatus status = CampaignStatus.active,
  DateTime? startDate,
}) {
  return Campaign(
    id: id,
    title: "Campanha $id",
    description: "Descrição de teste",
    wasteTypes: const {WasteType.electronics},
    locationName: "Praça Central",
    address: "Av. Teste, 100",
    latitude: -10.95,
    longitude: -37.06,
    startDate: startDate ?? DateTime.utc(2026, 11, 15),
    endDate: DateTime.utc(2026, 11, 30),
    status: status,
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test("loadOffline falls back to bundled campaigns asset", () async {
    final CampaignsRepository repository = CampaignsRepository(
      clock: () => DateTime.utc(2026, 11, 17, 12),
    );

    final List<Campaign> campaigns = await repository.loadOffline();

    expect(campaigns, isNotEmpty);
    expect(repository.sourceOrigin, DataSourceOrigin.bundledAsset);
    expect(repository.lastUpdated, isNotNull);
    expect(repository.isStale, isFalse);
    expect(campaigns.first.status, CampaignStatus.active);
  });

  test(
    "refresh fetches remote campaigns, caches them, and sorts active first",
    () async {
      final DateTime serverTime = DateTime.utc(2026, 11, 17, 14);
      final CampaignsRepository repository = CampaignsRepository(
        fetcher: () async => CampaignsRemoteSnapshot(
          campaigns: <Campaign>[
            testCampaign("finished", status: CampaignStatus.finished),
            testCampaign("upcoming", status: CampaignStatus.upcoming),
            testCampaign("active", status: CampaignStatus.active),
          ],
          updatedAt: serverTime,
        ),
        clock: () => DateTime.utc(2026, 11, 17, 15),
      );

      final List<Campaign> refreshed = await repository.refresh();

      expect(refreshed.map((Campaign c) => c.id), [
        "active",
        "upcoming",
        "finished",
      ]);
      expect(repository.sourceOrigin, DataSourceOrigin.remoteServer);
      expect(repository.lastUpdated, serverTime);

      final CampaignsRepository offlineRepo = CampaignsRepository(
        clock: () => DateTime.utc(2026, 11, 17, 15),
      );
      final List<Campaign> cached = await offlineRepo.loadOffline();

      expect(cached.map((Campaign c) => c.id), [
        "active",
        "upcoming",
        "finished",
      ]);
      expect(offlineRepo.sourceOrigin, DataSourceOrigin.localCache);
      expect(offlineRepo.lastUpdated, serverTime);
    },
  );

  test("refresh falls back to offline data on remote error", () async {
    final CampaignsRepository repository = CampaignsRepository(
      fetcher: () async => throw Exception("network down"),
      clock: () => DateTime.utc(2026, 11, 17, 12),
    );

    final List<Campaign> fallback = await repository.refresh();

    expect(fallback, isNotEmpty);
    expect(repository.sourceOrigin, DataSourceOrigin.bundledAsset);
  });

  test("isStale becomes true after kCampaignsMaxAge", () async {
    final DateTime updatedAt = DateTime.utc(2026, 11, 10, 12);
    final CampaignsRepository repository = CampaignsRepository(
      fetcher: () async => CampaignsRemoteSnapshot(
        campaigns: <Campaign>[testCampaign("c1")],
        updatedAt: updatedAt,
      ),
      clock: () => updatedAt,
    );

    await repository.refresh();

    final CampaignsRepository staleRepo = CampaignsRepository(
      clock: () => updatedAt.add(kCampaignsMaxAge + const Duration(hours: 1)),
    );
    await staleRepo.loadOffline();

    expect(staleRepo.isStale, isTrue);
  });

  test("clearCache resets loadOffline back to bundled asset", () async {
    final DateTime serverTime = DateTime.utc(2026, 11, 17, 12);
    final CampaignsRepository repository = CampaignsRepository(
      fetcher: () async => CampaignsRemoteSnapshot(
        campaigns: <Campaign>[testCampaign("remote-only")],
        updatedAt: serverTime,
      ),
      clock: () => serverTime,
    );

    await repository.refresh();
    await repository.clearCache();

    final List<Campaign> loaded = await repository.loadOffline();

    expect(loaded.any((Campaign c) => c.id == "remote-only"), isFalse);
    expect(repository.sourceOrigin, DataSourceOrigin.bundledAsset);
  });
}
