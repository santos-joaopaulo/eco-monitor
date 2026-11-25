import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";


// Home map controls -------------------------------------------------------- //


/// Botão flutuante que unifica localização e rota ao ponto mais próximo em 1 toque (RF02, RF04, T8.1).
class HomeLocateButton extends StatelessWidget {
  const HomeLocateButton({
    super.key,
    required this.bottom,
    required this.onPressed,
    this.distanceMeters,
    this.tooltip = "Centralizar na minha localização",
  });

  final double bottom;
  final VoidCallback onPressed;
  final double? distanceMeters;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final String? distanceLabel = distanceMeters != null
        ? formatDistance(distanceMeters!)
        : null;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,

      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (distanceLabel != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Mais próximo · $distanceLabel",
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            SizedBox(
              width: 72,
              height: 72,

              child: FloatingActionButton(
                heroTag: "home_locate_fab",
                backgroundColor: AppColors.primary,
                shape: const CircleBorder(),
                tooltip: tooltip,
                onPressed: onPressed,

                child: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botão flutuante que alterna entre a visualização em mapa e em lista.
class HomeViewToggleButton extends StatelessWidget {
  const HomeViewToggleButton({
    super.key,
    required this.bottom,
    required this.isListMode,
    required this.onPressed,
  });

  final double bottom;
  final bool isListMode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _HomeSideFloatingButton(
      bottom: bottom,
      alignRight: true,
      heroTag: "home_toggle_view_fab",
      tooltip: isListMode
          ? "Visualização em mapa"
          : "Visualização em lista",
      icon: isListMode ? Icons.map_outlined : Icons.view_list_rounded,
      onPressed: onPressed,
    );
  }
}


// Classes ------------------------------------------------------------------ //


/// Botão flutuante que abre a busca de resíduos no mapa.
class HomeSearchButton extends StatelessWidget {
  const HomeSearchButton({
    super.key,
    required this.bottom,
    required this.onPressed,
  });

  final double bottom;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _HomeSideFloatingButton(
      bottom: bottom,
      alignRight: false,
      heroTag: "home_search_fab",
      tooltip: "Buscar resíduo",
      icon: Icons.search_rounded,
      onPressed: onPressed,
    );
  }
}

class _HomeSideFloatingButton extends StatelessWidget {
  const _HomeSideFloatingButton({
    required this.bottom,
    required this.alignRight,
    required this.heroTag,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final double bottom;
  final bool alignRight;
  final String heroTag;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Alinha a altura do centro deste botão (48px) ao centro do botão principal (72px).
    final double alignedBottom = bottom + (72 - 48) / 2;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double sideInset =
        math.max(0.0, (screenWidth - kEcoMaxContentWidth) / 2) +
        kEcoContentHorizontalPadding;

    return Positioned(
      left: alignRight ? null : sideInset,
      right: alignRight ? sideInset : null,
      bottom: alignedBottom,

      child: SizedBox(
        width: 48,
        height: 48,

        child: FloatingActionButton(
          heroTag: heroTag,
          elevation: 4,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.primary,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.primary, width: 2),
          ),
          tooltip: tooltip,
          onPressed: onPressed,

          child: Icon(
            icon,
            size: 24,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
