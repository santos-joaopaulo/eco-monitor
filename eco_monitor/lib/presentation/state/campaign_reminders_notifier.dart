import "package:flutter/foundation.dart";

import "../../models/campaign.dart";
import "../../services/campaign_reminder_service.dart";


// Classes ----------------------------------------------------------------- //


/// Gerenciador de estado reativo para os lembretes de campanhas agendados (RF08, RF09).
class CampaignRemindersNotifier extends ChangeNotifier {
  CampaignRemindersNotifier(this._service) {
    _init();
  }

  final CampaignReminderService _service;
  Set<String> _activeCampaignIds = const <String>{};
  bool _isLoading = true;

  Set<String> get activeCampaignIds => _activeCampaignIds;
  bool get isLoading => _isLoading;

  /// Retorna se o lembrete para [campaignId] está ativado.
  bool isReminderActive(String campaignId) =>
      _activeCampaignIds.contains(campaignId);


  // Methods --------------------------------------------------------------- //


  Future<void> _init() async {
    _activeCampaignIds = await _service.getActiveCampaignIds();
    _isLoading = false;
    notifyListeners();
  }

  /// Alterna o estado do lembrete para [campaign].
  Future<bool> toggleReminder(Campaign campaign) async {
    final bool nowActive = await _service.toggleReminder(campaign);
    if (nowActive) {
      _activeCampaignIds = Set<String>.unmodifiable(
        <String>{..._activeCampaignIds, campaign.id},
      );
    } else {
      _activeCampaignIds = Set<String>.unmodifiable(
        _activeCampaignIds.where((String id) => id != campaign.id),
      );
    }
    notifyListeners();
    return nowActive;
  }

  /// Recarrega do armazenamento local.
  Future<void> reload() async {
    _activeCampaignIds = await _service.getActiveCampaignIds();
    notifyListeners();
  }
}
