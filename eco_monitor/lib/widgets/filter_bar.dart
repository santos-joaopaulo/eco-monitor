import "package:flutter/material.dart";

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

  static const Color _labelColor = Color(0xFF4A4A4A);

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
      excludeSemantics: true,

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type.icon, size: 15, color: type.color),
              const SizedBox(width: 5),

              Flexible(
                child: Text(
                  type.filterLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.primary : _labelColor,
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
