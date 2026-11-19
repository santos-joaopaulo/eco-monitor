import "package:flutter/material.dart";

import "../models/collection_point.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "waste_style.dart";

// Classes ----------------------------------------------------------------- //

/// Horizontal waste-type filters shown over the map (RF12, RF13).
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.selectedTypes,
    required this.visibleCount,
    required this.onChanged,
  });

  final Set<WasteType> selectedTypes;
  final int visibleCount;
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

      child: Material(
        color: AppColors.surface.withValues(alpha: 0.94),
        elevation: 3,
        shadowColor: Colors.black.withAlpha(35),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,

        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),

          child: Row(
            children: [
              for (final WasteType type in WasteType.values) ...[
                _WasteFilterChip(
                  type: type,
                  selected: selectedTypes.contains(type),
                  onTap: () => _toggle(type),
                ),
                const SizedBox(width: 8),
              ],

              const SizedBox(width: 4),

              Semantics(
                liveRegion: true,
                label: _countLabel(visibleCount),
                excludeSemantics: true,

                child: Text(
                  _countLabel(visibleCount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// Classes ----------------------------------------------------------------- //

class _WasteFilterChip extends StatelessWidget {
  const _WasteFilterChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final WasteType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected
        ? AppColors.textPrimary
        : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      hint: "Filtrar pontos de coleta",
      excludeSemantics: true,

      child: Material(
        color: selected ? AppColors.primary : AppColors.background,
        shape: const StadiumBorder(),

        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),

          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),

              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(type.icon, size: 18, color: foreground),
                  const SizedBox(width: 6),

                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),

                  if (selected) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Methods ----------------------------------------------------------------- //

String _countLabel(int count) {
  return count == 1 ? "1 ponto" : "$count pontos";
}
