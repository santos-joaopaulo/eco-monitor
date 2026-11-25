import "package:material_ui/material_ui.dart";

import "../domain/entities/waste_type.dart";
import "../domain/entities/campaign.dart";
import "../services/residue_search_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "../utils/spatial_index.dart";
import "filter_bar.dart";
import "radius_filter_bar.dart";
import "waste_style.dart";


// Home map top bar --------------------------------------------------------- //


/// Barra superior flutuante do mapa: filtros por categorias de resíduos e raio de busca.
///
/// O seletor de categorias e o seletor de raio formam uma área compacta de ~80px de altura
/// combinada, desobstruindo a visualização da malha viária e dos ecopontos no mapa.
class HomeMapTopBar extends StatelessWidget {
  const HomeMapTopBar({
    super.key,
    required this.selectedWasteTypes,
    required this.onFilterChanged,
    required this.showMapboxTokenWarning,
    required this.isLoadingPoints,
    required this.isEmptyResult,
    required this.emptyMessage,
    required this.locationNotice,
    required this.isListMode,
    this.isFavoritesOnly = false,
    this.onFavoritesToggle,
    this.selectedRadius = ProximityRadius.fiveKm,
    this.onRadiusChanged,
    this.isRadiusEmpty = false,
    this.onExpandRadius,
    this.isSearchActive = false,
    this.onSearchActiveChanged,
    this.onResidueSearched,
    this.searchService = const ResidueSearchService(),
    this.onSearchClose,
    this.focusedCampaign,
    this.onClearCampaign,
    this.onQuickNearestPoint,
    this.nearestDistanceMeters,
    this.showQuickAction = true,
    this.offlineBanner,
  });

  final Set<WasteType> selectedWasteTypes;
  final ValueChanged<Set<WasteType>> onFilterChanged;
  final bool showMapboxTokenWarning;
  final bool isLoadingPoints;
  final bool isEmptyResult;
  final String emptyMessage;
  final Widget? locationNotice;
  final bool isListMode;
  final bool isFavoritesOnly;
  final VoidCallback? onFavoritesToggle;

  /// Raio de proximidade atualmente ativo (T11.1).
  final ProximityRadius selectedRadius;

  /// Callback de alteração de raio de proximidade configurável (T11.1).
  final ValueChanged<ProximityRadius>? onRadiusChanged;

  /// Indica que nenhum ponto atende ao raio ativo, exibindo botão de expansão (T11.1).
  final bool isRadiusEmpty;

  /// Ação rápida de 1 toque para expandir a busca quando o raio estiver vazio (T11.1).
  final VoidCallback? onExpandRadius;

  /// Indica se a busca textual está em foco ou ativa na tela.
  final bool isSearchActive;

  /// Notifica quando o estado de foco/atividade da busca textual se altera.
  final ValueChanged<bool>? onSearchActiveChanged;

  /// Callback de encerramento da busca.
  final VoidCallback? onSearchClose;

  /// Chamado quando o usuário busca e seleciona um resíduo pela busca rápida.
  final ValueChanged<WasteType>? onResidueSearched;

  /// Serviço de catálogo e sinônimos de resíduos.
  final ResidueSearchService searchService;

  final Campaign? focusedCampaign;
  final VoidCallback? onClearCampaign;
  final VoidCallback? onQuickNearestPoint;
  final double? nearestDistanceMeters;
  final bool showQuickAction;
  final Widget? offlineBanner;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,

      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kEcoContentHorizontalPadding,
          6,
          kEcoContentHorizontalPadding,
          0,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            ?offlineBanner,

            if (isSearchActive) ...[
              HomeSearchBar(
                searchService: searchService,
                autofocus: true,
                onSelectWasteType: onResidueSearched,
                onActiveChanged: onSearchActiveChanged,
                onClose: onSearchClose,
              ),
            ] else ...[
              // Barra de filtros por chips
              FilterBar(
                selectedTypes: selectedWasteTypes,
                onChanged: onFilterChanged,
                isFavoritesOnly: isFavoritesOnly,
                onFavoritesToggle: onFavoritesToggle,
              ),

              // Controle de raio de proximidade configurável com espaçamento compacto (~80px altura combinada)
              const SizedBox(height: 6),
              RadiusFilterBar(
                selectedRadius: selectedRadius,
                onChanged: onRadiusChanged ?? (_) {},
              ),
            ],

            // Aviso amigável quando nenhum ecoponto é localizado no raio selecionado (T11.1)
            if (isRadiusEmpty && onExpandRadius != null) ...[
              const SizedBox(height: 6),
              EmptyRadiusNoticePill(
                radius: selectedRadius,
                onExpand: onExpandRadius!,
              ),
            ],

            if (showMapboxTokenWarning) ...[
              const SizedBox(height: 6),
              const _MapStatusPill(
                message: "Configure o token do Mapbox",
                icon: Icons.info_outline,
              ),
            ],

            if (isLoadingPoints) ...[
              const SizedBox(height: 6),
              const _MapStatusPill(
                message: "Carregando pontos...",
                isLoading: true,
              ),
            ] else if (!isListMode && isEmptyResult && !isRadiusEmpty) ...[
              // Suprime _MapStatusPill redundante se isRadiusEmpty já estiver ativo
              const SizedBox(height: 6),
              _MapStatusPill(
                message: emptyMessage,
                icon: Icons.location_off_outlined,
              ),
            ],

            if (locationNotice != null) ...[
              const SizedBox(height: 6),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kEcoMaxContentWidth,
                  ),
                  child: locationNotice,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// Classes ------------------------------------------------------------------ //


/// Campo de busca textual expansível sob demanda para consulta rápida de resíduos no mapa.
class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({
    super.key,
    this.searchService = const ResidueSearchService(),
    this.onSelectWasteType,
    this.onActiveChanged,
    this.onClose,
    this.autofocus = true,
  });

  final ResidueSearchService searchService;
  final ValueChanged<WasteType>? onSelectWasteType;
  final ValueChanged<bool>? onActiveChanged;
  final VoidCallback? onClose;
  final bool autofocus;

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<WasteTypeSearchResult> _results = const <WasteTypeSearchResult>[];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _onFocusChanged() {
    final bool hasFocus = _focusNode.hasFocus;
    widget.onActiveChanged?.call(hasFocus);
    if (!hasFocus && _controller.text.isEmpty && _isOpen) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  void _onQueryChanged(String query) {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const <WasteTypeSearchResult>[];
        _isOpen = false;
      });
      return;
    }

    final List<WasteTypeSearchResult> matches = widget.searchService.search(
      trimmed,
    );
    setState(() {
      _results = matches;
      _isOpen = matches.isNotEmpty;
    });
  }

  void _selectResult(WasteType type) {
    widget.onSelectWasteType?.call(type);
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _results = const <WasteTypeSearchResult>[];
      _isOpen = false;
    });
    FocusScope.of(context).unfocus();
    widget.onClose?.call();
    widget.onActiveChanged?.call(false);
  }

  void _clearSearch() {
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _results = const <WasteTypeSearchResult>[];
      _isOpen = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _handleClose() {
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
    widget.onClose?.call();
    widget.onActiveChanged?.call(false);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            textField: true,
            label: "Buscar resíduo no mapa",

            child: Material(
              elevation: 4,
              shadowColor: Colors.black.withAlpha(45),
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surface,

              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (String value) {
                  final WasteType? match = widget.searchService
                      .matchSingleWasteType(value);
                  if (match != null) {
                    _selectResult(match);
                  }
                },
                decoration: InputDecoration(
                  hintText: "Buscar resíduo (ex.: pilha, xarope)...",
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    tooltip: "Fechar busca",
                    onPressed: _handleClose,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: "Limpar busca",
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),

          if (_isOpen && _results.isNotEmpty) ...[
            const SizedBox(height: 6),
            Material(
              elevation: 4,
              shadowColor: Colors.black.withAlpha(45),
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surface,

              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),

                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,

                  child: Row(
                    children: _results.map((WasteTypeSearchResult result) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),

                        child: ActionChip(
                          avatar: Icon(
                            result.type.icon,
                            size: 16,
                            color: result.type.color,
                          ),
                          label: Text(
                            "${result.matchedTerm} (${result.type.filterLabel})",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          backgroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: result.type.color.withValues(alpha: 0.5),
                            ),
                          ),
                          onPressed: () => _selectResult(result.type),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


// Classes ------------------------------------------------------------------ //


/// Botão de ação rápida proeminente que conduz diretamente ao ponto mais próximo (T8.1).
class NearestPointQuickBanner extends StatelessWidget {
  const NearestPointQuickBanner({
    super.key,
    required this.distanceMeters,
    required this.onPressed,
  });

  final double? distanceMeters;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final String label = distanceMeters != null
        ? "Mais próximo a ${formatDistance(distanceMeters!)}"
        : "Ponto mais próximo";

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

      child: Semantics(
        button: true,
        label: "$label. Tocar para abrir mapa com a rota.",

        child: Material(
          elevation: 3,
          shadowColor: Colors.black.withAlpha(35),
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surface,

          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),

            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),

              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTint,
                      shape: BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.near_me_rounded,
                      size: 18,
                      color: AppColors.primaryAccessible,
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          "Traçar rota direta em 1 toque",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Traçar rota",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// Classes ------------------------------------------------------------------ //


class _MapStatusPill extends StatelessWidget {
  const _MapStatusPill({
    required this.message,
    this.icon,
    this.isLoading = false,
  });

  final String message;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

      child: Material(
        color: AppColors.surface.withValues(alpha: 0.95),
        elevation: 2,
        shadowColor: Colors.black.withAlpha(30),
        borderRadius: BorderRadius.circular(20),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon ?? Icons.info_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),

              const SizedBox(width: 8),

              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
