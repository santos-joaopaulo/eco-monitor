import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";
import "eco_card.dart";

/// Card de um resíduo na listagem do guia: ícone, título, descrição, botão
/// de ação e indicador lateral (tempo estimado e quantidade de passos).
///
/// Com [onPressed] nulo, o botão aparece desabilitado.
class ResidueCard extends StatelessWidget {
  const ResidueCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.info,
    this.infoWithClock = false,
    this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonLabel;
  final String info;
  final bool infoWithClock;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.iconTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Wrap: botão à esquerda e indicador à direita; se não houver
          // espaço suficiente (tela estreita / fonte grande), o indicador
          // desce para a linha seguinte.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionButton(label: buttonLabel, onPressed: onPressed),
                _Indicator(text: info, withClock: infoWithClock),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.iconTint,
        disabledForegroundColor: AppColors.textSecondary,

        minimumSize: const Size(120, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.text, required this.withClock});

  final String text;
  final bool withClock;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (withClock) ...[
          const Icon(
            Icons.schedule_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
