import "package:material_ui/material_ui.dart";

import "../../data/admin_database_repository.dart";
import "../../data/app_data_sync.dart";
import "../../domain/entities/waste_type.dart";
import "../../domain/entities/collection_point.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";
import "../../widgets/waste_style.dart";
import "admin_point_form_screen.dart";


// Classes ------------------------------------------------------------------ //


/// Tela de listagem e gerenciamento de pontos de coleta cadastrados no Firestore.
class AdminPointsScreen extends StatefulWidget {
  const AdminPointsScreen({
    super.key,
    required this.databaseRepository,
    this.dataSync,
  });

  final AdminDatabaseRepository databaseRepository;
  final AppDataSync? dataSync;

  @override
  State<AdminPointsScreen> createState() => _AdminPointsScreenState();
}

class _AdminPointsScreenState extends State<AdminPointsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<CollectionPoint> _allPoints = const <CollectionPoint>[];
  bool _isLoading = true;
  String? _errorMessage;
  int _statusFilterIndex = 0; // 0: Todos, 1: Ativos, 2: Inativos


// Lifecycle ---------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


// Methods ------------------------------------------------------------------ //


  Future<void> _loadPoints() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<CollectionPoint> points =
          await widget.databaseRepository.fetchPoints();
      if (!mounted) {
        return;
      }
      setState(() {
        _allPoints = points;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = "Erro ao carregar pontos: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePointStatus(CollectionPoint point) async {
    final PointStatus newStatus = point.isActive
        ? PointStatus.inactive
        : PointStatus.active;

    final CollectionPoint updated = CollectionPoint(
      id: point.id,
      name: point.name,
      type: point.type,
      latitude: point.latitude,
      longitude: point.longitude,
      address: point.address,
      acceptedWasteTypes: point.acceptedWasteTypes,
      hours: point.hours,
      status: newStatus,
    );

    try {
      await widget.databaseRepository.savePoint(updated);
      widget.dataSync?.refreshAll();
      await _loadPoints();
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

  Future<void> _deletePoint(CollectionPoint point) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Excluir Ponto"),
        content: Text(
          "Tem certeza que deseja excluir o ponto \"${point.name}\"? Esta ação não pode ser desfeita.",
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
      await widget.databaseRepository.deletePoint(point.id);
      await widget.dataSync?.refreshAll(forceFullPoints: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ponto excluído com sucesso.")),
      );
      await _loadPoints();
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

  void _openForm({CollectionPoint? point}) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => AdminPointFormScreen(
          databaseRepository: widget.databaseRepository,
          dataSync: widget.dataSync,
          existingPoint: point,
        ),
      ),
    );

    if (changed == true) {
      await _loadPoints();
    }
  }

  List<CollectionPoint> get _filteredPoints {
    final String query = _searchController.text.trim().toLowerCase();

    return _allPoints.where((CollectionPoint point) {
      if (_statusFilterIndex == 1 && !point.isActive) {
        return false;
      }
      if (_statusFilterIndex == 2 && point.isActive) {
        return false;
      }

      if (query.isNotEmpty) {
        final bool matchesName = point.name.toLowerCase().contains(query);
        final bool matchesAddress = point.address.toLowerCase().contains(query);
        return matchesName || matchesAddress;
      }

      return true;
    }).toList();
  }

  String _formatPointType(PointType type) {
    return switch (type) {
      PointType.pharmacy => "Farmácia",
      PointType.healthCenter => "UBS",
      PointType.ecoPoint => "Ecoponto",
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<CollectionPoint> filtered = _filteredPoints;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        title: const Text(
          "PONTOS DE COLETA",
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
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text(
          "Novo Ponto",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

            child: Column(
              children: [
                // Barra de pesquisa e filtro
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: kEcoContentHorizontalPadding,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: "Buscar por nome ou endereço...",
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.outline),
                          ),
                          filled: true,
                          fillColor: AppColors.background,
                        ),
                      ),
                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,

                        child: Row(
                          children: [
                            _FilterChip(
                              label: "Todos (${_allPoints.length})",
                              isSelected: _statusFilterIndex == 0,
                              onTap: () => setState(() => _statusFilterIndex = 0),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: "Ativos",
                              isSelected: _statusFilterIndex == 1,
                              onTap: () => setState(() => _statusFilterIndex = 1),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: "Inativos",
                              isSelected: _statusFilterIndex == 2,
                              onTap: () => setState(() => _statusFilterIndex = 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: AppColors.outline),

                // Lista de pontos
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
                                  onPressed: _loadPoints,
                                  child: const Text("Tentar novamente"),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),

                            child: Text(
                              _searchController.text.isNotEmpty
                                  ? "Nenhum ponto encontrado para o termo pesquisado."
                                  : "Nenhum ponto de coleta cadastrado.",
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadPoints,
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
                                const SizedBox(height: 10),
                            itemBuilder: (BuildContext context, int index) {
                              final CollectionPoint point = filtered[index];
                              return _AdminPointCard(
                                point: point,
                                typeLabel: _formatPointType(point.type),
                                onToggleStatus: () => _togglePointStatus(point),
                                onEdit: () => _openForm(point: point),
                                onDelete: () => _deletePoint(point),
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

class _AdminPointCard extends StatelessWidget {
  const _AdminPointCard({
    required this.point,
    required this.typeLabel,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
  });

  final CollectionPoint point;
  final String typeLabel;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
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
        padding: const EdgeInsets.all(14),

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
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,

                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryAccessible,
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: point.isActive
                                  ? AppColors.primaryTint
                                  : AppColors.inactiveBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              point.isActive ? "Ativo" : "Inativo",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: point.isActive
                                    ? AppColors.active
                                    : AppColors.inactive,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Text(
                        point.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),

                      Text(
                        point.address,
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
                    } else if (action == "toggle") {
                      onToggleStatus();
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
                    PopupMenuItem(
                      value: "toggle",
                      child: Row(
                        children: [
                          Icon(
                            point.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(point.isActive ? "Desativar" : "Ativar"),
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
            const SizedBox(height: 10),

            Wrap(
              spacing: 6,
              runSpacing: 4,

              children: point.acceptedWasteTypes.map((WasteType type) {
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
