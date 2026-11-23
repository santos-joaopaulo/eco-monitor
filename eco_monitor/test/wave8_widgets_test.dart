import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:provider/provider.dart";

import "package:eco_monitor/data/favorites_repository.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/point_reviews_repository.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/domain/repositories/favorites_repository_contract.dart";
import "package:eco_monitor/domain/repositories/point_reviews_repository_contract.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/models/point_review.dart";
import "package:eco_monitor/presentation/state/campaign_reminders_notifier.dart";
import "package:eco_monitor/presentation/state/favorites_notifier.dart";
import "package:eco_monitor/services/campaign_reminder_service.dart";
import "package:eco_monitor/widgets/campaign_card.dart";
import "package:eco_monitor/widgets/campaign_details_sheet.dart";
import "package:eco_monitor/widgets/collect_point_sheet.dart";
import "package:eco_monitor/widgets/collect_points_list_view.dart";
import "package:eco_monitor/widgets/filter_bar.dart";


// Helpers ------------------------------------------------------------------ //


CollectionPoint createTestPoint({
  String id = "pt_1",
  String name = "Farmácia Popular Aracaju",
  PointType type = PointType.pharmacy,
}) {
  return CollectionPoint(
    id: id,
    name: name,
    type: type,
    latitude: -10.92,
    longitude: -37.07,
    address: "Av. Barão de Maruim, 100",
    acceptedWasteTypes: const <WasteType>{WasteType.medicines},
    hours: "Seg a Sex: 08h às 18h",
    status: PointStatus.active,
  );
}

Campaign createTestCampaign({
  String id = "camp_1",
  String title = "Mutirão de Lixo Eletrônico",
}) {
  return Campaign(
    id: id,
    title: title,
    description: "Mutirão para recolhimento de lixo eletrônico.",
    locationName: "Praça Fausto Cardoso",
    address: "Centro",
    latitude: -10.91,
    longitude: -37.05,
    startDate: DateTime(2026, 12, 10, 8, 0),
    endDate: DateTime(2026, 12, 12, 18, 0),
    wasteTypes: const <WasteType>{WasteType.electronics},
    status: CampaignStatus.upcoming,
  );
}

Widget buildTestableWidget({
  required Widget child,
  IFavoritesRepository? favoritesRepository,
  IPointReviewsRepository? reviewsRepository,
  CampaignReminderService? reminderService,
  FavoritesNotifier? favoritesNotifier,
  CampaignRemindersNotifier? remindersNotifier,
}) {
  final InMemoryLocalStore store = InMemoryLocalStore();
  final IFavoritesRepository favRepo =
      favoritesRepository ?? FavoritesRepository(localStore: store);
  final IPointReviewsRepository revRepo =
      reviewsRepository ?? PointReviewsRepository(localStore: store);
  final CampaignReminderService remService = reminderService ??
      CampaignReminderService(
        scheduler: InMemoryNotificationScheduler(),
        localStore: store,
      );

  return MultiProvider(
    providers: [
      Provider<IFavoritesRepository>.value(value: favRepo),
      Provider<IPointReviewsRepository>.value(value: revRepo),
      Provider<CampaignReminderService>.value(value: remService),
      ChangeNotifierProvider<FavoritesNotifier>.value(
        value: favoritesNotifier ?? FavoritesNotifier(favRepo),
      ),
      ChangeNotifierProvider<CampaignRemindersNotifier>.value(
        value: remindersNotifier ?? CampaignRemindersNotifier(remService),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("T9.1 — Sistema de Favoritar Pontos (Widgets)", () {
    testWidgets("CollectPointSheet exibe botão de coração e alterna estado ao tocar", (
      WidgetTester tester,
    ) async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);
      final FavoritesNotifier notifier = FavoritesNotifier(repo);
      final CollectionPoint point = createTestPoint(id: "ponto_fav_sheet");

      await tester.pumpWidget(
        buildTestableWidget(
          favoritesRepository: repo,
          favoritesNotifier: notifier,
          child: CollectPointSheet(
            point: point,
            distanceMeters: 500,
            activeFilter: const <WasteType>{},
            isDataStale: false,
            onCancel: () {},
            onStartRoute: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Inicialmente não é favorito: ícone favorite_border
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Toca no botão de favoritar
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      // Agora é favorito: ícone favorite
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
      expect(notifier.isFavorite("ponto_fav_sheet"), isTrue);
    });

    testWidgets("CollectPointsListView renderiza botão de favorito em cada card", (
      WidgetTester tester,
    ) async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);
      final FavoritesNotifier notifier = FavoritesNotifier(repo);
      final CollectionPoint point = createTestPoint(id: "ponto_list_fav");

      await tester.pumpWidget(
        buildTestableWidget(
          favoritesRepository: repo,
          favoritesNotifier: notifier,
          child: CollectPointsListView(
            points: <CollectionPoint>[point],
            onPointSelected: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(notifier.isFavorite("ponto_list_fav"), isTrue);
    });

    testWidgets("FilterBar renderiza pílula de Favoritos quando habilitada", (
      WidgetTester tester,
    ) async {
      bool favToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterBar(
              selectedTypes: const <WasteType>{},
              onChanged: (_) {},
              isFavoritesOnly: false,
              onFavoritesToggle: () {
                favToggled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip("Favoritos"), findsOneWidget);
      await tester.tap(find.byTooltip("Favoritos"));
      await tester.pumpAndSettle();

      expect(favToggled, isTrue);
    });
  });

  group("T9.2 — Sistema de Avaliação e Reporte (Widgets)", () {
    testWidgets("CollectPointSheet exibe seletor de estrelas, chips e envia avaliação", (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final InMemoryLocalStore store = InMemoryLocalStore();
      final PointReviewsRepository reviewsRepo = PointReviewsRepository(
        localStore: store,
      );
      final CollectionPoint point = createTestPoint(id: "ponto_rev_sheet");

      await tester.pumpWidget(
        buildTestableWidget(
          reviewsRepository: reviewsRepo,
          child: SingleChildScrollView(
            child: CollectPointSheet(
              point: point,
              distanceMeters: 300,
              activeFilter: const <WasteType>{},
              isDataStale: false,
              onCancel: () {},
              onStartRoute: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica componente de avaliação
      expect(find.text("AVALIAÇÃO DO ECOPONTO"), findsOneWidget);
      expect(find.text(PointReviewTags.accessibleCollector), findsOneWidget);
      expect(find.text(PointReviewTags.veryGood), findsOneWidget);
      expect(find.text("Enviar avaliação"), findsOneWidget);

      // Seleciona um chip de status
      await tester.ensureVisible(find.text(PointReviewTags.veryGood));
      await tester.tap(find.text(PointReviewTags.veryGood));
      await tester.pumpAndSettle();

      // Clica em enviar
      await tester.ensureVisible(find.text("Enviar avaliação"));
      await tester.tap(find.text("Enviar avaliação"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // SnackBar acessível exibido
      expect(find.textContaining("Avaliação"), findsOneWidget);
      expect(find.text("Obrigado! Sua avaliação foi registrada."), findsOneWidget);

      // Confirma que foi gravado no repositório
      final List<PointReview> reviews = await reviewsRepo.getReviewsForPoint(point.id);
      expect(reviews, hasLength(1));
      expect(reviews.first.tags, contains(PointReviewTags.veryGood));
    });
  });

  group("T10.1 — Lembretes de Campanhas de Lixo Eletrônico (Widgets)", () {
    testWidgets("CampaignCard alterna entre Lembrar-me e Lembrete ativado com 1 toque", (
      WidgetTester tester,
    ) async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      final CampaignReminderService service = CampaignReminderService(
        scheduler: scheduler,
        localStore: store,
      );
      final CampaignRemindersNotifier notifier = CampaignRemindersNotifier(service);
      final Campaign campaign = createTestCampaign(id: "camp_card_test");

      await tester.pumpWidget(
        buildTestableWidget(
          reminderService: service,
          remindersNotifier: notifier,
          child: CampaignCard(
            campaign: campaign,
            onTap: () {},
            onViewLocation: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Estado inicial: "Lembrar-me"
      expect(find.text("Lembrar-me"), findsOneWidget);
      expect(find.text("Lembrete ativado"), findsNothing);

      // Toca em Lembrar-me
      await tester.tap(find.text("Lembrar-me"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Estado alternado: "Lembrete ativado" e SnackBar
      expect(find.text("Lembrete ativado"), findsOneWidget);
      expect(find.text("Lembrete ativado para esta campanha!"), findsOneWidget);
      expect(notifier.isReminderActive(campaign.id), isTrue);

      // Toca novamente para desativar
      await tester.tap(find.text("Lembrete ativado"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text("Lembrar-me"), findsOneWidget);
      expect(find.text("Lembrete cancelado."), findsOneWidget);
      expect(notifier.isReminderActive(campaign.id), isFalse);
    });

    testWidgets("CampaignDetailsSheet exibe ação de lembrete com feedback", (
      WidgetTester tester,
    ) async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      final CampaignReminderService service = CampaignReminderService(
        scheduler: scheduler,
        localStore: store,
      );
      final CampaignRemindersNotifier notifier = CampaignRemindersNotifier(service);
      final Campaign campaign = createTestCampaign(id: "camp_details_test");

      await tester.pumpWidget(
        buildTestableWidget(
          reminderService: service,
          remindersNotifier: notifier,
          child: CampaignDetailsSheet(
            campaign: campaign,
            onClose: () {},
            onViewLocation: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Definir lembrete"), findsOneWidget);

      await tester.tap(find.text("Definir lembrete"));
      await tester.pumpAndSettle();

      expect(find.text("Lembrete ativado"), findsOneWidget);
      expect(notifier.isReminderActive(campaign.id), isTrue);
    });
  });
}
