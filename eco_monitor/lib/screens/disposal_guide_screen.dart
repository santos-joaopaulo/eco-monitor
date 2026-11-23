import "dart:async";

import "package:material_ui/material_ui.dart";

import "../data/waste_search_analytics_repository.dart";
import "../domain/entities/residue.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "../domain/repositories/waste_search_analytics_repository_contract.dart";
import "../services/residue_search_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/eco_app_bar.dart";
import "../widgets/residue_card.dart";
import "../widgets/waste_style.dart";


// Screens ----------------------------------------------------------------- //


/// Tela 1: listagem de resíduos com busca textual, ranking comunitário e início de guia.
class DisposalGuideScreen extends StatefulWidget {
  const DisposalGuideScreen({
    super.key,
    required this.repository,
    required this.onStartGuide,
    this.banner,
    this.analyticsRepository,
    this.searchService = const ResidueSearchService(),
    this.onShowCollectionPoints,
  });

  final DisposalGuideRepository repository;
  final ValueChanged<Residue> onStartGuide;
  final Widget? banner;
  final IWasteSearchAnalyticsRepository? analyticsRepository;
  final ResidueSearchService searchService;
  final ValueChanged<WasteType>? onShowCollectionPoints;

  @override
  State<DisposalGuideScreen> createState() => _DisposalGuideScreenState();
}

class _DisposalGuideScreenState extends State<DisposalGuideScreen> {
  late final TextEditingController _searchController;
  late final IWasteSearchAnalyticsRepository _analytics;

  List<WasteSearchStat> _stats = const <WasteSearchStat>[];
  String _searchQuery = "";
  bool _isLoadingStats = true;


  // Init ------------------------------------------------------------------ //


  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _analytics =
        widget.analyticsRepository ?? WasteSearchAnalyticsRepository();
    unawaited(_loadStats());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final List<WasteSearchStat> loaded = await _analytics.getRankedStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = loaded;
        _isLoadingStats = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = "";
    });
  }

  void _handleStartGuide(Residue residue) {
    unawaited(_analytics.recordSearch(residue.type));
    widget.onStartGuide(residue);
  }

  void _handleShowOnMap(WasteType type) {
    unawaited(_analytics.recordSearch(type));
    widget.onShowCollectionPoints?.call(type);
  }


  // Build ----------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final List<Residue> allResidues = widget.repository.listResidues();
    final List<WasteTypeSearchResult> searchResults =
        _searchQuery.isNotEmpty
            ? widget.searchService.search(_searchQuery)
            : const <WasteTypeSearchResult>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const EcoAppBar(title: "GUIA DE DESCARTE"),
      body: Column(
        children: [
          ?widget.banner,

          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kEcoContentHorizontalPadding,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kEcoMaxContentWidth,
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      16,
                      0,
                      CustomBottomNavBar.reservedBottomInset(context) + 56,
                    ),
                    children: [
                      _SearchBar(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onClear: _clearSearch,
                      ),
                      const SizedBox(height: 16),

                      if (_searchQuery.isNotEmpty) ...[
                        _SearchResultsHeader(
                          query: _searchQuery,
                          resultCount: searchResults.length,
                        ),
                        const SizedBox(height: 12),

                        if (searchResults.isEmpty)
                          _EmptySearchState(query: _searchQuery)
                        else
                          for (final WasteTypeSearchResult result
                              in searchResults) ...[
                            _SearchResultCard(
                              result: result,
                              residue: allResidues.firstWhere(
                                (Residue r) => r.type == result.type,
                                orElse: () => Residue(
                                  type: result.type,
                                  title: result.type.label,
                                  description: "",
                                  minutes: 2,
                                  totalSteps: 4,
                                ),
                              ),
                              onStart: _handleStartGuide,
                              onShowMap:
                                  widget.onShowCollectionPoints != null
                                      ? () => _handleShowOnMap(result.type)
                                      : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                      ] else ...[
                        if (!_isLoadingStats && _stats.isNotEmpty) ...[
                          _PopularSearchesSection(
                            stats: _stats,
                            onSelectWasteType: (WasteType type) {
                              final Residue? residue = allResidues
                                  .where((Residue r) => r.type == type)
                                  .firstOrNull;
                              if (residue != null) {
                                _handleStartGuide(residue);
                              } else {
                                _handleShowOnMap(type);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        const _Header(),
                        const SizedBox(height: 20),

                        for (final Residue residue in allResidues) ...[
                          ResidueCard(
                            icon: residue.type.icon,
                            iconColor: residue.type.color,
                            title: residue.title,
                            description: residue.description,
                            buttonLabel: "Iniciar",
                            info:
                                "${residue.minutes} min · ${residue.totalSteps} passos",
                            infoWithClock: true,
                            onPressed: () => _handleStartGuide(residue),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// Widgets auxiliares ------------------------------------------------------ //


class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: "Buscar tipo de resíduo",
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),

        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: "Buscar resíduo (ex.: paracetamol, pilha)...",
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    tooltip: "Limpar busca",
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularSearchesSection extends StatelessWidget {
  const _PopularSearchesSection({
    required this.stats,
    required this.onSelectWasteType,
  });

  final List<WasteSearchStat> stats;
  final ValueChanged<WasteType> onSelectWasteType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 20,
                color: AppColors.primaryAccessible,
              ),
              SizedBox(width: 8),
              Text(
                "Resíduos mais pesquisados",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Categorias mais consultadas pelos cidadãos.",
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stats.map((WasteSearchStat stat) {
            final int pct = stat.percentage.round();

            return Semantics(
              button: true,
              label:
                  "Ver orientações de ${stat.type.label}, $pct por cento das buscas",
              child: InkWell(
                onTap: () => onSelectWasteType(stat.type),
                borderRadius: BorderRadius.circular(20),

                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: stat.type.color.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),

                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stat.type.icon,
                        size: 16,
                        color: stat.type.color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${stat.type.filterLabel} $pct%",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SearchResultsHeader extends StatelessWidget {
  const _SearchResultsHeader({
    required this.query,
    required this.resultCount,
  });

  final String query;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Resultados para "$query"',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          resultCount == 1 ? "1 categoria" : "$resultCount categorias",
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.result,
    required this.residue,
    required this.onStart,
    this.onShowMap,
  });

  final WasteTypeSearchResult result;
  final Residue residue;
  final ValueChanged<Residue> onStart;
  final VoidCallback? onShowMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Icon(
                  result.type.icon,
                  color: result.type.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      residue.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Termo: "${result.matchedTerm}"',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryAccessible,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            residue.description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text(
                    "Iniciar guia",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => onStart(residue),
                ),
              ),

              if (onShowMap != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryAccessible,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: const Icon(Icons.location_on_outlined, size: 16),
                  label: const Text(
                    "Ver no mapa",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: onShowMap,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),

      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Nenhum resíduo encontrado para "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tente pesquisar por medicamentos (paracetamol, xarope), pilhas, baterias, seringas, eletrônicos ou frascos de vidro.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            "Como descartar certo?",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Escolha o material e siga o passo a passo antes de levar ao ponto de coleta.",
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
