import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/admin_database_repository.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/models/point_review.dart";
import "package:eco_monitor/models/point_suggestion.dart";
import "package:eco_monitor/screens/admin/admin_campaigns_screen.dart";
import "package:eco_monitor/screens/admin/admin_dashboard_screen.dart";
import "package:eco_monitor/screens/admin/admin_key_screen.dart";
import "package:eco_monitor/screens/admin/admin_point_form_screen.dart";
import "package:eco_monitor/screens/admin/admin_points_screen.dart";
import "package:eco_monitor/screens/admin/admin_reviews_screen.dart";
import "package:eco_monitor/screens/admin/admin_suggestions_screen.dart";
import "package:eco_monitor/services/admin_auth_service.dart";
import "package:eco_monitor/widgets/eco_app_bar.dart";


// Auxiliares -------------------------------------------------------------- //


class FakeAdminDatabaseRepository implements AdminDatabaseRepository {
  final List<CollectionPoint> points = <CollectionPoint>[];
  final List<Campaign> campaigns = <Campaign>[];
  final List<PointSuggestion> suggestions = <PointSuggestion>[];
  final List<PointReview> reviews = <PointReview>[];

  @override
  Future<List<CollectionPoint>> fetchPoints() async =>
      List<CollectionPoint>.of(points);

  @override
  Future<void> savePoint(CollectionPoint point) async {
    final int index = points.indexWhere((CollectionPoint p) => p.id == point.id);
    if (index >= 0) {
      points[index] = point;
    } else {
      final String id = point.id.isEmpty ? "pt-${points.length + 1}" : point.id;
      points.add(
        CollectionPoint(
          id: id,
          name: point.name,
          type: point.type,
          latitude: point.latitude,
          longitude: point.longitude,
          address: point.address,
          acceptedWasteTypes: point.acceptedWasteTypes,
          hours: point.hours,
          status: point.status,
        ),
      );
    }
  }

  @override
  Future<void> savePointsBatch(List<CollectionPoint> pointsList) async {
    for (final CollectionPoint p in pointsList) {
      await savePoint(p);
    }
  }

  @override
  Future<void> deletePoint(String pointId) async {
    points.removeWhere((CollectionPoint p) => p.id == pointId);
  }

  @override
  Future<List<Campaign>> fetchCampaigns() async => List<Campaign>.of(campaigns);

  @override
  Future<void> saveCampaign(Campaign campaign) async {
    final int index = campaigns.indexWhere(
      (Campaign c) => c.id == campaign.id,
    );
    if (index >= 0) {
      campaigns[index] = campaign;
    } else {
      final String id =
          campaign.id.isEmpty ? "cmp-${campaigns.length + 1}" : campaign.id;
      campaigns.add(
        Campaign(
          id: id,
          title: campaign.title,
          description: campaign.description,
          wasteTypes: campaign.wasteTypes,
          locationName: campaign.locationName,
          address: campaign.address,
          latitude: campaign.latitude,
          longitude: campaign.longitude,
          startDate: campaign.startDate,
          endDate: campaign.endDate,
          status: campaign.status,
        ),
      );
    }
  }

  @override
  Future<void> deleteCampaign(String campaignId) async {
    campaigns.removeWhere((Campaign c) => c.id == campaignId);
  }

  @override
  Future<List<PointSuggestion>> fetchSuggestions() async =>
      List<PointSuggestion>.of(suggestions);

  @override
  Future<void> updateSuggestionStatus(
    String suggestionId,
    SuggestionStatus status,
  ) async {
    final int index = suggestions.indexWhere(
      (PointSuggestion s) => s.id == suggestionId,
    );
    if (index >= 0) {
      final PointSuggestion curr = suggestions[index];
      suggestions[index] = PointSuggestion(
        id: curr.id,
        name: curr.name,
        address: curr.address,
        acceptedWasteTypes: curr.acceptedWasteTypes,
        hours: curr.hours,
        latitude: curr.latitude,
        longitude: curr.longitude,
        status: status,
        createdAt: curr.createdAt,
      );
    }
  }

  @override
  Future<void> deleteSuggestion(String suggestionId) async {
    suggestions.removeWhere((PointSuggestion s) => s.id == suggestionId);
  }

  @override
  Future<List<PointReview>> fetchReviews({String? pointId}) async {
    if (pointId != null && pointId.isNotEmpty) {
      return reviews.where((PointReview r) => r.pointId == pointId).toList();
    }
    return List<PointReview>.of(reviews);
  }

  @override
  Future<void> deleteReview(String reviewId) async {
    reviews.removeWhere((PointReview r) => r.id == reviewId);
  }

  @override
  Future<List<CollectionPoint>> fetchPointsWithCriticalReports({
    String criticalTag = PointReviewTags.fullCollector,
    int minReports = 2,
  }) async {
    final Map<String, int> counts = <String, int>{};
    for (final PointReview r in reviews) {
      if (r.tags.contains(criticalTag)) {
        counts[r.pointId] = (counts[r.pointId] ?? 0) + 1;
      }
    }

    final Set<String> criticalIds = counts.entries
        .where((MapEntry<String, int> e) => e.value >= minReports)
        .map((MapEntry<String, int> e) => e.key)
        .toSet();

    return points
        .where((CollectionPoint p) => criticalIds.contains(p.id))
        .toList();
  }
}

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

CollectionPoint testPoint(
  String id, {
  String name = "Farmácia Teste",
  PointStatus status = PointStatus.active,
}) {
  return CollectionPoint(
    id: id,
    name: name,
    type: PointType.pharmacy,
    latitude: -10.95,
    longitude: -37.06,
    address: "Rua Exemplo, 100",
    acceptedWasteTypes: const {WasteType.medicines},
    hours: "Seg a Sex: 08h às 18h",
    status: status,
  );
}


// Testes ------------------------------------------------------------------ //


void main() {
  late InMemoryLocalStore store;
  late AdminAuthService authService;
  late FakeAdminDatabaseRepository databaseRepo;

  setUp(() {
    store = InMemoryLocalStore();
    authService = AdminAuthService(
      localStore: store,
      configuredKey: "chaveSecreta",
    );
    databaseRepo = FakeAdminDatabaseRepository();
  });

  group("AdminKeyScreen", () {
    testWidgets("shows error on empty submit and rejects incorrect key", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminKeyScreen(
            authService: authService,
            databaseRepository: databaseRepo,
          ),
        ),
      );

      // Clicar em Liberar Acesso sem preencher
      await tester.tap(find.text("Liberar Acesso"));
      await tester.pumpAndSettle();
      expect(find.text("Informe a chave de acesso."), findsOneWidget);

      // Preencher com chave errada
      await tester.enterText(find.byType(TextField), "chaveErrada");
      await tester.tap(find.text("Liberar Acesso"));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Chave de acesso incorreta"),
        findsOneWidget,
      );
    });

    testWidgets("submitting correct key navigates to AdminDashboardScreen", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminKeyScreen(
            authService: authService,
            databaseRepository: databaseRepo,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), "chaveSecreta");
      await tester.tap(find.text("Liberar Acesso"));
      await tester.pumpAndSettle();

      expect(find.text("PAINEL ADMINISTRATIVO"), findsOneWidget);
      expect(find.text("Pontos de Coleta"), findsOneWidget);
    });
  });

  group("AdminDashboardScreen", () {
    testWidgets("renders module cards and lock button revokes authorization", (
      WidgetTester tester,
    ) async {
      // Pré-autoriza o serviço
      await authService.authenticate("chaveSecreta");
      expect(await authService.isAuthorized(), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            authService: authService,
            databaseRepository: databaseRepo,
          ),
        ),
      );

      expect(find.text("PAINEL ADMINISTRATIVO"), findsOneWidget);
      expect(find.text("Pontos de Coleta"), findsOneWidget);
      expect(find.text("Sugestões de Usuários"), findsOneWidget);
      expect(find.text("Campanhas de Coleta"), findsOneWidget);
      expect(find.text("Avaliações e Reportes Cidadãos"), findsOneWidget);

      // Clicar no botão de bloquear
      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();

      expect(await authService.isAuthorized(), isFalse);
    });

    testWidgets("navigates to AdminReviewsScreen from dashboard module card", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      await authService.authenticate("chaveSecreta");

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            authService: authService,
            databaseRepository: databaseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Avaliações e Reportes Cidadãos"), findsOneWidget);

      await tester.tap(find.text("Avaliações e Reportes Cidadãos"));
      await tester.pumpAndSettle();

      expect(find.text("AVALIAÇÕES E REPORTES"), findsOneWidget);
    });
  });

  group("AdminPointsScreen & AdminPointFormScreen", () {
    testWidgets("lists points, toggles status, and creates new point", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      databaseRepo.points.add(testPoint("pt-1", name: "Farmácia Centro"));

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPointsScreen(databaseRepository: databaseRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Farmácia Centro"), findsOneWidget);
      expect(find.text("Ativo"), findsWidgets);

      // Clicar em Novo Ponto
      await tester.tap(find.text("Novo Ponto"));
      await tester.pumpAndSettle();

      expect(find.text("NOVO PONTO DE COLETA"), findsOneWidget);

      // Preencher formulário
      await tester.enterText(
        find.widgetWithText(TextFormField, "Nome do Ponto *"),
        "Ecoponto Norte",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Endereço Completo *"),
        "Av. das Palmeiras, 500",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Latitude *"),
        "-10.9123",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Longitude *"),
        "-37.0456",
      );

      await tester.tap(find.text("Cadastrar Ponto"));
      await tester.pumpAndSettle();

      // Volta para a lista e exibe novo ponto
      expect(find.text("Ecoponto Norte"), findsOneWidget);
      expect(databaseRepo.points.length, 2);
    });

    testWidgets("AdminPointFormScreen supports glass waste and displays review stats when editing", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      final CollectionPoint point = testPoint("pt-edit", name: "Farmácia Esperança");
      databaseRepo.points.add(point);
      databaseRepo.reviews.addAll([
        PointReview(
          id: "rev-1",
          pointId: "pt-edit",
          rating: 4,
          tags: const [PointReviewTags.accessibleCollector],
          createdAt: DateTime.utc(2026, 11, 21),
        ),
        PointReview(
          id: "rev-2",
          pointId: "pt-edit",
          rating: 5,
          tags: const [PointReviewTags.accessibleCollector, PointReviewTags.veryGood],
          createdAt: DateTime.utc(2026, 11, 22),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPointFormScreen(
            databaseRepository: databaseRepo,
            existingPoint: point,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("EDITAR PONTO"), findsOneWidget);
      expect(find.text("AVALIAÇÃO DA POPULAÇÃO"), findsOneWidget);
      expect(find.textContaining("4.5 / 5.0"), findsOneWidget);
      expect(find.textContaining("2 avaliações"), findsOneWidget);
      expect(find.textContaining("Coletor acessível (2)"), findsOneWidget);

      // Verifica presença e seleção do resíduo Vidro
      final Finder glassChip = find.widgetWithText(FilterChip, "Vidro");
      expect(glassChip, findsOneWidget);
      await tester.tap(glassChip);
      await tester.pumpAndSettle();

      await tester.tap(find.text("Salvar Alterações"));
      await tester.pumpAndSettle();

      final CollectionPoint updated = databaseRepo.points.firstWhere((p) => p.id == "pt-edit");
      expect(updated.acceptedWasteTypes.contains(WasteType.glass), isTrue);
    });
  });

  group("AdminSuggestionsScreen", () {
    testWidgets("lists user suggestions and changes status", (
      WidgetTester tester,
    ) async {
      databaseRepo.suggestions.add(
        PointSuggestion(
          id: "sug-1",
          name: "Posto do Bairro",
          address: "Rua B, 20",
          acceptedWasteTypes: const {WasteType.batteries},
          hours: "08h às 17h",
          latitude: -10.9,
          longitude: -37.0,
          status: SuggestionStatus.pending,
          createdAt: DateTime.utc(2026, 11, 20),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSuggestionsScreen(databaseRepository: databaseRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Posto do Bairro"), findsOneWidget);
      expect(find.text("Pendente"), findsOneWidget);
      expect(find.text("Criar Ponto"), findsOneWidget);
    });

    testWidgets("hides report buttons in AppBar and converts suggestion to point", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      databaseRepo.suggestions.addAll([
        PointSuggestion(
          id: "sug-1",
          name: "Coleta Praça Centro",
          address: "Rua das Laranjeiras, 100 - Centro",
          acceptedWasteTypes: const {WasteType.glass, WasteType.batteries},
          hours: "08h às 18h",
          latitude: -10.91,
          longitude: -37.05,
          status: SuggestionStatus.pending,
          createdAt: DateTime.utc(2026, 11, 20),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSuggestionsScreen(databaseRepository: databaseRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("SUGESTÕES DE USUÁRIOS"), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsNothing);
      expect(find.byIcon(Icons.assessment_rounded), findsNothing);
      expect(find.byIcon(Icons.location_city_rounded), findsNothing);

      expect(find.text("Criar Ponto"), findsOneWidget);
      await tester.tap(find.text("Criar Ponto"));
      await tester.pumpAndSettle();

      expect(find.text("NOVO PONTO DE COLETA"), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, "Nome do Ponto *"),
        findsOneWidget,
      );
    });
  });

  group("AdminReviewsScreen", () {
    testWidgets("lists reviews, displays critical banner and deletes review", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      databaseRepo.points.add(testPoint("pt-1", name: "Ecoponto Central"));
      databaseRepo.reviews.addAll([
        PointReview(
          id: "rev-1",
          pointId: "pt-1",
          rating: 1,
          tags: const [PointReviewTags.fullCollector],
          createdAt: DateTime.utc(2026, 11, 22),
          comment: "Coletor transbordando resíduos",
        ),
        PointReview(
          id: "rev-2",
          pointId: "pt-1",
          rating: 2,
          tags: const [PointReviewTags.fullCollector],
          createdAt: DateTime.utc(2026, 11, 23),
          comment: "Ainda continua cheio hoje",
        ),
        PointReview(
          id: "rev-3",
          pointId: "pt-1",
          rating: 5,
          tags: const [PointReviewTags.accessibleCollector],
          createdAt: DateTime.utc(2026, 11, 23),
          comment: "Muito prático",
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminReviewsScreen(databaseRepository: databaseRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("AVALIAÇÕES E REPORTES"), findsOneWidget);
      expect(find.textContaining("múltiplos reportes críticos"), findsOneWidget);
      expect(find.text("Ecoponto Central"), findsWidgets);
      expect(find.text("\"Coletor transbordando resíduos\""), findsOneWidget);

      // Filtro por tag
      await tester.tap(find.text("Coletor cheio").first);
      await tester.pumpAndSettle();

      expect(find.text("\"Coletor transbordando resíduos\""), findsOneWidget);
      expect(find.text("\"Muito prático\""), findsNothing);

      // Limpa filtro de tag
      await tester.tap(find.text("Todas as tags"));
      await tester.pumpAndSettle();

      expect(find.text("\"Muito prático\""), findsOneWidget);

      // Filtro por nota (ex.: 5 ★)
      await tester.tap(find.text("5 ★"));
      await tester.pumpAndSettle();

      expect(find.text("\"Muito prático\""), findsOneWidget);
      expect(find.text("\"Coletor transbordando resíduos\""), findsNothing);

      // Limpa filtro de nota
      await tester.tap(find.text("Todas as notas"));
      await tester.pumpAndSettle();

      // Deletar a primeira avaliação
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text("Moderar Avaliação"), findsOneWidget);
      await tester.tap(find.text("Remover"));
      await tester.pumpAndSettle();

      expect(databaseRepo.reviews.length, 2);
    });
  });

  group("AdminCampaignsScreen & AdminCampaignFormScreen", () {
    testWidgets("lists campaigns and creates a new campaign", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminCampaignsScreen(databaseRepository: databaseRepo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("CAMPANHAS DE COLETA"), findsOneWidget);

      await tester.tap(find.text("Nova Campanha"));
      await tester.pumpAndSettle();

      expect(find.text("NOVA CAMPANHA"), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, "Título da Campanha *"),
        "Mutirão de Eletrônicos",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Descrição *"),
        "Descarte seguro de lixo eletrônico",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Nome do Local *"),
        "Praça Fausto Cardoso",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Endereço *"),
        "Centro da Cidade",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Latitude *"),
        "-10.91",
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, "Longitude *"),
        "-37.07",
      );

      await tester.tap(find.text("Cadastrar Campanha"));
      await tester.pumpAndSettle();

      expect(find.text("Mutirão de Eletrônicos"), findsOneWidget);
      expect(databaseRepo.campaigns.length, 1);
    });
  });

  group("EcoAppBar Admin Integration", () {
    testWidgets("secret gesture on EcoAppBar logo opens AdminKeyScreen when unauthorized", (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: EcoAppBar(
              title: "ECOMONITOR",
              authService: authService,
              adminHoldDuration: const Duration(seconds: 1),
            ),
            body: const Center(child: Text("Home")),
          ),
        ),
      );

      final Offset center = tester.getCenter(find.byType(Image));

      // 1º toque
      final TestGesture gesture = await tester.startGesture(center);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      // 2º toque mantido por 1s
      await gesture.down(center);
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text("ACESSO ADMINISTRATIVO"), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, "Liberar Acesso"), findsOneWidget);
    });
  });
}
