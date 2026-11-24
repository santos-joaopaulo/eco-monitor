import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/spatial_index.dart";
import "location_notice.dart";


// Classes ------------------------------------------------------------------ //


/// Barra de seleção de raio de proximidade configurável para busca geoespacial (T11.1).
class RadiusFilterBar extends StatelessWidget {
  const RadiusFilterBar({
    super.key,
    required this.selectedRadius,
    required this.onChanged,
  });

  final ProximityRadius selectedRadius;
  final ValueChanged<ProximityRadius> onChanged;

  static const List<ProximityRadius> _options = <ProximityRadius>[
    ProximityRadius.twoKm,
    ProximityRadius.fiveKm,
    ProximityRadius.tenKm,
    ProximityRadius.unlimited,
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),

            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),

                  child: Icon(
                    Icons.radar_rounded,
                    size: 16,
                    color: AppColors.primaryAccessible,
                  ),
                ),
                for (int i = 0; i < _options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _RadiusOptionPill(
                      radius: _options[i],
                      isSelected: selectedRadius == _options[i],
                      onTap: () => onChanged(_options[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _RadiusOptionPill extends StatelessWidget {
  const _RadiusOptionPill({
    required this.radius,
    required this.isSelected,
    required this.onTap,
  });

  final ProximityRadius radius;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = radius == ProximityRadius.unlimited
        ? "Todos"
        : (radius == ProximityRadius.fiveKm ? "5 km" : radius.label);

    return Semantics(
      button: true,
      selected: isSelected,
      label: "Filtrar por raio de ${radius.label}",

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,

          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryAccessible
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),

            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Aviso amigável exibido quando nenhum ecoponto for localizado no raio ativo (T11.1).
class EmptyRadiusNoticePill extends StatelessWidget {
  const EmptyRadiusNoticePill({
    super.key,
    required this.radius,
    required this.onExpand,
  });

  final ProximityRadius radius;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

        child: LocationNotice(
          message: "Nenhum ecoponto em até ${radius.label}",
          actionLabel: "Expandir",
          onAction: onExpand,
        ),
      ),
    );
  }
}
