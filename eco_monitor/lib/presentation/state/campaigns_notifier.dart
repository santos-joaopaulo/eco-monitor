import "package:flutter/foundation.dart";

import "../../data/app_data_sync.dart";
import "../../domain/entities/campaign.dart";
import "../../domain/repositories/campaigns_repository_contract.dart";
import "../../domain/usecases/get_campaigns_use_case.dart";


// Notifiers ---------------------------------------------------------------- //


/// Gerenciador de estado reativo para as campanhas de coleta (Presentation).
class CampaignsNotifier extends ChangeNotifier {
  CampaignsNotifier({
    ICampaignsRepository? repository,
    AppDataSync? dataSync,
    GetCampaignsUseCase? useCase,
    List<Campaign> initialCampaigns = const <Campaign>[],
  }) : _repository = repository,
       _dataSync = dataSync,
       _useCase = useCase ??
           (repository != null ? GetCampaignsUseCase(repository) : null),
       _campaigns = initialCampaigns.isNotEmpty
           ? initialCampaigns
           : (dataSync?.campaigns ?? const <Campaign>[]),
       _isLoading =
           initialCampaigns.isEmpty && (dataSync?.campaigns.isEmpty ?? true) {
    _dataSync?.addListener(_onSyncChanged);
  }

  final ICampaignsRepository? _repository;
  final AppDataSync? _dataSync;
  final GetCampaignsUseCase? _useCase;

  List<Campaign> _campaigns;
  CampaignStatusFilter _filter = CampaignStatusFilter.all;
  Campaign? _focusedCampaign;
  bool _isLoading;
  bool _hasError = false;

  List<Campaign> get campaigns => _campaigns;

  List<Campaign> get filteredCampaigns {
    final GetCampaignsUseCase? uc = _useCase;
    if (uc != null) {
      return uc.filterList(_campaigns, _filter);
    }
    return switch (_filter) {
      CampaignStatusFilter.all => _campaigns,
      CampaignStatusFilter.active =>
        _campaigns.where((Campaign c) => c.isActive).toList(),
      CampaignStatusFilter.upcoming =>
        _campaigns.where((Campaign c) => c.isUpcoming).toList(),
    };
  }

  CampaignStatusFilter get filter => _filter;

  Campaign? get focusedCampaign => _focusedCampaign;

  bool get isLoading => _isLoading;

  bool get hasError => _hasError;


// Methods ------------------------------------------------------------------ //


  void _onSyncChanged() {
    final AppDataSync? sync = _dataSync;
    if (sync != null) {
      _campaigns = sync.campaigns;
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dataSync?.removeListener(_onSyncChanged);
    super.dispose();
  }


  /// Atualiza o conjunto de campanhas e notifica os ouvintes.
  void setCampaigns(List<Campaign> campaigns) {
    _campaigns = campaigns;
    _isLoading = false;
    _hasError = false;
    notifyListeners();
  }

  /// Carrega as campanhas do cache offline.
  Future<void> loadCampaigns() async {
    final ICampaignsRepository? repo = _repository;
    if (repo == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = _campaigns.isEmpty;
    _hasError = false;
    notifyListeners();

    try {
      final List<Campaign> offline = await repo.loadOffline();
      _campaigns = offline;
      _isLoading = false;
      _hasError = false;
      notifyListeners();
    } catch (_) {
      _isLoading = false;
      _hasError = _campaigns.isEmpty;
      notifyListeners();
    }
  }

  /// Atualiza as campanhas a partir da fonte remota.
  Future<void> refreshCampaigns() async {
    final ICampaignsRepository? repo = _repository;
    if (repo == null || !repo.hasRemoteSource) {
      return;
    }

    try {
      final List<Campaign> refreshed = await repo.refresh();
      _campaigns = refreshed;
      _hasError = false;
      notifyListeners();
    } catch (_) {
      if (_campaigns.isEmpty) {
        _hasError = true;
        notifyListeners();
      }
    }
  }

  /// Define o filtro de status ativo.
  void setFilter(CampaignStatusFilter filter) {
    if (_filter != filter) {
      _filter = filter;
      notifyListeners();
    }
  }

  /// Define a campanha focada para navegação no mapa.
  void setFocusedCampaign(Campaign? campaign) {
    if (_focusedCampaign != campaign) {
      _focusedCampaign = campaign;
      notifyListeners();
    }
  }
}
