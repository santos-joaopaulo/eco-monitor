import "package:flutter/material.dart";

import "../theme/eco_theme.dart";


/// Caixa de alerta de biossegurança (fundo rosado, ícone e texto em vermelho).
class WarningBox extends StatelessWidget {
  const WarningBox({super.key, required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: "Atenção. $mensagem",
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: EcoColors.alertaFundo,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 26,
              color: EcoColors.alertaTexto,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensagem,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: EcoColors.alertaTexto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
