import "dart:async";
import "dart:convert";

import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:timezone/data/latest_all.dart" as tz;
import "package:timezone/timezone.dart" as tz;

import "../data/local_store.dart";
import "../domain/entities/campaign.dart";


// Interfaces --------------------------------------------------------------- //


/// Contrato abstrato para disparos e agendamento de notificações na plataforma.
abstract interface class INotificationScheduler {
  Future<void> initialize();

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  });

  Future<void> cancelNotification(int id);
}


// Classes ------------------------------------------------------------------ //


/// Agendador padrão sobre o plugin `flutter_local_notifications`.
class LocalNotificationsScheduler implements INotificationScheduler {
  LocalNotificationsScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings("@mipmap/ic_launcher");
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    try {
      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (_) {
      // Ignora falhas de canal de plataforma em ambientes de teste de widget/unitário
    }
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await initialize();

    try {
      final tz.TZDateTime tzDate = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            "campaign_reminders_channel",
            "Lembretes de Campanhas",
            channelDescription:
                "Notificações de mutirões de coleta e campanhas ambientais",
            importance: Importance.high,
            priority: Priority.high,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Fallback gracioso caso a plataforma não suporte agendamento exato
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (_) {
      // Ignora erro em ambientes sem canal ativo
    }
  }
}

/// Agendador em memória para execução limpa de testes unitários e de widget.
class InMemoryNotificationScheduler implements INotificationScheduler {
  final Map<int, Map<String, dynamic>> scheduled = <int, Map<String, dynamic>>{};
  bool isInitialized = false;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    scheduled[id] = <String, dynamic>{
      "id": id,
      "title": title,
      "body": body,
      "scheduledDate": scheduledDate,
    };
  }

  @override
  Future<void> cancelNotification(int id) async {
    scheduled.remove(id);
  }
}

/// Serviço de agendamento e persistência de lembretes locais para campanhas de coleta (RF08, RF09).
class CampaignReminderService {
  CampaignReminderService({
    INotificationScheduler? scheduler,
    LocalStore? localStore,
    Future<SharedPreferences> Function()? preferencesFactory,
    DateTime Function()? nowProvider,
  }) : _scheduler = scheduler ?? LocalNotificationsScheduler(),
       _store = localStore ??
           SharedPreferencesLocalStore(
             preferencesFactory: preferencesFactory,
           ),
       _nowProvider = nowProvider ?? DateTime.now;

  static const String storeKey = "active_campaign_reminders_store_v1";

  final INotificationScheduler _scheduler;
  final LocalStore _store;
  final DateTime Function() _nowProvider;

  Set<String>? _cachedActiveIds;
  Future<void> _lock = Future<void>.value();


// Methods ------------------------------------------------------------------ //


  /// Inicializa o subsistema de notificações da plataforma.
  Future<void> initialize() async {
    await _scheduler.initialize();
  }

  /// Retorna se há um lembrete ativo agendado para a campanha [campaignId].
  Future<bool> isReminderActive(String campaignId) {
    return _synchronized(() async {
      final Set<String> active = await _loadActiveIdsUnsafe();
      return active.contains(campaignId);
    });
  }

  /// Retorna o conjunto de IDs de campanhas com lembretes ativos.
  Future<Set<String>> getActiveCampaignIds() {
    return _synchronized(() async {
      final Set<String> active = await _loadActiveIdsUnsafe();
      return Set<String>.of(active);
    });
  }

  /// Ativa o lembrete para [campaign], agendando notificações para a véspera (24h antes)
  /// e para a manhã do início do evento (às 08:00), persistindo no [LocalStore].
  Future<bool> setReminder(Campaign campaign) {
    return _synchronized(() async {
      final Set<String> active = await _loadActiveIdsUnsafe();
      if (active.contains(campaign.id)) {
        return true;
      }

      await _scheduleCampaignNotifications(campaign);
      active.add(campaign.id);
      await _persistActiveIdsUnsafe(active);
      return true;
    });
  }

  /// Cancela o lembrete agendado para [campaignId] e desmarca notificações no sistema.
  Future<bool> cancelReminder(String campaignId) {
    return _synchronized(() async {
      final Set<String> active = await _loadActiveIdsUnsafe();
      if (!active.contains(campaignId)) {
        return false;
      }

      final (int eveId, int morningId) = _notificationIdsFor(campaignId);
      await _scheduler.cancelNotification(eveId);
      await _scheduler.cancelNotification(morningId);

      active.remove(campaignId);
      await _persistActiveIdsUnsafe(active);
      return false;
    });
  }

  /// Alterna o estado do lembrete: cancela se ativo, ou ativa se inativo.
  Future<bool> toggleReminder(Campaign campaign) async {
    final bool active = await isReminderActive(campaign.id);
    if (active) {
      await cancelReminder(campaign.id);
      return false;
    } else {
      await setReminder(campaign);
      return true;
    }
  }


// Helpers ------------------------------------------------------------------ //


  (int, int) _notificationIdsFor(String campaignId) {
    final int baseHash = (campaignId.hashCode & 0x7FFFFFFF) % 1000000;
    return (baseHash * 2, baseHash * 2 + 1);
  }

  Future<void> _scheduleCampaignNotifications(Campaign campaign) async {
    final DateTime now = _nowProvider();
    final (int eveId, int morningId) = _notificationIdsFor(campaign.id);

    // 1. Notificação de Véspera (24h antes do início)
    final DateTime eveDate = campaign.startDate.subtract(const Duration(hours: 24));
    if (eveDate.isAfter(now)) {
      await _scheduler.scheduleNotification(
        id: eveId,
        title: "Lembrete de Campanha: ${campaign.title}",
        body: "Amanhã inicia o mutirão de coleta em ${campaign.locationName}. Prepare seus resíduos!",
        scheduledDate: eveDate,
      );
    }

    // 2. Notificação da Manhã do Início da Campanha (08:00)
    final DateTime morningDate = DateTime(
      campaign.startDate.year,
      campaign.startDate.month,
      campaign.startDate.day,
      8,
      0,
    );
    if (morningDate.isAfter(now)) {
      await _scheduler.scheduleNotification(
        id: morningId,
        title: "Hoje: ${campaign.title}",
        body: "Mutirão de lixo eletrônico acontecendo hoje em ${campaign.locationName}. Participe!",
        scheduledDate: morningDate,
      );
    }
  }

  Future<Set<String>> _loadActiveIdsUnsafe() async {
    final Set<String>? cached = _cachedActiveIds;
    if (cached != null) {
      return cached;
    }

    final String? raw = await _store.getString(storeKey);
    if (raw == null || raw.trim().isEmpty) {
      _cachedActiveIds = <String>{};
      return <String>{};
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        final Set<String> set = decoded.whereType<String>().toSet();
        _cachedActiveIds = set;
        return set;
      }
    } catch (_) {
      // Ignora dado inválido
    }

    _cachedActiveIds = <String>{};
    return <String>{};
  }

  Future<void> _persistActiveIdsUnsafe(Set<String> ids) async {
    _cachedActiveIds = Set<String>.of(ids);
    final String encoded = jsonEncode(ids.toList()..sort());
    await _store.setString(storeKey, encoded);
  }

  Future<T> _synchronized<T>(Future<T> Function() computation) {
    final Completer<T> completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        final T result = await computation();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
