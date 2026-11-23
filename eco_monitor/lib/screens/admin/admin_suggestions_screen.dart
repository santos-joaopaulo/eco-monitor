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


/// Agrupamento de solicitações cívicas de novos pontos por bairro territorial.
class NeighborhoodDemand {
  NeighborhoodDemand({
    required this.neighborhood,
    required this.suggestions,
  });

  final String neighborhood;
  final List<PointSuggestion> suggestions;

  int get total => suggestions.length;

  Map<WasteType, int> get wasteCounts {
    final Map<WasteType, int> counts = <WasteType, int>{};
    for (final PointSuggestion s in suggestions) {
      for (final WasteType type in s.acceptedWasteTypes) {
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }
    return counts;
  }

  List<MapEntry<WasteType, int>> get topWastes {
    final List<MapEntry<WasteType, int>> entries = wasteCounts.entries.toList()
      ..sort(
        (MapEntry<WasteType, int> a, MapEntry<WasteType, int> b) =>
            b.value.compareTo(a.value),
      );
    return entries;
  }
}

/// Tela de moderação e análise territorial das sugestões enviadas pelos usuários.
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
  bool _showTerritorialView = false;


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

  String _extractNeighborhood(String address) {
    final String trimmed = address.trim();
    if (trimmed.isEmpty) {
      return "Não informado";
    }

    // Padrão com hífen: "Rua X, 123 - Centro, Aracaju" ou "Rua X - Centro"
    if (trimmed.contains(" - ")) {
      final List<String> segments = trimmed.split(" - ");
      if (segments.length >= 2) {
        final String candidate = segments[1].split(",").first.trim();
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
    }

    // Padrão com vírgula: "Rua X, 123, Centro"
    final List<String> commaParts = trimmed.split(",");
    if (commaParts.length >= 3) {
      final String candidate = commaParts[commaParts.length - 2].trim();
      if (candidate.isNotEmpty && !RegExp(r"^\d+$").hasMatch(candidate)) {
        return candidate;
      }
    }

    return trimmed;
  }

  List<NeighborhoodDemand> get _neighborhoodDemands {
    final Map<String, List<PointSuggestion>> grouped =
        <String, List<PointSuggestion>>{};

    for (final PointSuggestion s in _allSuggestions) {
      final String neighborhood = _extractNeighborhood(s.address);
      (grouped[neighborhood] ??= <PointSuggestion>[]).add(s);
    }

    final List<NeighborhoodDemand> demands = grouped.entries
        .map((MapEntry<String, List<PointSuggestion>> entry) {
          return NeighborhoodDemand(
            neighborhood: entry.key,
            suggestions: entry.value,
          );
        })
        .toList();

    demands.sort(
      (NeighborhoodDemand a, NeighborhoodDemand b) =>
          b.total.compareTo(a.total),
    );
    return demands;
  }

  WasteType? get _mostRequestedWasteOverall {
    final Map<WasteType, int> counts = <WasteType, int>{};
    for (final PointSuggestion s in _allSuggestions) {
      for (final WasteType type in s.acceptedWasteTypes) {
        counts[type] = (counts[type] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      return null;
    }
    final List<MapEntry<WasteType, int>> sorted = counts.entries.toList()
      ..sort(
        (MapEntry<WasteType, int> a, MapEntry<WasteType, int> b) =>
            b.value.compareTo(a.value),
      );
    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    final List<PointSuggestion> filtered = _filteredSuggestions;
    final List<NeighborhoodDemand> demands = _neighborhoodDemands;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _showTerritorialView
              ? "DEMANDA TERRITORIAL"
              : "SUGESTÕES DE USUÁRIOS",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showTerritorialView
                  ? Icons.view_list_rounded
                  : Icons.location_city_rounded,
            ),
            tooltip: _showTerritorialView
                ? "Lista de Moderação"
                : "Visão Territorial / Bairros",
            onPressed: () {
              setState(() {
                _showTerritorialView = !_showTerritorialView;
              });
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
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
                : _showTerritorialView
                ? _buildTerritorialView(demands)
                : _buildModerationListView(filtered),
          ),
        ),
      ),
    );
  }

  Widget _buildTerritorialView(List<NeighborhoodDemand> demands) {
    final WasteType? topWaste = _mostRequestedWasteOverall;

    return RefreshIndicator(
      onRefresh: _loadSuggestions,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: kEcoContentHorizontalPadding,
          vertical: 16,
        ),
        children: [
          // Sumário de Demanda Municipal
          Card(
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.outline),
            ),

            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SUMÁRIO TERRITORIAL DE DEMANDA",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${_allSuggestions.length}",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryAccessible,
                              ),
                            ),
                            const Text(
                              "Total de solicitações",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${demands.length}",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryAccessible,
                              ),
                            ),
                            const Text(
                              "Bairros demandantes",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (topWaste != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.outline),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(topWaste.icon, size: 18, color: topWaste.color),
                        const SizedBox(width: 8),

                        Text(
                          "Resíduo mais solicitado: ${topWaste.label}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            "DEMANDA AGREGADA POR BAIRRO",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          if (demands.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Nenhuma demanda territorial registrada.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...demands.map((NeighborhoodDemand item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NeighborhoodDemandCard(
                  demand: item,
                  onConvertSuggestion: _convertToPoint,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildModerationListView(List<PointSuggestion> filtered) {
    return Column(
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
          child: filtered.isEmpty
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
    );
  }
}

class _NeighborhoodDemandCard extends StatelessWidget {
  const _NeighborhoodDemandCard({
    required this.demand,
    required this.onConvertSuggestion,
  });

  final NeighborhoodDemand demand;
  final ValueChanged<PointSuggestion> onConvertSuggestion;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<WasteType, int>> topWastes = demand.topWastes;

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),

      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.primaryTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.location_city_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                demand.neighborhood,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryAccessible.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${demand.total} ${demand.total == 1 ? "solicitação" : "solicitações"}",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryAccessible,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: topWastes.map((MapEntry<WasteType, int> entry) {
              final WasteType type = entry.key;
              final int count = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSection,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type.icon, size: 12, color: type.color),
                    const SizedBox(width: 4),
                    Text(
                      "${type.label} ($count)",
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        children: [
          const Divider(height: 1, color: AppColors.outline),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: demand.suggestions.map((PointSuggestion s) {
                final bool isApproved = s.status == SuggestionStatus.approved;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isApproved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.active.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Aprovado",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.active,
                            ),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () => onConvertSuggestion(s),
                          icon: const Icon(
                            Icons.add_location_alt_outlined,
                            size: 14,
                          ),
                          label: const Text(
                            "Aprovar e Criar",
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
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
