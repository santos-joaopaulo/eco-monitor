import "package:material_ui/material_ui.dart";

import "../../data/admin_database_repository.dart";
import "../../data/app_data_sync.dart";
import "../../domain/entities/waste_type.dart";
import "../../models/campaign.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";
import "../../utils/formatters.dart";
import "../../widgets/waste_style.dart";
import "admin_campaign_form_screen.dart";


// Classes ----------------------------------------------------------------- //


/// Tela de listagem e gerenciamento de campanhas e eventos de coleta.
class AdminCampaignsScreen extends StatefulWidget {
  const AdminCampaignsScreen({
    super.key,
    required this.databaseRepository,
    this.dataSync,
  });

  final AdminDatabaseRepository databaseRepository;
  final AppDataSync? dataSync;

  @override
  State<AdminCampaignsScreen> createState() => _AdminCampaignsScreenState();
}

class _AdminCampaignsScreenState extends State<AdminCampaignsScreen> {
  List<Campaign> _allCampaigns = const <Campaign>[];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilterIndex = 0; // 0: Todas, 1: Ativas, 2: Previstas, 3: Encerradas


  // Lifecycle ------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }


  // Methods --------------------------------------------------------------- //


  Future<void> _loadCampaigns() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Campaign> items =
          await widget.databaseRepository.fetchCampaigns();
      if (!mounted) {
        return;
      }
      setState(() {
        _allCampaigns = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = "Erro ao carregar campanhas: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCampaign(Campaign campaign) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Excluir Campanha"),
        content: Text(
          "Tem certeza que deseja excluir a campanha \"${campaign.title}\"?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warningText,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Excluir"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    try {
      await widget.databaseRepository.deleteCampaign(campaign.id);
      if (!mounted) {
        return;
      }
      widget.dataSync?.refreshAll();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Campanha excluída com sucesso.")),
      );
      await _loadCampaigns();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao excluir: $e"),
          backgroundColor: AppColors.warningText,
        ),
      );
    }
  }

  void _openForm({Campaign? campaign}) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => AdminCampaignFormScreen(
          databaseRepository: widget.databaseRepository,
          dataSync: widget.dataSync,
          existingCampaign: campaign,
        ),
      ),
    );

    if (changed == true) {
      await _loadCampaigns();
    }
  }

  List<Campaign> get _filteredCampaigns {
    return _allCampaigns.where((Campaign item) {
      return switch (_selectedFilterIndex) {
        1 => item.status == CampaignStatus.active,
        2 => item.status == CampaignStatus.upcoming,
        3 => item.status == CampaignStatus.finished,
        _ => true,
      };
    }).toList();
  }

  String _statusLabel(CampaignStatus status) {
    return switch (status) {
      CampaignStatus.active => "Ativa",
      CampaignStatus.upcoming => "Prevista",
      CampaignStatus.finished => "Encerrada",
    };
  }

  Color _statusColor(CampaignStatus status) {
    return switch (status) {
      CampaignStatus.active => AppColors.active,
      CampaignStatus.upcoming => AppColors.userLocation,
      CampaignStatus.finished => AppColors.inactive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<Campaign> filtered = _filteredCampaigns;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "CAMPANHAS DE COLETA",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          "Nova Campanha",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

            child: Column(
              children: [
                // Filtros
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: kEcoContentHorizontalPadding,
                    vertical: 12,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: "Todas (${_allCampaigns.length})",
                          isSelected: _selectedFilterIndex == 0,
                          onTap: () => setState(() => _selectedFilterIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Ativas",
                          isSelected: _selectedFilterIndex == 1,
                          onTap: () => setState(() => _selectedFilterIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Previstas",
                          isSelected: _selectedFilterIndex == 2,
                          onTap: () => setState(() => _selectedFilterIndex = 2),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Encerradas",
                          isSelected: _selectedFilterIndex == 3,
                          onTap: () => setState(() => _selectedFilterIndex = 3),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: AppColors.outline),

                // Lista de campanhas
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_off_rounded,
                                  size: 48,
                                  color: AppColors.warningText,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.warningText,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadCampaigns,
                                  child: const Text("Tentar novamente"),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              "Nenhuma campanha encontrada nesta categoria.",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadCampaigns,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.only(
                              left: kEcoContentHorizontalPadding,
                              right: kEcoContentHorizontalPadding,
                              top: 12,
                              bottom: 80,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (BuildContext context, int index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final Campaign item = filtered[index];
                              return _CampaignCard(
                                campaign: item,
                                statusLabel: _statusLabel(item.status),
                                statusColor: _statusColor(item.status),
                                onEdit: () => _openForm(campaign: item),
                                onDelete: () => _deleteCampaign(item),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaign,
    required this.statusLabel,
    required this.statusColor,
    required this.onEdit,
    required this.onDelete,
  });

  final Campaign campaign;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final String start = formatDate(campaign.startDate);
    final String end = formatDate(campaign.endDate);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outline),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Text(
                        campaign.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),

                      Text(
                        campaign.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (String action) {
                    if (action == "edit") {
                      onEdit();
                    } else if (action == "delete") {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: "edit",
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text("Editar"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: "delete",
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.warningText,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Excluir",
                            style: TextStyle(color: AppColors.warningText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  "$start a $end",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "${campaign.locationName} (${campaign.address})",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: campaign.wasteTypes.map((WasteType type) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSection,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    type.label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
