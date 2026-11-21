import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";
import "selection_checkbox.dart";


// Métodos ----------------------------------------------------------------- //


/// Formata um [TimeOfDay] no padrão de 24 horas exibido nas pílulas de horário.
String formatTimeOfDayValue(TimeOfDay time) {
  final String hour = time.hour.toString().padLeft(2, "0");
  final String minute = time.minute.toString().padLeft(2, "0");

  return "$hour:$minute";
}


// Classes ----------------------------------------------------------------- //


/// Linha de um dia da semana na seção "Horário de funcionamento".
///
/// O checkbox ao lado do dia alterna entre aberto e fechado. Quando aberto,
/// exibe duas pílulas de horário (abertura e fechamento) separadas por "às".
class OpeningHoursRow extends StatelessWidget {
  const OpeningHoursRow({
    super.key,
    required this.dayLabel,
    required this.isOpen,
    required this.opensAt,
    required this.closesAt,
    required this.onToggleOpen,
    required this.onOpeningTap,
    required this.onClosingTap,
  });

  final String dayLabel;
  final bool isOpen;
  final TimeOfDay opensAt;
  final TimeOfDay closesAt;
  final VoidCallback onToggleOpen;
  final VoidCallback onOpeningTap;
  final VoidCallback onClosingTap;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),

        child: Row(
          children: [
            Semantics(
              button: true,
              checked: isOpen,
              label: "$dayLabel, ${isOpen ? "aberto" : "fechado"}",
              hint: isOpen
                  ? "Toque para marcar como fechado"
                  : "Toque para abrir neste dia",
              excludeSemantics: true,

              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onToggleOpen,

                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      SelectionCheckbox(isSelected: isOpen, size: 20),
                      const SizedBox(width: 8),

                      SizedBox(
                        width: 30,
                        child: Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isOpen
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            Expanded(
              child: isOpen
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _TimePill(
                          time: opensAt,
                          semanticsLabel: "$dayLabel, horário de abertura",
                          onTap: onOpeningTap,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "às",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        _TimePill(
                          time: closesAt,
                          semanticsLabel: "$dayLabel, horário de fechamento",
                          onTap: onClosingTap,
                        ),
                      ],
                    )
                  : const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "Fechado",
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


// Classes ----------------------------------------------------------------- //


class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.time,
    required this.semanticsLabel,
    required this.onTap,
  });

  final TimeOfDay time;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "$semanticsLabel, ${formatTimeOfDayValue(time)}",
      hint: "Toque para alterar",
      excludeSemantics: true,

      child: Material(
        color: AppColors.primaryTint,
        shape: const StadiumBorder(side: BorderSide(color: AppColors.primary)),
        clipBehavior: Clip.antiAlias,

        child: InkWell(
          onTap: onTap,

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              formatTimeOfDayValue(time),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
