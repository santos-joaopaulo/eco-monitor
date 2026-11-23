import "../entities/campaign.dart";
import "../repositories/campaigns_repository_contract.dart";


// Enums ------------------------------------------------------------------- //


/// Filtros de listagem de campanhas de coleta.
enum CampaignStatusFilter { all, active, upcoming }


// Use cases --------------------------------------------------------------- //


/// Caso de uso para consulta e filtragem de campanhas de coleta (Domínio).
class GetCampaignsUseCase {
  const GetCampaignsUseCase(this._repository);

  final ICampaignsRepository _repository;

  /// Obtém campanhas salvas localmente filtradas pelo status desejado.
  Future<List<Campaign>> executeOffline({
    CampaignStatusFilter filter = CampaignStatusFilter.all,
  }) async {
    final List<Campaign> all = await _repository.loadOffline();
    return _applyFilter(all, filter);
  }

  /// Atualiza as campanhas da fonte remota e aplica o filtro.
  Future<List<Campaign>> executeRefresh({
    CampaignStatusFilter filter = CampaignStatusFilter.all,
  }) async {
    final List<Campaign> all = await _repository.refresh();
    return _applyFilter(all, filter);
  }

  /// Aplica filtragem de status sobre a lista de campanhas em memória.
  List<Campaign> filterList(
    List<Campaign> campaigns,
    CampaignStatusFilter filter,
  ) {
    return _applyFilter(campaigns, filter);
  }

  List<Campaign> _applyFilter(
    List<Campaign> campaigns,
    CampaignStatusFilter filter,
  ) {
    return switch (filter) {
      CampaignStatusFilter.all => campaigns,
      CampaignStatusFilter.active =>
        campaigns.where((Campaign c) => c.isActive).toList(),
      CampaignStatusFilter.upcoming =>
        campaigns.where((Campaign c) => c.isUpcoming).toList(),
    };
  }
}
