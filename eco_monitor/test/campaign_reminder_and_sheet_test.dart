import "dart:typed_data";

import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/presentation/state/campaign_reminders_notifier.dart";
import "package:eco_monitor/services/campaign_reminder_service.dart";
import "package:eco_monitor/services/location_service.dart";
import "package:eco_monitor/widgets/campaign_details_sheet.dart";
import "package:eco_monitor/widgets/focused_campaign_sheet.dart";
import "package:eco_monitor/widgets/point_pin.dart";
import "package:eco_monitor/widgets/waste_style.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Campaign createTestCampaign({
    String id = "test_campaign_1",
    String title = "Mutirão de Coleta de Eletrônicos",
    String locationName = "Parque da Sementeira",
    String address = "Av. Beira Mar, s/n, Jardins",
    double latitude = -10.9472,
    double longitude = -37.0565,
    Set<WasteType> wasteTypes = const <WasteType>{
      WasteType.electronics,
      WasteType.batteries,
    },
  }) {
    return Campaign(
      id: id,
      title: title,
      description: "Traga seus aparelhos eletrônicos e pilhas usadas.",
      locationName: locationName,
      address: address,
      latitude: latitude,
      longitude: longitude,
      startDate: DateTime(2026, 12, 10, 9, 0),
      endDate: DateTime(2026, 12, 12, 17, 0),
      wasteTypes: wasteTypes,
      status: CampaignStatus.upcoming,
    );
  }

  CampaignReminderService createReminderService() {
    return CampaignReminderService(
      scheduler: InMemoryNotificationScheduler(),
      localStore: InMemoryLocalStore(),
      nowProvider: () => DateTime(2026, 12, 1, 10, 0),
    );
  }

  group("PointPin — Marcador de Campanha no Mapa", () {
    test("renderCampaign produz imagem PNG circular de 44x44 válida", () async {
      final Uint8List pinBytes = await PointPin.renderCampaign();
      expect(pinBytes, isNotEmpty);
      expect(pinBytes[0], equals(0x89));
      expect(pinBytes[1], equals(0x50));
      expect(pinBytes[2], equals(0x4E));
      expect(pinBytes[3], equals(0x47));
    });
  });

  group("CampaignDetailsSheet — Feedback Visual Reativo do Lembrete", () {
    testWidgets(
      "alterna entre definir e lembrete ativado com banner informativo imediato",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final Campaign campaign = createTestCampaign();
        final CampaignReminderService reminderService = createReminderService();
        final CampaignRemindersNotifier notifier =
            CampaignRemindersNotifier(reminderService);

        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<CampaignRemindersNotifier>.value(
                value: notifier,
                child: CampaignDetailsSheet(
                  campaign: campaign,
                  onClose: () {},
                  onViewLocation: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder reminderButton = find.text("Definir lembrete");
        expect(reminderButton, findsOneWidget);
        expect(find.byIcon(Icons.notifications_none), findsOneWidget);
        expect(
          find.text("Lembrete programado para a data do evento."),
          findsNothing,
        );
        expect(notifier.isReminderSet(campaign.id), isFalse);

        await tester.ensureVisible(reminderButton);
        await tester.tap(reminderButton);
        await tester.pumpAndSettle();

        expect(find.text("Lembrete ativado"), findsOneWidget);
        expect(find.byIcon(Icons.notifications_active), findsWidgets);
        expect(
          find.text("Lembrete programado para a data do evento."),
          findsOneWidget,
        );
        expect(notifier.isReminderSet(campaign.id), isTrue);

        final Finder activeReminderButton = find.text("Lembrete ativado");
        await tester.ensureVisible(activeReminderButton);
        await tester.tap(activeReminderButton);
        await tester.pumpAndSettle();

        expect(find.text("Definir lembrete"), findsOneWidget);
        expect(find.byIcon(Icons.notifications_none), findsOneWidget);
        expect(
          find.text("Lembrete programado para a data do evento."),
          findsNothing,
        );
        expect(notifier.isReminderSet(campaign.id), isFalse);
      },
    );

    testWidgets(
      "showCampaignDetailsSheet injeta remindersNotifier no modal context",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final Campaign campaign = createTestCampaign();
        final CampaignReminderService reminderService = createReminderService();
        final CampaignRemindersNotifier notifier =
            CampaignRemindersNotifier(reminderService);

        await tester.pump(const Duration(milliseconds: 50));

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showCampaignDetailsSheet(
                          context: context,
                          campaign: campaign,
                          remindersNotifier: notifier,
                          onViewLocation: () {},
                        );
                      },
                      child: const Text("Abrir Detalhes"),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text("Abrir Detalhes"));
        await tester.pumpAndSettle();

        final Finder reminderButton = find.text("Definir lembrete");
        expect(reminderButton, findsOneWidget);

        await tester.ensureVisible(reminderButton);
        await tester.tap(reminderButton);
        await tester.pumpAndSettle();

        expect(find.text("Lembrete ativado"), findsOneWidget);
        expect(notifier.isReminderSet(campaign.id), isTrue);
      },
    );
  });

  group("FocusedCampaignSheet — Renderização, Badges e Ações", () {
    testWidgets(
      "renderiza chips com WasteTypeBadge, distância calculada e botão Traçar Rota",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final Campaign campaign = createTestCampaign(
          latitude: -10.9472,
          longitude: -37.0565,
          wasteTypes: const <WasteType>{
            WasteType.electronics,
            WasteType.batteries,
          },
        );

        final _FakeLocationService fakeLocationService = _FakeLocationService(
          const UserLocation(latitude: -10.9300, longitude: -37.0500),
        );

        bool startRouteCalled = false;
        bool clearCampaignCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusedCampaignSheet(
                campaign: campaign,
                locationService: fakeLocationService,
                onClearCampaign: () => clearCampaignCalled = true,
                onStartRoute: () => startRouteCalled = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Mutirão de Coleta de Eletrônicos"), findsOneWidget);
        expect(find.text("Parque da Sementeira"), findsOneWidget);
        expect(find.text("Av. Beira Mar, s/n, Jardins"), findsOneWidget);

        expect(find.byType(WasteTypeBadge), findsNWidgets(2));
        expect(find.text("Lixo eletrônico"), findsOneWidget);
        expect(find.text("Pilhas e baterias"), findsOneWidget);

        expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
        expect(find.textContaining("km"), findsOneWidget);

        final Finder routeButton = find.widgetWithText(
          FilledButton,
          "Traçar rota para a campanha",
        );
        expect(routeButton, findsOneWidget);

        await tester.ensureVisible(routeButton);
        await tester.tap(routeButton);
        expect(startRouteCalled, isTrue);

        final Finder closeButton = find.byTooltip("Fechar campanha");
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        expect(clearCampaignCalled, isTrue);
      },
    );

    testWidgets(
      "fecha o modal ao arrastar a alça superior para baixo (delta > 20)",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final Campaign campaign = createTestCampaign();
        bool clearCampaignCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusedCampaignSheet(
                campaign: campaign,
                onClearCampaign: () => clearCampaignCalled = true,
                onStartRoute: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder dragHandle = find.byType(GestureDetector).first;

        await tester.drag(dragHandle, const Offset(0, 40));
        await tester.pumpAndSettle();

        expect(clearCampaignCalled, isTrue);
      },
    );

    testWidgets(
      "fecha o modal ao arrastar com velocidade descendente",
      (WidgetTester tester) async {
        useTallSurface(tester);

        final Campaign campaign = createTestCampaign();
        bool clearCampaignCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusedCampaignSheet(
                campaign: campaign,
                onClearCampaign: () => clearCampaignCalled = true,
                onStartRoute: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder dragHandle = find.byType(GestureDetector).first;

        await tester.fling(dragHandle, const Offset(0, 50), 800);
        await tester.pumpAndSettle();

        expect(clearCampaignCalled, isTrue);
      },
    );
  });
}


// Classes ----------------------------------------------------------------- //


class _FakeLocationService extends LocationService {
  _FakeLocationService(this._position);

  final UserLocation? _position;

  @override
  Future<UserLocation?> currentPosition() async => _position;
}
