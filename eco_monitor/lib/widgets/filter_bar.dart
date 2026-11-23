import "package:material_ui/material_ui.dart";

import "../domain/entities/waste_type.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "waste_style.dart";


// Classes ----------------------------------------------------------------- //


/// Filtros horizontais de tipos de resíduos exibidos sobre o mapa (RF12, RF13).
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.selectedTypes,
    required this.onChanged,
  });

  static const List<WasteType> _types = <WasteType>[
    WasteType.medicines,
    WasteType.sharps,
    WasteType.batteries,
    WasteType.electronics,
    WasteType.glass,
  ];

  final Set<WasteType> selectedTypes;
  final ValueChanged<Set<WasteType>> onChanged;


  // Methods --------------------------------------------------------------- //


  void _toggle(WasteType type) {
    final Set<WasteType> next = Set<WasteType>.of(selectedTypes);
    if (!next.remove(type)) {
      next.add(type);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: Row(
            children: [
              for (int index = 0; index < _types.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),

                Expanded(
                  child: _MapFilterPill(
                    type: _types[index],
                    isSelected: selectedTypes.contains(_types[index]),
                    onTap: () => _toggle(_types[index]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


// Classes ----------------------------------------------------------------- //


class _MapFilterPill extends StatelessWidget {
  const _MapFilterPill({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final WasteType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: type.filterLabel,
      hint: "Filtrar pontos de coleta",

      child: Tooltip(
        message: type.filterLabel,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryTint : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),

          child: Material(
            color: Colors.transparent,

            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,

              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),

                child: Center(
                  child: Icon(
                    type.icon,
                    size: 20,
                    color: type.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
