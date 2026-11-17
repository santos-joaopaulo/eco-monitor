import "package:flutter/material.dart";

import "../theme/eco_theme.dart";


/// Item de uma timeline vertical: círculo numerado verde-água à esquerda,
/// título e descrição à direita, ligados por uma linha fina.
///
/// Marque o último item com [ultimo] para ocultar a linha de conexão.
class StepTimelineItem extends StatelessWidget {
  const StepTimelineItem({
    super.key,
    required this.numero,
    required this.titulo,
    required this.descricao,
    this.ultimo = false,
  });

  final int numero;
  final String titulo;
  final String descricao;
  final bool ultimo;

  static const double _diametro = 34;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _diametro,
              child: Column(
                children: [
                  Container(
                    width: _diametro,
                    height: _diametro,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: EcoColors.primaria,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "$numero",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!ultimo)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: EcoColors.linhaTimeline,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 2, bottom: ultimo ? 0 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: EcoColors.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descricao,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: EcoColors.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
