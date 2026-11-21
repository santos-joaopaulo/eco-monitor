import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";


// Home map controls ------------------------------------------------------- //


/// Botão flutuante que centraliza o mapa na localização do usuário.
class HomeLocateButton extends StatelessWidget {
  const HomeLocateButton({
    super.key,
    required this.bottom,
    required this.onPressed,
  });

  final double bottom;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,

      child: Center(
        child: SizedBox(
          width: 72,
          height: 72,

          child: FloatingActionButton(
            heroTag: "home_locate_fab",
            backgroundColor: AppColors.primary,
            shape: const CircleBorder(),
            tooltip: "Centralizar na minha localização",
            onPressed: onPressed,

            child: const Icon(Icons.my_location, color: Colors.white),
          ),
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
    return Positioned(
      right: 16,
      bottom: bottom,

      child: FloatingActionButton(
        heroTag: "home_toggle_view_fab",
        mini: true,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryAccessible,
        elevation: 4,
        tooltip: isListMode
            ? "Visualização em mapa"
            : "Visualização em lista",
        onPressed: onPressed,

        child: Icon(
          isListMode ? Icons.map_outlined : Icons.view_list_rounded,
          size: 22,
          color: AppColors.primaryAccessible,
        ),
      ),
    );
  }
}
