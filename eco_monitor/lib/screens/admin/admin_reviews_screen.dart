import "package:material_ui/material_ui.dart";

import "../../data/admin_database_repository.dart";
import "../../data/app_data_sync.dart";
import "../../domain/entities/point_review.dart";
import "../../models/collection_point.dart";
import "../../theme/app_colors.dart";
import "../../theme/eco_theme.dart";
import "../../utils/formatters.dart";


// Classes ----------------------------------------------------------------- //


/// Tela de gestão e moderação das avaliações e reportes enviados pelos cidadãos.
class AdminReviewsScreen extends StatefulWidget {
  const AdminReviewsScreen({
    super.key,
    required this.databaseRepository,
    this.dataSync,
    this.initialPointId,
  });

  final AdminDatabaseRepository databaseRepository;
  final AppDataSync? dataSync;
  final String? initialPointId;

  @override
  State<AdminReviewsScreen> createState() => _AdminReviewsScreenState();
}

class _AdminReviewsScreenState extends State<AdminReviewsScreen> {
  List<PointReview> _allReviews = const <PointReview>[];
  List<CollectionPoint> _points = const <CollectionPoint>[];
  List<CollectionPoint> _criticalPoints = const <CollectionPoint>[];

  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedPointId;
  String? _selectedTag;
  int? _selectedRating; // 1 a 5 ou null para todas


  // Lifecycle ------------------------------------------------------------- //


  @override
  void initState() {
    super.initState();
    _selectedPointId = widget.initialPointId;
    _loadData();
  }


  // Methods --------------------------------------------------------------- //


  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<PointReview> reviews =
          await widget.databaseRepository.fetchReviews();
      final List<CollectionPoint> points =
          await widget.databaseRepository.fetchPoints();
      final List<CollectionPoint> critical =
          await widget.databaseRepository.fetchPointsWithCriticalReports();

      if (!mounted) {
        return;
      }

      setState(() {
        _allReviews = reviews;
        _points = points;
        _criticalPoints = critical;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = "Erro ao carregar avaliações: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteReview(PointReview review) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Moderar Avaliação"),
        content: const Text(
          "Deseja remover este reporte de avaliação? Esta ação deve ser realizada após a apuração ou resolução do incidente.",
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
            child: const Text("Remover"),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    try {
      await widget.databaseRepository.deleteReview(review.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Avaliação removida com sucesso.")),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao remover avaliação: $e"),
          backgroundColor: AppColors.warningText,
        ),
      );
    }
  }

  List<PointReview> get _filteredReviews {
    return _allReviews.where((PointReview item) {
      if (_selectedPointId != null && item.pointId != _selectedPointId) {
        return false;
      }
      if (_selectedRating != null && item.rating != _selectedRating) {
        return false;
      }
      if (_selectedTag != null && !item.tags.contains(_selectedTag)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _pointName(String pointId) {
    for (final CollectionPoint p in _points) {
      if (p.id == pointId) {
        return p.name;
      }
    }
    return "Ponto #$pointId";
  }

  @override
  Widget build(BuildContext context) {
    final List<PointReview> filtered = _filteredReviews;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "AVALIAÇÕES E REPORTES",
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
                // Banner de Pontos Críticos
                if (_criticalPoints.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: kEcoContentHorizontalPadding,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warningText.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warningText,
                          size: 24,
                        ),
                        const SizedBox(width: 10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Atenção: ${_criticalPoints.length} ecoponto(s) com múltiplos reportes críticos de \"Coletor cheio\"",
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warningText,
                                ),
                              ),
                              const SizedBox(height: 4),

                              Wrap(
                                spacing: 6,
                                children: _criticalPoints.map((
                                  CollectionPoint p,
                                ) {
                                  final bool isSelected =
                                      _selectedPointId == p.id;
                                  return ActionChip(
                                    label: Text(p.name),
                                    backgroundColor: isSelected
                                        ? AppColors.warningText
                                        : Colors.white,
                                    labelStyle: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.warningText,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedPointId = isSelected
                                            ? null
                                            : p.id;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Filtros de busca
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: kEcoContentHorizontalPadding,
                    vertical: 10,
                  ),
                  child: Column(
                    children: [
                      // Seletor de Ponto de Coleta
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: "Filtrar por Ecoponto",
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedPointId,
                            isDense: true,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text("Todos os Ecopontos"),
                              ),
                              ..._points.map((CollectionPoint p) {
                                return DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (String? val) {
                              setState(() {
                                _selectedPointId = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Chips de Filtro por Tag
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _ReviewFilterChip(
                              label: "Todas as tags",
                              isSelected: _selectedTag == null,
                              onTap: () => setState(() => _selectedTag = null),
                            ),

                            ...PointReviewTags.all.map((String tag) {
                              final bool isSelected = _selectedTag == tag;
                              return _ReviewFilterChip(
                                label: tag,
                                isSelected: isSelected,
                                onTap: () => setState(() {
                                  _selectedTag = isSelected ? null : tag;
                                }),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Chips de Filtro por Nota
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _ReviewFilterChip(
                              label: "Todas as notas",
                              isSelected: _selectedRating == null,
                              onTap: () =>
                                  setState(() => _selectedRating = null),
                            ),

                            ...[1, 2, 3, 4, 5].map((int star) {
                              final bool isSelected = _selectedRating == star;
                              return _ReviewFilterChip(
                                label: "$star ★",
                                isSelected: isSelected,
                                onTap: () => setState(() {
                                  _selectedRating = isSelected ? null : star;
                                }),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.outline,
                ),

                // Lista de avaliações
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
                                  onPressed: _loadData,
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
                              "Nenhuma avaliação encontrada com os filtros selecionados.",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: kEcoContentHorizontalPadding,
                              vertical: 12,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final PointReview item = filtered[index];
                              return _ReviewCard(
                                review: item,
                                pointName: _pointName(item.pointId),
                                onDelete: () => _deleteReview(item),
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

class _ReviewFilterChip extends StatelessWidget {
  const _ReviewFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.pointName,
    required this.onDelete,
  });

  final PointReview review;
  final String pointName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool hasCriticalTag = review.tags.contains(
      PointReviewTags.fullCollector,
    );

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasCriticalTag
              ? AppColors.warningText.withAlpha(80)
              : AppColors.outline,
        ),
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
                      Text(
                        pointName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Row(
                        children: [
                          ...List.generate(5, (int i) {
                            final bool filled = i < review.rating;
                            return Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 18,
                              color: filled
                                  ? AppColors.ratingStar
                                  : AppColors.ratingStarEmpty,
                            );
                          }),
                          const SizedBox(width: 8),

                          Text(
                            "${review.rating}.0",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.warningText,
                    size: 20,
                  ),
                  tooltip: "Remover avaliação",
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (review.tags.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: review.tags.map((String tag) {
                  final bool isAlert = tag == PointReviewTags.fullCollector;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isAlert
                          ? AppColors.warningBackground
                          : AppColors.surfaceSection,
                      borderRadius: BorderRadius.circular(6),
                      border: isAlert
                          ? Border.all(
                              color: AppColors.warningText.withAlpha(60),
                            )
                          : null,
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isAlert
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isAlert
                            ? AppColors.warningText
                            : AppColors.textSecondary,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            if (review.comment.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "\"${review.comment}\"",
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Enviada em ${formatDate(review.createdAt)}",
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
