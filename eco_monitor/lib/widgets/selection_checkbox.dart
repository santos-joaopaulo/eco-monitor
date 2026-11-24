import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";


// Classes ------------------------------------------------------------------ //


/// Caixa de seleção visual com cantos arredondados usada nos cards de material
/// e nas linhas de horário de funcionamento.
class SelectionCheckbox extends StatelessWidget {
  const SelectionCheckbox({
    super.key,
    required this.isSelected,
    this.size = 22,
  });

  final bool isSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.inactive,
          width: 1.5,
        ),
      ),

      child: isSelected
          ? Icon(Icons.check_rounded, size: size * 0.72, color: Colors.white)
          : null,
    );
  }
}
