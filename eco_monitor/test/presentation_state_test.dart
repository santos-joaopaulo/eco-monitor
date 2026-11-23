import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

import "package:eco_monitor/data/app_data_sync.dart";
import "package:eco_monitor/data/campaigns_repository.dart";
import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/connectivity_service.dart";
import "package:eco_monitor/data/disposal_guide_repository_synced.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/domain/entities/campaign.dart";
import "package:eco_monitor/domain/entities/collection_point.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/domain/repositories/collect_points_repository_contract.dart";
import "package:eco_monitor/domain/usecases/get_campaigns_use_case.dart";
import "package:eco_monitor/presentation/state/app_providers.dart";
import "package:eco_monitor/presentation/state/campaigns_notifier.dart";
import "package:eco_monitor/presentation/state/location_notifier.dart";
import "package:eco_monitor/presentation/state/points_notifier.dart";
import "package:eco_monitor/presentation/state/sync_notifier.dart";
import "package:eco_monitor/services/location_service.dart";


// Mocks ------------------------------------------------------------------- //


class MockCollectPointsRepository implements ICollectPointsRepository {
  List<CollectionPoint> points = <CollectionPoint>[];
  bool refreshCalled = false;

  @override
  Future<List<CollectionPoint>> loadOffline() async => points;

  @override
  Future<List<CollectionPoint>> refresh() async {
    refreshCalled = true;
    return points;
  }

  @override
  DateTime? get lastUpdated => DateTime.utc(2026, 11, 23);

  @override
  bool get isStale => false;

  @override
  bool get hasRemoteSource => true;

  @override
  Future<List<CollectionPoint>> upsertLocalPoints(
    List<CollectionPoint> newPoints, {
    DateTime? updatedAt,
  }) async {
    final Map<String, CollectionPoint> map = <String, CollectionPoint>{
      for (final CollectionPoint p in points) p.id: p,
    };
    for (final CollectionPoint p in newPoints) {
      map[p.id] = p;
    }
    points = map.values.toList();
    return points;
  }
}

class MockLocationService extends LocationService {
  const MockLocationService({
    this.initialPermission = LocationPermissionState.granted,
    this.initialLocation = const UserLocation(
      latitude: -10.9100,
      longitude: -37.0700,
    ),
  });

  final LocationPermissionState initialPermission;
  final UserLocation? initialLocation;

  @override
  Future<LocationPermissionState> currentPermission() async =>
      initialPermission;

  @override
  Future<LocationPermissionState> requestPermission() async =>
      initialPermission;

  @override
  Future<UserLocation?> currentPosition() async => initialLocation;
}

class FakeConnectivityService extends ConnectivityService {
  FakeConnectivityService({bool initialOnline = true})
      : super(
          connectivityStream: Stream<List<ConnectivityResult>>.value(
            initialOnline
                ? const <ConnectivityResult>[ConnectivityResult.wifi]
                : const <ConnectivityResult>[ConnectivityResult.none],
          ),
        );
}


// Tests ------------------------------------------------------------------- //


void main() {
  group("PointsNotifier", () {
    late MockCollectPointsRepository mockRepo;
    late PointsNotifier notifier;

    final List<CollectionPoint> testPoints = <CollectionPoint>[
      CollectionPoint(
        id: "p1",
        name: "Farmácia A",
        type: PointType.pharmacy,
        latitude: -10.91,
        longitude: -37.07,
        address: "Rua A",
        acceptedWasteTypes: const <WasteType>{WasteType.medicines},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      ),
      CollectionPoint(
        id: "p2",
        name: "Ecoponto B",
        type: PointType.ecoPoint,
        latitude: -10.92,
        longitude: -37.06,
        address: "Rua B",
        acceptedWasteTypes: const <WasteType>{WasteType.batteries},
        hours: "08:00 - 17:00",
        status: PointStatus.active,
      ),
    ];

    setUp(() {
      mockRepo = MockCollectPointsRepository()..points = testPoints;
      notifier = PointsNotifier(repository: mockRepo);
    });

    tearDown(() {
      notifier.dispose();
    });

    test("loads offline points and updates loading state", () async {
      expect(notifier.isLoading, isTrue);
      await notifier.loadOffline();
      expect(notifier.isLoading, isFalse);
      expect(notifier.points.length, 2);
      expect(notifier.filteredPoints.length, 2);
    });

    test("filters points by waste type", () async {
      notifier.setPoints(testPoints);
      expect(notifier.filteredPoints.length, 2);

      notifier.setWasteFilter(WasteType.medicines);
      expect(notifier.filteredPoints.length, 1);
      expect(notifier.filteredPoints.first.id, "p1");

      notifier.clearWasteFilter();
      expect(notifier.filteredPoints.length, 2);
    });

    test("toggles waste filter correctly", () async {
      notifier.setPoints(testPoints);

      notifier.toggleWasteFilter(WasteType.batteries);
      expect(notifier.selectedWasteTypes, contains(WasteType.batteries));
      expect(notifier.filteredPoints.length, 1);
      expect(notifier.filteredPoints.first.id, "p2");

      notifier.toggleWasteFilter(WasteType.batteries);
      expect(notifier.selectedWasteTypes, isEmpty);
      expect(notifier.filteredPoints.length, 2);
    });

    test("manages selected point and list view mode", () {
      notifier.setPoints(testPoints);

      expect(notifier.selectedPoint, isNull);
      notifier.selectPoint(testPoints.first);
      expect(notifier.selectedPoint, testPoints.first);

      expect(notifier.isListView, isFalse);
      notifier.toggleListView();
      expect(notifier.isListView, isTrue);
      notifier.setListView(false);
      expect(notifier.isListView, isFalse);
    });

    test("finds nearest point via use case", () {
      notifier.setPoints(testPoints);

      final nearest = notifier.findNearestPoint(
        latitude: -10.9101,
        longitude: -37.0701,
      );

      expect(nearest, isNotNull);
      expect(nearest!.point.id, "p1");
    });
  });

  group("LocationNotifier", () {
    test("checks permission and locates user successfully", () async {
      final LocationNotifier notifier = LocationNotifier(
        locationService: const MockLocationService(),
      );

      expect(notifier.permissionState, isNull);
      await notifier.checkPermission();
      expect(notifier.permissionState, LocationPermissionState.granted);

      expect(notifier.isLocating, isFalse);
      final UserLocation? location = await notifier.locateUser();
      expect(location, isNotNull);
      expect(notifier.userLocation?.latitude, -10.9100);
      expect(notifier.hasLocation, isTrue);
      expect(notifier.locationFailed, isFalse);

      notifier.dispose();
    });

    test("sets user location directly", () {
      final LocationNotifier notifier = LocationNotifier();

      const UserLocation customLoc = UserLocation(
        latitude: -10.95,
        longitude: -37.05,
      );
      notifier.setUserLocation(customLoc);
      expect(notifier.userLocation, customLoc);

      notifier.dispose();
    });
  });

  group("CampaignsNotifier", () {
    final List<Campaign> testCampaigns = <Campaign>[
      Campaign(
        id: "c1",
        title: "Campanha Ativa",
        description: "Descrição",
        wasteTypes: const <WasteType>{WasteType.electronics},
        locationName: "Local",
        address: "Endereço",
        latitude: -10.91,
        longitude: -37.07,
        startDate: DateTime.utc(2026, 11, 1),
        endDate: DateTime.utc(2026, 11, 30),
        status: CampaignStatus.active,
      ),
    ];

    test("manages campaigns, filters and focused campaign", () {
      final CampaignsNotifier notifier = CampaignsNotifier(
        initialCampaigns: testCampaigns,
      );

      expect(notifier.campaigns.length, 1);
      expect(notifier.filteredCampaigns.length, 1);

      notifier.setFilter(CampaignStatusFilter.upcoming);
      expect(notifier.filteredCampaigns, isEmpty);

      notifier.setFocusedCampaign(testCampaigns.first);
      expect(notifier.focusedCampaign, testCampaigns.first);

      notifier.dispose();
    });
  });

  group("MultiProvider integration test", () {
    testWidgets("provides all dependencies and notifiers to widget tree", (
      WidgetTester tester,
    ) async {
      final AppDataSync sync = AppDataSync(
        collectPointsRepository: CollectPointsRepository(
          localStore: InMemoryLocalStore(),
        ),
        campaignsRepository: CampaignsRepository(
          localStore: InMemoryLocalStore(),
        ),
        guideRepository: DisposalGuideRepositorySynced(
          localStore: InMemoryLocalStore(),
        ),
        suggestionsRepository: PointSuggestionsRepository(
          localStore: InMemoryLocalStore(),
        ),
        connectivityService: FakeConnectivityService(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: buildAppProviders(dataSync: sync),
          child: MaterialApp(
            home: Scaffold(
              body: Consumer4<
                PointsNotifier,
                LocationNotifier,
                CampaignsNotifier,
                SyncNotifier
              >(
                builder: (
                  BuildContext context,
                  PointsNotifier points,
                  LocationNotifier location,
                  CampaignsNotifier campaigns,
                  SyncNotifier syncState,
                  Widget? child,
                ) {
                  return Column(
                    children: [
                      Text("Points: ${points.points.length}"),
                      Text("Location: ${location.hasLocation}"),
                      Text("Campaigns: ${campaigns.campaigns.length}"),
                      Text("Online: ${syncState.isOnline}"),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text("Points: 0"), findsOneWidget);
      expect(find.text("Location: false"), findsOneWidget);
      expect(find.text("Campaigns: 0"), findsOneWidget);
      expect(find.text("Online: true"), findsOneWidget);

      sync.dispose();
    });
  });
}
