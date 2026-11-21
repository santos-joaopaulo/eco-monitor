import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";


/// Caixa de aviso de biossegurança (fundo rosa, ícone e texto vermelhos).
class WarningBox extends StatelessWidget {
  const WarningBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: "Atenção. $message",
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.warningBackground,
          borderRadius: BorderRadius.circular(16),
        ),

        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 26,
              color: AppColors.warningText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warningText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
