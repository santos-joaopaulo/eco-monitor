import "dart:async";

import "package:material_ui/material_ui.dart";

import "../data/app_data_sync.dart";
import "../data/campaigns_repository.dart";
import "../models/campaign.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../widgets/campaign_card.dart";
import "../widgets/campaign_details_sheet.dart";
import "../widgets/custom_bottom_nav_bar.dart";


// Enums ------------------------------------------------------------------- //


/// Chips de filtro de status exibidos no topo da lista de campanhas (RF08).
enum CampaignFilter { all, active, upcoming }


// Classes ----------------------------------------------------------------- //


/// Tela que lista campanhas de coleta ativas e previstas (RF08, RF09).
class EventsScreen extends StatefulWidget {
  const EventsScreen({
    super.key,
    this.repository,
    this.dataSync,
    this.onShowCampaignLocation,
  });

  final CampaignsRepository? repository;
  final AppDataSync? dataSync;

  /// Chamado quando o usuário toca em "Ver local" no card ou no modal de detalhes da campanha.
  final ValueChanged<Campaign>? onShowCampaignLocation;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  CampaignFilter _filter = CampaignFilter.all;
  List<Campaign> _campaigns = const <Campaign>[];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    widget.dataSync?.addListener(_onSyncUpdated);
    unawaited(_loadCampaigns());
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataSync != widget.dataSync) {
      oldWidget.dataSync?.removeListener(_onSyncUpdated);
      widget.dataSync?.addListener(_onSyncUpdated);
      _onSyncUpdated();
    } else if (oldWidget.repository != widget.repository) {
      unawaited(_loadCampaigns());
    }
  }

  @override
  void dispose() {
    widget.dataSync?.removeListener(_onSyncUpdated);
    super.dispose();
  }

  void _onSyncUpdated() {
    final AppDataSync? sync = widget.dataSync;
    if (sync == null || !mounted) {
      return;
    }

    setState(() {
      _campaigns = sync.campaigns;
      if (_campaigns.isNotEmpty || !sync.isSyncing) {
        _isLoading = false;
        _hasError = false;
      }
    });
  }

  Future<void> _loadCampaigns() async {
    final AppDataSync? sync = widget.dataSync;
    if (sync != null && sync.campaigns.isNotEmpty) {
      if (mounted) {
        setState(() {
          _campaigns = sync.campaigns;
          _isLoading = false;
          _hasError = false;
        });
      }
      return;
    }

    final CampaignsRepository? repository =
        widget.repository ?? sync?.campaignsRepository;
    if (repository == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = _campaigns.isEmpty;
        _hasError = false;
      });
    }

    try {
      final List<Campaign> offline = await repository.loadOffline();
      if (!mounted) {
        return;
      }

      setState(() {
        _campaigns = offline;
        _isLoading = false;
        _hasError = false;
      });

      if (sync == null && repository.hasRemoteSource) {
        final List<Campaign> refreshed = await repository.refresh();
        if (mounted) {
          setState(() {
            _campaigns = refreshed;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _campaigns.isEmpty;
        });
      }
    }
  }

  Future<void> _refreshCampaigns() async {
    final AppDataSync? sync = widget.dataSync;
    if (sync != null) {
      await sync.refreshAll();
      return;
    }

    final CampaignsRepository? repository = widget.repository;
    if (repository == null) {
      return;
    }

    try {
      final List<Campaign> refreshed = await repository.refresh();
      if (mounted) {
        setState(() {
          _campaigns = refreshed;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = _campaigns.isEmpty;
        });
      }
    }
  }

  List<Campaign> get _filteredCampaigns {
    return switch (_filter) {
      CampaignFilter.all => _campaigns,
      CampaignFilter.active =>
        _campaigns.where((Campaign c) => c.isActive).toList(),
      CampaignFilter.upcoming =>
        _campaigns.where((Campaign c) => c.isUpcoming).toList(),
    };
  }

  void _openDetails(Campaign campaign) {
    unawaited(
      showCampaignDetailsSheet(
        context: context,
        campaign: campaign,
        onViewLocation: () => _handleViewLocation(campaign),
      ),
    );
  }

  void _handleViewLocation(Campaign campaign) {
    final ValueChanged<Campaign>? callback = widget.onShowCampaignLocation;
    if (callback != null) {
      callback(campaign);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Local: ${campaign.locationName}"),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final List<Campaign> visibleCampaigns = _filteredCampaigns;
    final double bottomInset = CustomBottomNavBar.reservedBottomInset(context);

    return ColoredBox(
      color: AppColors.background,

      child: Align(
        alignment: Alignment.topCenter,

        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kEcoContentHorizontalPadding,
          ),

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

            child: Column(
              children: [
                _FilterChipBar(
                  selected: _filter,
                  onSelected: (CampaignFilter filter) {
                    setState(() {
                      _filter = filter;
                    });
                  },
                ),

                Expanded(
                  child: _buildBody(
                    visibleCampaigns: visibleCampaigns,
                    bottomInset: bottomInset,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<Campaign> visibleCampaigns,
    required double bottomInset,
  }) {
    if (_isLoading && _campaigns.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_hasError && _campaigns.isEmpty) {
      return _FeedbackState(
        icon: Icons.error_outline_rounded,
        title: "Não foi possível carregar as campanhas",
        subtitle: "Verifique sua conexão e tente novamente.",
        actionLabel: "Tentar novamente",
        onAction: _loadCampaigns,
        bottomInset: bottomInset,
      );
    }

    if (visibleCampaigns.isEmpty) {
      final bool hasOtherCampaigns =
          _filter != CampaignFilter.all && _campaigns.isNotEmpty;

      final String emptyTitle = switch (_filter) {
        CampaignFilter.all => "Nenhuma campanha disponível",
        CampaignFilter.active => "Nenhuma campanha ativa no momento",
        CampaignFilter.upcoming => "Nenhuma campanha programada",
      };

      final String emptySubtitle = hasOtherCampaigns
          ? "Experimente alterar o filtro para ver outras campanhas."
          : "Novos mutirões e pontos extras de coleta aparecerão aqui.";

      return _FeedbackState(
        icon: Icons.event_busy_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
        actionLabel: hasOtherCampaigns ? "Ver todas" : "Atualizar",
        onAction: hasOtherCampaigns
            ? () => setState(() => _filter = CampaignFilter.all)
            : _refreshCampaigns,
        bottomInset: bottomInset,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshCampaigns,

      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 56),
        itemCount: visibleCampaigns.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: 16),
        itemBuilder: (BuildContext context, int index) {
          final Campaign campaign = visibleCampaigns[index];

          return CampaignCard(
            campaign: campaign,
            onTap: () => _openDetails(campaign),
            onViewLocation: () => _handleViewLocation(campaign),
          );
        },
      ),
    );
  }
}

class _FilterChipBar extends StatelessWidget {
  const _FilterChipBar({required this.selected, required this.onSelected});

  final CampaignFilter selected;
  final ValueChanged<CampaignFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),

      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,

        child: Row(
          children: [
            Expanded(
              child: _FilterPill(
                label: "Todas",
                icon: Icons.grid_view_rounded,
                selected: selected == CampaignFilter.all,
                onTap: () => onSelected(CampaignFilter.all),
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: _FilterPill(
                label: "Ativas",
                icon: Icons.check_circle_outline_rounded,
                selected: selected == CampaignFilter.active,
                onTap: () => onSelected(CampaignFilter.active),
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: _FilterPill(
                label: "Em breve",
                icon: Icons.schedule_outlined,
                selected: selected == CampaignFilter.upcoming,
                onTap: () => onSelected(CampaignFilter.upcoming),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  static const Color _labelColor = Color(0xFF4A4A4A);

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: selected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),

              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.primary : _labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackState extends StatelessWidget {
  const _FeedbackState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.bottomInset,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 24, 28, bottomInset + 24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.iconTint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryAccessible,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
