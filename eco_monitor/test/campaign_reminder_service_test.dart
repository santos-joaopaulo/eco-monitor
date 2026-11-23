import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/campaign.dart";
import "package:eco_monitor/presentation/state/campaign_reminders_notifier.dart";
import "package:eco_monitor/services/campaign_reminder_service.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Campaign createCampaign({
    String id = "camp_eletronicos_1",
    String title = "Mutirão de Lixo Eletrônico",
    String locationName = "Praça Fausto Cardoso",
    DateTime? startDate,
  }) {
    final DateTime start = startDate ?? DateTime(2026, 12, 10, 9, 0);
    return Campaign(
      id: id,
      title: title,
      description: "Descarte seus computadores e celulares antigos.",
      locationName: locationName,
      address: "Centro, Aracaju - SE",
      latitude: -10.91,
      longitude: -37.05,
      startDate: start,
      endDate: start.add(const Duration(days: 2)),
      wasteTypes: const <WasteType>{WasteType.electronics},
      status: CampaignStatus.upcoming,
    );
  }

  group("CampaignReminderService — Agendamento e Notificações Locais (T10.1)", () {
    test("agenda notificações de véspera (24h antes) e manhã do evento (08h)", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      final DateTime now = DateTime(2026, 12, 1, 10, 0);

      final CampaignReminderService service = CampaignReminderService(
        scheduler: scheduler,
        localStore: store,
        nowProvider: () => now,
      );

      final Campaign campaign = createCampaign(
        startDate: DateTime(2026, 12, 10, 9, 0),
      );

      final bool activated = await service.setReminder(campaign);
      expect(activated, isTrue);
      expect(await service.isReminderActive(campaign.id), isTrue);

      // Deve ter agendado 2 notificações (véspera e manhã do evento)
      expect(scheduler.scheduled.length, 2);

      // 1. Véspera: 09/12/2026 às 09:00
      final DateTime expectedEve = campaign.startDate.subtract(const Duration(hours: 24));
      // 2. Manhã: 10/12/2026 às 08:00
      final DateTime expectedMorning = DateTime(2026, 12, 10, 8, 0);

      final List<DateTime> scheduledDates = scheduler.scheduled.values
          .map((item) => item["scheduledDate"] as DateTime)
          .toList();

      expect(scheduledDates, contains(expectedEve));
      expect(scheduledDates, contains(expectedMorning));

      // Validação das mensagens
      final List<String> titles = scheduler.scheduled.values
          .map((item) => item["title"] as String)
          .toList();
      expect(titles.any((t) => t.contains("Mutirão de Lixo Eletrônico")), isTrue);
    });

    test("cancela notificações e remove da persistência", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      final DateTime now = DateTime(2026, 12, 1, 10, 0);

      final CampaignReminderService service = CampaignReminderService(
        scheduler: scheduler,
        localStore: store,
        nowProvider: () => now,
      );

      final Campaign campaign = createCampaign();
      await service.setReminder(campaign);
      expect(await service.isReminderActive(campaign.id), isTrue);
      expect(scheduler.scheduled.length, 2);

      final bool canceled = await service.cancelReminder(campaign.id);
      expect(canceled, isFalse);
      expect(await service.isReminderActive(campaign.id), isFalse);
      expect(scheduler.scheduled, isEmpty);
    });

    test("toggleReminder alterna entre ativado e desativado", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      final DateTime now = DateTime(2026, 12, 1, 10, 0);

      final CampaignReminderService service = CampaignReminderService(
        scheduler: scheduler,
        localStore: store,
        nowProvider: () => now,
      );

      final Campaign campaign = createCampaign();

      final bool turnOn = await service.toggleReminder(campaign);
      expect(turnOn, isTrue);
      expect(await service.isReminderActive(campaign.id), isTrue);

      final bool turnOff = await service.toggleReminder(campaign);
      expect(turnOff, isFalse);
      expect(await service.isReminderActive(campaign.id), isFalse);
    });

    test("persiste estado entre instâncias com o mesmo LocalStore", () async {
      final InMemoryLocalStore sharedStore = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      final DateTime now = DateTime(2026, 12, 1, 10, 0);

      final CampaignReminderService service1 = CampaignReminderService(
        scheduler: scheduler,
        localStore: sharedStore,
        nowProvider: () => now,
      );

      final Campaign campaign = createCampaign(id: "camp_persisted");
      await service1.setReminder(campaign);

      final CampaignReminderService service2 = CampaignReminderService(
        scheduler: scheduler,
        localStore: sharedStore,
        nowProvider: () => now,
      );

      expect(await service2.isReminderActive("camp_persisted"), isTrue);
      expect(await service2.getActiveCampaignIds(), contains("camp_persisted"));
    });

    test("ignora horários no passado de forma graciosa sem lançar exceção", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      // O evento começou no passado em relação ao horário simulado
      final DateTime now = DateTime(2026, 12, 15, 10, 0);

      final CampaignReminderService service = CampaignReminderService(
        scheduler: scheduler,
        localStore: store,
        nowProvider: () => now,
      );

      final Campaign pastCampaign = createCampaign(
        startDate: DateTime(2026, 12, 10, 9, 0),
      );

      await service.setReminder(pastCampaign);
      // Nenhuma notificação agendada no passado
      expect(scheduler.scheduled, isEmpty);
      // Mas o ID é gravado
      expect(await service.isReminderActive(pastCampaign.id), isTrue);
    });
  });

  group("CampaignRemindersNotifier — Notificador Reativo", () {
    test("inicia carregando lembretes persistidos", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      final CampaignReminderService service = CampaignReminderService(
        scheduler: scheduler,
        localStore: store,
      );

      final Campaign campaign = createCampaign(id: "c_notif");
      await service.setReminder(campaign);

      final CampaignRemindersNotifier notifier = CampaignRemindersNotifier(service);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.isReminderActive("c_notif"), isTrue);
      expect(notifier.activeCampaignIds, contains("c_notif"));
    });

    test("toggleReminder atualiza estado reativo e emite notificações aos listeners", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final InMemoryNotificationScheduler scheduler = InMemoryNotificationScheduler();
      final CampaignReminderService service = CampaignReminderService(
        scheduler: scheduler,
        localStore: store,
      );

      final CampaignRemindersNotifier notifier = CampaignRemindersNotifier(service);
      final Campaign campaign = createCampaign(id: "c_toggle");

      int notifies = 0;
      notifier.addListener(() => notifies++);

      final bool nowActive = await notifier.toggleReminder(campaign);
      expect(nowActive, isTrue);
      expect(notifier.isReminderActive("c_toggle"), isTrue);
      expect(notifies, greaterThan(0));

      final bool nowInactive = await notifier.toggleReminder(campaign);
      expect(nowInactive, isFalse);
      expect(notifier.isReminderActive("c_toggle"), isFalse);
    });
  });
}
