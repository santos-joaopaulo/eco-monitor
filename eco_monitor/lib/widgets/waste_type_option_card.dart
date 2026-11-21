import "package:flutter/material.dart";

import "../domain/entities/waste_type.dart";
import "../theme/app_colors.dart";
import "selection_checkbox.dart";
import "waste_style.dart";


// Classes ----------------------------------------------------------------- //


/// Card selecionável de um tipo de resíduo no formulário de sugestão de ponto.
///
/// Exibe o checkbox à esquerda, o ícone e o rótulo curto do material. O estado
/// selecionado usa o tom claro da cor primária e a borda de destaque do tema.
class WasteTypeOptionCard extends StatelessWidget {
  const WasteTypeOptionCard({
    super.key,
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
      hint: isSelected ? "Toque para remover" : "Toque para adicionar",
      excludeSemantics: true,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),

        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,

          child: InkWell(
            onTap: onTap,

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Row(
                  children: [
                    SelectionCheckbox(isSelected: isSelected),
                    const SizedBox(width: 10),

                    Icon(type.icon, size: 18, color: type.color),
                    const SizedBox(width: 6),

                    Expanded(
                      child: Text(
                        type.filterLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
