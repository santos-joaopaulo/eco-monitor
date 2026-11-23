import "package:material_ui/material_ui.dart";

import "../../data/admin_database_repository.dart";
import "../../data/app_data_sync.dart";
import "../../domain/entities/waste_type.dart";
import "../../models/point_suggestion.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";
import "../../utils/formatters.dart";
import "../../widgets/waste_style.dart";
import "admin_point_form_screen.dart";


// Classes ----------------------------------------------------------------- //


/// Tela de moderação das sugestões anônimas de pontos enviadas pelos usuários.
class AdminSuggestionsScreen extends StatefulWidget {
  const AdminSuggestionsScreen({
    super.key,
    required this.databaseRepository,
    this.dataSync,
  });

  final AdminDatabaseRepository databaseRepository;
  final AppDataSync? dataSync;

  @override
  State<AdminSuggestionsScreen> createState() => _AdminSuggestionsScreenState();
}

class _AdminSuggestionsScreenState extends State<AdminSuggestionsScreen> {
  List<PointSuggestion> _allSuggestions = const <PointSuggestion>[];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilterIndex = 0; // 0: Todas, 1: Pendentes, 2: Em análise, 3: Aprovadas, 4: Rejeitadas


  // Lifecycle ------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }


  // Methods --------------------------------------------------------------- //


  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<PointSuggestion> items =
          await widget.databaseRepository.fetchSuggestions();
      if (!mounted) {
        return;
      }
      setState(() {
        _allSuggestions = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = "Erro ao carregar sugestões: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _changeStatus(
    PointSuggestion suggestion,
    SuggestionStatus newStatus,
  ) async {
    try {
      await widget.databaseRepository.updateSuggestionStatus(
        suggestion.id,
        newStatus,
      );
      await _loadSuggestions();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao alterar status: $e"),
          backgroundColor: AppColors.warningText,
        ),
      );
    }
  }

  Future<void> _deleteSuggestion(PointSuggestion suggestion) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Excluir Sugestão"),
        content: Text(
          "Deseja excluir a sugestão \"${suggestion.name}\"? Esta ação é irreversível.",
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
      await widget.databaseRepository.deleteSuggestion(suggestion.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sugestão excluída com sucesso.")),
      );
      await _loadSuggestions();
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

  void _convertToPoint(PointSuggestion suggestion) async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => AdminPointFormScreen(
          databaseRepository: widget.databaseRepository,
          dataSync: widget.dataSync,
          fromSuggestion: suggestion,
        ),
      ),
    );

    if (created == true) {
      await _loadSuggestions();
    }
  }

  List<PointSuggestion> get _filteredSuggestions {
    return _allSuggestions.where((PointSuggestion item) {
      return switch (_selectedFilterIndex) {
        1 => item.status == SuggestionStatus.pending,
        2 => item.status == SuggestionStatus.reviewing,
        3 => item.status == SuggestionStatus.approved,
        4 => item.status == SuggestionStatus.rejected,
        _ => true,
      };
    }).toList();
  }

  String _statusLabel(SuggestionStatus status) {
    return switch (status) {
      SuggestionStatus.pending => "Pendente",
      SuggestionStatus.reviewing => "Em análise",
      SuggestionStatus.approved => "Aprovado",
      SuggestionStatus.rejected => "Rejeitado",
    };
  }

  Color _statusColor(SuggestionStatus status) {
    return switch (status) {
      SuggestionStatus.pending => AppColors.medicine,
      SuggestionStatus.reviewing => AppColors.userLocation,
      SuggestionStatus.approved => AppColors.active,
      SuggestionStatus.rejected => AppColors.inactive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<PointSuggestion> filtered = _filteredSuggestions;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "SUGESTÕES DE USUÁRIOS",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
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
                          label: "Todas (${_allSuggestions.length})",
                          isSelected: _selectedFilterIndex == 0,
                          onTap: () => setState(() => _selectedFilterIndex = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Pendentes",
                          isSelected: _selectedFilterIndex == 1,
                          onTap: () => setState(() => _selectedFilterIndex = 1),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Em análise",
                          isSelected: _selectedFilterIndex == 2,
                          onTap: () => setState(() => _selectedFilterIndex = 2),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Aprovadas",
                          isSelected: _selectedFilterIndex == 3,
                          onTap: () => setState(() => _selectedFilterIndex = 3),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: "Rejeitadas",
                          isSelected: _selectedFilterIndex == 4,
                          onTap: () => setState(() => _selectedFilterIndex = 4),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: AppColors.outline),

                // Lista de sugestões
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
                                  onPressed: _loadSuggestions,
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
                              "Nenhuma sugestão encontrada nesta categoria.",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSuggestions,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kEcoContentHorizontalPadding,
                              vertical: 12,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (BuildContext context, int index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final PointSuggestion item = filtered[index];
                              return _SuggestionCard(
                                suggestion: item,
                                statusLabel: _statusLabel(item.status),
                                statusColor: _statusColor(item.status),
                                onConvert: () => _convertToPoint(item),
                                onChangeStatus: (SuggestionStatus newStatus) =>
                                    _changeStatus(item, newStatus),
                                onDelete: () => _deleteSuggestion(item),
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

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.statusLabel,
    required this.statusColor,
    required this.onConvert,
    required this.onChangeStatus,
    required this.onDelete,
  });

  final PointSuggestion suggestion;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onConvert;
  final ValueChanged<SuggestionStatus> onChangeStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                        suggestion.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),

                      Text(
                        suggestion.address,
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
                    if (action == "pending") {
                      onChangeStatus(SuggestionStatus.pending);
                    } else if (action == "reviewing") {
                      onChangeStatus(SuggestionStatus.reviewing);
                    } else if (action == "approved") {
                      onChangeStatus(SuggestionStatus.approved);
                    } else if (action == "rejected") {
                      onChangeStatus(SuggestionStatus.rejected);
                    } else if (action == "delete") {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      enabled: false,
                      child: Text(
                        "MUDAR STATUS",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const PopupMenuItem(
                      value: "pending",
                      child: Text("Marcar como Pendente"),
                    ),
                    const PopupMenuItem(
                      value: "reviewing",
                      child: Text("Marcar como Em análise"),
                    ),
                    const PopupMenuItem(
                      value: "approved",
                      child: Text("Marcar como Aprovado"),
                    ),
                    const PopupMenuItem(
                      value: "rejected",
                      child: Text("Marcar como Rejeitado"),
                    ),
                    const PopupMenuDivider(),
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

            if (suggestion.hours.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      suggestion.hours,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],

            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: suggestion.acceptedWasteTypes.map((WasteType type) {
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
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Enviado em ${formatDate(suggestion.createdAt)}",
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),

                if (suggestion.status != SuggestionStatus.approved)
                  ElevatedButton.icon(
                    onPressed: onConvert,
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                    label: const Text(
                      "Criar Ponto",
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
