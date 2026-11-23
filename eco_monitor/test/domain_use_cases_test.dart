import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/domain/entities/campaign.dart";
import "package:eco_monitor/domain/entities/collection_point.dart";
import "package:eco_monitor/domain/entities/point_suggestion.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/domain/repositories/campaigns_repository_contract.dart";
import "package:eco_monitor/domain/repositories/point_suggestions_repository_contract.dart";
import "package:eco_monitor/domain/usecases/filter_points_use_case.dart";
import "package:eco_monitor/domain/usecases/get_campaigns_use_case.dart";
import "package:eco_monitor/domain/usecases/get_nearest_point_use_case.dart";
import "package:eco_monitor/domain/usecases/submit_suggestion_use_case.dart";


// Mocks ------------------------------------------------------------------- //


class MockPointSuggestionsRepository implements IPointSuggestionsRepository {
  final List<PointSuggestion> submitted = <PointSuggestion>[];
  SuggestionSubmitResult nextResult = SuggestionSubmitResult.sent;

  @override
  Future<SuggestionSubmitResult> submit(PointSuggestion suggestion) async {
    submitted.add(suggestion);
    return nextResult;
  }

  @override
  Future<int> flushPending() async => 0;

  @override
  Future<int> pendingCount() async => 0;
}

class MockCampaignsRepository implements ICampaignsRepository {
  List<Campaign> campaigns = <Campaign>[];

  @override
  Future<List<Campaign>> loadOffline() async => campaigns;

  @override
  Future<List<Campaign>> refresh() async => campaigns;

  @override
  DateTime? get lastUpdated => DateTime.utc(2026, 11, 23);

  @override
  bool get isStale => false;

  @override
  bool get hasRemoteSource => true;
}


// Tests ------------------------------------------------------------------- //


void main() {
  group("FilterPointsUseCase", () {
    const FilterPointsUseCase useCase = FilterPointsUseCase();

    final List<CollectionPoint> testPoints = <CollectionPoint>[
      CollectionPoint(
        id: "p1",
        name: "Farmácia Centro",
        type: PointType.pharmacy,
        latitude: -10.9100,
        longitude: -37.0700,
        address: "Rua A",
        acceptedWasteTypes: const <WasteType>{WasteType.medicines},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      ),
      CollectionPoint(
        id: "p2",
        name: "Ecoponto Bairro",
        type: PointType.ecoPoint,
        latitude: -10.9200,
        longitude: -37.0600,
        address: "Rua B",
        acceptedWasteTypes: const <WasteType>{
          WasteType.batteries,
          WasteType.electronics,
        },
        hours: "08:00 - 17:00",
        status: PointStatus.active,
      ),
      CollectionPoint(
        id: "p3",
        name: "UBS Inativa",
        type: PointType.healthCenter,
        latitude: -10.9300,
        longitude: -37.0500,
        address: "Rua C",
        acceptedWasteTypes: const <WasteType>{
          WasteType.medicines,
          WasteType.sharps,
        },
        hours: "07:00 - 19:00",
        status: PointStatus.inactive,
      ),
    ];

    test("returns all active points when waste types filter is empty", () {
      final List<CollectionPoint> result = useCase.execute(
        points: testPoints,
        selectedWasteTypes: const <WasteType>{},
      );

      expect(result.length, 2);
      expect(result.map((p) => p.id), containsAll(<String>["p1", "p2"]));
      expect(result.map((p) => p.id), isNot(contains("p3")));
    });

    test("filters active points accepting specified waste type", () {
      final List<CollectionPoint> result = useCase.execute(
        points: testPoints,
        selectedWasteTypes: const <WasteType>{WasteType.medicines},
      );

      expect(result.length, 1);
      expect(result.first.id, "p1");
    });

    test("filters points accepting any of multiple waste types", () {
      final List<CollectionPoint> result = useCase.execute(
        points: testPoints,
        selectedWasteTypes: const <WasteType>{
          WasteType.medicines,
          WasteType.batteries,
        },
      );

      expect(result.length, 2);
      expect(result.map((p) => p.id), containsAll(<String>["p1", "p2"]));
    });
  });

  group("GetNearestPointUseCase", () {
    const GetNearestPointUseCase useCase = GetNearestPointUseCase();

    final List<CollectionPoint> testPoints = <CollectionPoint>[
      CollectionPoint(
        id: "far",
        name: "Ponto Longe",
        type: PointType.pharmacy,
        latitude: -10.9500,
        longitude: -37.0500,
        address: "Rua Longe",
        acceptedWasteTypes: const <WasteType>{WasteType.medicines},
        hours: "08:00 - 18:00",
        status: PointStatus.active,
      ),
      CollectionPoint(
        id: "near",
        name: "Ponto Perto",
        type: PointType.healthCenter,
        latitude: -10.9110,
        longitude: -37.0710,
        address: "Rua Perto",
        acceptedWasteTypes: const <WasteType>{
          WasteType.medicines,
          WasteType.sharps,
        },
        hours: "08:00 - 17:00",
        status: PointStatus.active,
      ),
      CollectionPoint(
        id: "inactive_near",
        name: "Ponto Inativo Perto",
        type: PointType.pharmacy,
        latitude: -10.9105,
        longitude: -37.0705,
        address: "Rua Inativa",
        acceptedWasteTypes: const <WasteType>{WasteType.medicines},
        hours: "08:00 - 18:00",
        status: PointStatus.inactive,
      ),
    ];

    test("finds the nearest active point and calculates correct distance", () {
      final NearestPointResult? result = useCase.execute(
        userLatitude: -10.9100,
        userLongitude: -37.0700,
        points: testPoints,
      );

      expect(result, isNotNull);
      expect(result!.point.id, "near");
      expect(result.distanceMeters, greaterThan(0));
      expect(result.distanceMeters, lessThan(1000));
    });

    test("filters by waste type before calculating nearest point", () {
      final NearestPointResult? result = useCase.execute(
        userLatitude: -10.9100,
        userLongitude: -37.0700,
        points: testPoints,
        selectedWasteTypes: const <WasteType>{WasteType.sharps},
      );

      expect(result, isNotNull);
      expect(result!.point.id, "near");
    });

    test("respects maxDistanceMeters constraint", () {
      final NearestPointResult? result = useCase.execute(
        userLatitude: -10.9100,
        userLongitude: -37.0700,
        points: testPoints,
        maxDistanceMeters: 50, // muito curto para alcançar a 150m
      );

      expect(result, isNull);
    });

    test("returns null when no points are provided", () {
      final NearestPointResult? result = useCase.execute(
        userLatitude: -10.9100,
        userLongitude: -37.0700,
        points: const <CollectionPoint>[],
      );

      expect(result, isNull);
    });
  });

  group("SubmitSuggestionUseCase", () {
    late MockPointSuggestionsRepository mockRepo;
    late SubmitSuggestionUseCase useCase;

    setUp(() {
      mockRepo = MockPointSuggestionsRepository();
      useCase = SubmitSuggestionUseCase(mockRepo);
    });

    test("submits valid suggestion successfully", () async {
      final SuggestionSubmitResult result = await useCase.execute(
        name: "Farmácia Teste",
        address: "Avenida Principal, 123",
        acceptedWasteTypes: const <WasteType>{WasteType.medicines},
        hours: "Segunda a Sexta: 08:00 às 18:00",
        latitude: -10.91,
        longitude: -37.07,
      );

      expect(result, SuggestionSubmitResult.sent);
      expect(mockRepo.submitted.length, 1);
      final PointSuggestion saved = mockRepo.submitted.first;
      expect(saved.name, "Farmácia Teste");
      expect(saved.address, "Avenida Principal, 123");
      expect(saved.acceptedWasteTypes, contains(WasteType.medicines));
    });

    test("throws ArgumentError on name shorter than 2 characters", () async {
      expect(
        () => useCase.execute(
          name: "A",
          address: "Avenida Principal, 123",
          acceptedWasteTypes: const <WasteType>{WasteType.medicines},
          hours: "08:00 - 18:00",
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test("throws ArgumentError on address shorter than 5 characters", () async {
      expect(
        () => useCase.execute(
          name: "Nome Válido",
          address: "Rua",
          acceptedWasteTypes: const <WasteType>{WasteType.medicines},
          hours: "08:00 - 18:00",
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test("throws ArgumentError on empty waste types", () async {
      expect(
        () => useCase.execute(
          name: "Nome Válido",
          address: "Avenida Principal, 123",
          acceptedWasteTypes: const <WasteType>{},
          hours: "08:00 - 18:00",
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group("GetCampaignsUseCase", () {
    late MockCampaignsRepository mockRepo;
    late GetCampaignsUseCase useCase;

    final Campaign activeCampaign = Campaign(
      id: "c1",
      title: "Mutirão Ativo",
      description: "Coleta ativa",
      wasteTypes: const <WasteType>{WasteType.electronics},
      locationName: "Praça Fausto Cardoso",
      address: "Centro",
      latitude: -10.91,
      longitude: -37.07,
      startDate: DateTime.utc(2026, 11, 1),
      endDate: DateTime.utc(2026, 11, 30),
      status: CampaignStatus.active,
    );

    final Campaign upcomingCampaign = Campaign(
      id: "c2",
      title: "Mutirão Previsto",
      description: "Coleta futura",
      wasteTypes: const <WasteType>{WasteType.batteries},
      locationName: "Parque da Sementeira",
      address: "Jardins",
      latitude: -10.92,
      longitude: -37.06,
      startDate: DateTime.utc(2026, 12, 1),
      endDate: DateTime.utc(2026, 12, 10),
      status: CampaignStatus.upcoming,
    );

    setUp(() {
      mockRepo = MockCampaignsRepository()
        ..campaigns = <Campaign>[activeCampaign, upcomingCampaign];
      useCase = GetCampaignsUseCase(mockRepo);
    });

    test("executeOffline returns all campaigns when filter is all", () async {
      final List<Campaign> result = await useCase.executeOffline(
        filter: CampaignStatusFilter.all,
      );
      expect(result.length, 2);
    });

    test("executeOffline filters active campaigns", () async {
      final List<Campaign> result = await useCase.executeOffline(
        filter: CampaignStatusFilter.active,
      );
      expect(result.length, 1);
      expect(result.first.id, "c1");
    });

    test("executeOffline filters upcoming campaigns", () async {
      final List<Campaign> result = await useCase.executeOffline(
        filter: CampaignStatusFilter.upcoming,
      );
      expect(result.length, 1);
      expect(result.first.id, "c2");
    });
  });
}
