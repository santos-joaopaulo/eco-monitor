import "package:material_ui/material_ui.dart";

import "../data/admin_database_repository.dart";
import "../domain/entities/collection_point.dart";
import "../domain/entities/point_suggestion.dart";
import "../domain/repositories/waste_search_analytics_repository_contract.dart";
import "../domain/entities/civic_demand_summary.dart";
import "../screens/admin/admin_environmental_report_screen.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "waste_style.dart";


// Classes ------------------------------------------------------------------ //


/// Modal Bottom Sheet que apresenta o diagnóstico territorial de demandas cívicas,
/// carência de pontos por bairro e atalho para exportação do relatório ambiental em PDF.
class SuggestionsReportSheet extends StatelessWidget {
  const SuggestionsReportSheet({
    super.key,
    required this.suggestions,
    this.existingPoints = const <CollectionPoint>[],
    this.databaseRepository,
    this.analyticsRepository,
  });

  final List<PointSuggestion> suggestions;
  final List<CollectionPoint> existingPoints;
  final AdminDatabaseRepository? databaseRepository;
  final IWasteSearchAnalyticsRepository? analyticsRepository;


// Factory / Static Methods ------------------------------------------------- //


  /// Exibe o bottom sheet modal de diagnóstico territorial.
  static Future<void> show(
    BuildContext context, {
    required List<PointSuggestion> suggestions,
    List<CollectionPoint> existingPoints = const <CollectionPoint>[],
    AdminDatabaseRepository? databaseRepository,
    IWasteSearchAnalyticsRepository? analyticsRepository,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => SuggestionsReportSheet(
        suggestions: suggestions,
        existingPoints: existingPoints,
        databaseRepository: databaseRepository,
        analyticsRepository: analyticsRepository,
      ),
    );
  }


// Methods ------------------------------------------------------------------ //


  void _openPdfReport(BuildContext context, {String? filterNeighborhood}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminEnvironmentalReportScreen(
          databaseRepository: databaseRepository,
          analyticsRepository: analyticsRepository,
          initialPoints: existingPoints,
          initialSuggestions: suggestions,
          initialNeighborhood: filterNeighborhood,
        ),
      ),
    );
  }

  Color _shortageColor(ShortageLevel level) => switch (level) {
    ShortageLevel.high => AppColors.warningText,
    ShortageLevel.medium => AppColors.medicine,
    ShortageLevel.low => AppColors.active,
  };

  Color _shortageBackgroundColor(ShortageLevel level) => switch (level) {
    ShortageLevel.high => AppColors.warningBackground,
    ShortageLevel.medium => AppColors.primaryTint,
    ShortageLevel.low => AppColors.offlineSurface,
  };

  @override
  Widget build(BuildContext context) {
    final CivicDemandSummary summary = CivicDemandSummary.fromData(
      suggestions: suggestions,
      existingPoints: existingPoints,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),

          child: Column(
            children: [
              // Barra de arraste
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Cabeçalho do modal
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kEcoContentHorizontalPadding,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryTint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assessment_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            "DIAGNÓSTICO TERRITORIAL",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Ranking de Carência Cívica por Bairro",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: "Fechar",
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.outline),

              // Conteúdo rolável
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: kEcoContentHorizontalPadding,
                    vertical: 16,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: kEcoMaxContentWidth,
                        ),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,

                          children: [
                            // Botão proeminente de exportação geral do PDF
                            FilledButton.icon(
                              onPressed: () => _openPdfReport(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                "Exportar Relatório Geral em PDF",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Cartão com métricas consolidadas
                            Card(
                              elevation: 0,
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.outline),
                              ),

                              child: Padding(
                                padding: const EdgeInsets.all(14),

                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatMetric(
                                      label: "Solicitações",
                                      value: "${summary.totalSuggestions}",
                                      color: AppColors.primary,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: AppColors.outline,
                                    ),
                                    _buildStatMetric(
                                      label: "Pendentes",
                                      value: "${summary.pendingCount}",
                                      color: AppColors.warningText,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 36,
                                      color: AppColors.outline,
                                    ),
                                    _buildStatMetric(
                                      label: "Bairros Atendidos",
                                      value:
                                          "${summary.neighborhoodDemands.length}",
                                      color: AppColors.primaryAccessible,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Título da seção de ranking
                            const Text(
                              "PRIORIDADE DE CARÊNCIA TERRITORIAL",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (summary.neighborhoodDemands.isEmpty)
                              Card(
                                elevation: 0,
                                color: AppColors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: AppColors.outline,
                                  ),
                                ),

                                child: const Padding(
                                  padding: EdgeInsets.all(24),

                                  child: Center(
                                    child: Text(
                                      "Nenhuma solicitação cívica registrada.",
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              for (
                                int i = 0;
                                i < summary.neighborhoodDemands.length;
                                i++
                              )
                                _buildNeighborhoodCard(
                                  context: context,
                                  rank: i + 1,
                                  demand: summary.neighborhoodDemands[i],
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildNeighborhoodCard({
    required BuildContext context,
    required int rank,
    required NeighborhoodCivicDemand demand,
  }) {
    final Color badgeColor = _shortageColor(demand.shortageLevel);
    final Color badgeBg = _shortageBackgroundColor(demand.shortageLevel);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
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
              children: [
                // Indicador de Posição
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "$rankº",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    demand.neighborhood,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                // Selo de Carência
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withAlpha(80)),
                  ),
                  child: Text(
                    demand.shortageLevelLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Métricas da localidade
            Wrap(
              spacing: 12,
              runSpacing: 4,

              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.send_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${demand.totalSuggestions} pedido(s) (${demand.pendingCount} pendente(s))",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${demand.activePointsCount} ponto(s) ativo(s)",
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Chips com percentuais de resíduos mais solicitados
            if (demand.rankedWastes.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,

                children: [
                  for (final CivicWasteDemand item in demand.rankedWastes)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSection,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.type.icon,
                            size: 12,
                            color: item.type.color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${item.type.filterLabel} (${item.percentage.toStringAsFixed(0)}%)",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Botão de atalho em 1 toque para o PDF filtrado deste bairro
            Align(
              alignment: Alignment.centerRight,

              child: TextButton.icon(
                onPressed: () => _openPdfReport(
                  context,
                  filterNeighborhood: demand.neighborhood,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text(
                  "Gerar PDF deste Bairro",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
