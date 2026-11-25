import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:printing/printing.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/admin_database_repository.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/domain/entities/collection_point.dart";
import "package:eco_monitor/domain/entities/point_review.dart";
import "package:eco_monitor/domain/entities/point_suggestion.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/screens/admin/admin_dashboard_screen.dart";
import "package:eco_monitor/screens/admin/admin_environmental_report_screen.dart";
import "package:eco_monitor/screens/admin/admin_suggestions_screen.dart";
import "package:eco_monitor/services/admin_auth_service.dart";
import "package:eco_monitor/widgets/suggestions_report_sheet.dart";


// Auxiliares -------------------------------------------------------------- //


class FakeAdminDatabaseRepo implements AdminDatabaseRepository {
  final List<CollectionPoint> points = <CollectionPoint>[];
  final List<PointSuggestion> suggestions = <PointSuggestion>[];
  final List<Campaign> campaigns = <Campaign>[];
  final List<PointReview> reviews = <PointReview>[];

  @override
  Future<List<CollectionPoint>> fetchPoints() async => List.of(points);

  @override
  Future<List<PointSuggestion>> fetchSuggestions() async => List.of(suggestions);

  @override
  Future<void> savePoint(CollectionPoint point) async {}

  @override
  Future<void> savePointsBatch(List<CollectionPoint> pointsList) async {}

  @override
  Future<void> deletePoint(String pointId) async {}

  @override
  Future<List<Campaign>> fetchCampaigns() async => List.of(campaigns);

  @override
  Future<void> saveCampaign(Campaign campaign) async {}

  @override
  Future<void> deleteCampaign(String campaignId) async {}

  @override
  Future<void> updateSuggestionStatus(
    String suggestionId,
    SuggestionStatus status,
  ) async {}

  @override
  Future<void> deleteSuggestion(String suggestionId) async {}

  @override
  Future<List<PointReview>> fetchReviews({String? pointId}) async =>
      List.of(reviews);

  @override
  Future<void> deleteReview(String reviewId) async {}

  @override
  Future<List<CollectionPoint>> fetchPointsWithCriticalReports({
    String criticalTag = "full_collector",
    int minReports = 2,
  }) async => <CollectionPoint>[];
}

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}


// Testes ------------------------------------------------------------------ //


void main() {
  late FakeAdminDatabaseRepo databaseRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    databaseRepo = FakeAdminDatabaseRepo();
  });

  group("AdminEnvironmentalReportScreen Widget Tests", () {
    testWidgets("renders app bar, scope banner and PdfPreview", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      final List<CollectionPoint> points = [
        CollectionPoint(
          id: "p1",
          name: "Farmácia Centro",
          type: PointType.pharmacy,
          latitude: -10.92,
          longitude: -37.05,
          address: "Rua A, 100 - Centro, Aracaju",
          acceptedWasteTypes: const {WasteType.medicines},
          hours: "08h às 18h",
          status: PointStatus.active,
        ),
      ];

      final List<PointSuggestion> suggestions = [
        PointSuggestion(
          id: "s1",
          name: "Sugestão 1",
          address: "Rua B, 200 - Centro",
          acceptedWasteTypes: const {WasteType.medicines},
          hours: "08h às 17h",
          latitude: -10.92,
          longitude: -37.05,
          status: SuggestionStatus.pending,
          createdAt: DateTime.utc(2026, 11, 20),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminEnvironmentalReportScreen(
            initialPoints: points,
            initialSuggestions: suggestions,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("RELATÓRIO AMBIENTAL"), findsOneWidget);
      expect(
        find.text("Abrangência: Todo o Município de Aracaju/SE"),
        findsOneWidget,
      );
      expect(find.byType(PdfPreview), findsOneWidget);
    });

    testWidgets("allows filtering territorial scope by neighborhood", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      final List<PointSuggestion> suggestions = [
        PointSuggestion(
          id: "s1",
          name: "Sugestão Farolândia",
          address: "Av. Murilo Dantas, 100 - Farolândia",
          acceptedWasteTypes: const {WasteType.glass},
          hours: "08h às 17h",
          latitude: -10.95,
          longitude: -37.06,
          status: SuggestionStatus.pending,
          createdAt: DateTime.utc(2026, 11, 20),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AdminEnvironmentalReportScreen(
            initialSuggestions: suggestions,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text("Abrangência: Todo o Município de Aracaju/SE"),
        findsOneWidget,
      );

      // Abrir o menu popup de filtro
      await tester.tap(find.byIcon(Icons.filter_alt_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Farolândia"), findsOneWidget);
      await tester.tap(find.text("Farolândia"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text("Abrangência: Bairro Farolândia"),
        findsOneWidget,
      );
      expect(find.text("Ver Geral"), findsOneWidget);

      // Resetar para visão geral
      await tester.tap(find.text("Ver Geral"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text("Abrangência: Todo o Município de Aracaju/SE"),
        findsOneWidget,
      );
    });
  });

  group("SuggestionsReportSheet Widget Tests", () {
    testWidgets("displays territorial diagnosis, ranking cards and 1-touch actions", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      final List<PointSuggestion> suggestions = [
        PointSuggestion(
          id: "s1",
          name: "Sugestão Centro 1",
          address: "Rua das Flores, 50 - Centro",
          acceptedWasteTypes: const {WasteType.medicines, WasteType.batteries},
          hours: "08h às 17h",
          latitude: -10.92,
          longitude: -37.05,
          status: SuggestionStatus.pending,
          createdAt: DateTime.utc(2026, 11, 20),
        ),
        PointSuggestion(
          id: "s2",
          name: "Sugestão Centro 2",
          address: "Av. Rio Branco, 100 - Centro",
          acceptedWasteTypes: const {WasteType.medicines},
          hours: "08h às 17h",
          latitude: -10.92,
          longitude: -37.05,
          status: SuggestionStatus.pending,
          createdAt: DateTime.utc(2026, 11, 21),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    SuggestionsReportSheet.show(
                      context,
                      suggestions: suggestions,
                    );
                  },
                  child: const Text("Abrir Diagnóstico"),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text("Abrir Diagnóstico"));
      await tester.pumpAndSettle();

      expect(find.text("DIAGNÓSTICO TERRITORIAL"), findsOneWidget);
      expect(find.text("Ranking de Carência Cívica por Bairro"), findsOneWidget);
      expect(find.text("Exportar Relatório Geral em PDF"), findsOneWidget);
      expect(find.text("Centro"), findsOneWidget);
      expect(find.text("Alta Carência"), findsOneWidget);
      expect(find.text("Gerar PDF deste Bairro"), findsOneWidget);

      // Tocar em Exportar Relatório Geral em PDF
      await tester.tap(find.text("Exportar Relatório Geral em PDF"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("RELATÓRIO AMBIENTAL"), findsOneWidget);
    });
  });

  group("Admin Screens Integration Tests", () {
    testWidgets("AdminDashboardScreen displays Relatório Ambiental module card and navigates", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      final authService = AdminAuthService(
        localStore: InMemoryLocalStore(),
        configuredKey: "secret",
      );
      await authService.authenticate("secret");

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboardScreen(
            authService: authService,
            databaseRepository: databaseRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Relatório Ambiental (PDF)"), findsOneWidget);
      expect(
        find.text(
          "Exportar indicadores de impacto ecológico e gestão cívica",
        ),
        findsOneWidget,
      );

      await tester.tap(find.text("Relatório Ambiental (PDF)"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("RELATÓRIO AMBIENTAL"), findsOneWidget);
    });

    testWidgets("AdminSuggestionsScreen does not show report buttons in AppBar", (
      WidgetTester tester,
    ) async {
      useTallSurface(tester);

      databaseRepo.suggestions.add(
        PointSuggestion(
          id: "s1",
          name: "Sugestão Teste",
          address: "Rua X, 10 - Jardins",
          acceptedWasteTypes: const {WasteType.glass},
          hours: "08h às 17h",
          latitude: -10.92,
          longitude: -37.05,
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

      // Verificar ausência dos botões de relatório na AppBar
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsNothing);
      expect(find.byIcon(Icons.assessment_rounded), findsNothing);
      expect(find.byIcon(Icons.location_city_rounded), findsNothing);
    });
  });
}
