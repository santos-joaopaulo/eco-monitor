import "package:flutter/material.dart";

import "../theme/eco_theme.dart";
import "eco_card.dart";


/// Cartão de um resíduo na lista do guia: ícone, título, descrição,
/// botão de ação e indicador lateral (tempo/passos ou progresso).
///
/// Com [onPressed] nulo o botão aparece desabilitado.
class ResiduoCard extends StatelessWidget {
  const ResiduoCard({
    super.key,
    required this.icone,
    required this.corIcone,
    required this.titulo,
    required this.descricao,
    required this.rotuloBotao,
    required this.info,
    this.infoComRelogio = false,
    this.onPressed,
  });

  final IconData icone;
  final Color corIcone;
  final String titulo;
  final String descricao;
  final String rotuloBotao;
  final String info;
  final bool infoComRelogio;
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
                    color: EcoColors.tintaIcone,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icone, size: 32, color: corIcone),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: EcoColors.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      descricao,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: EcoColors.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Wrap: botão à esquerda e indicador à direita; se faltar espaço
          // (tela estreita / fonte grande) o indicador desce para a linha de baixo.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _BotaoAcao(rotulo: rotuloBotao, onPressed: onPressed),
                _Indicador(texto: info, comRelogio: infoComRelogio),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _BotaoAcao extends StatelessWidget {
  const _BotaoAcao({required this.rotulo, required this.onPressed});

  final String rotulo;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward, size: 20),
      label: Text(rotulo),
      style: FilledButton.styleFrom(
        backgroundColor: EcoColors.primaria,
        foregroundColor: Colors.white,
        disabledBackgroundColor: EcoColors.tintaIcone,
        disabledForegroundColor: EcoColors.textoSecundario,
        minimumSize: const Size(120, 48), // alvo de toque confortável
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}


class _Indicador extends StatelessWidget {
  const _Indicador({required this.texto, required this.comRelogio});

  final String texto;
  final bool comRelogio;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (comRelogio) ...[
          const Icon(
            Icons.schedule_outlined,
            size: 18,
            color: EcoColors.textoSecundario,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          texto,
          style: const TextStyle(
            fontSize: 13,
            color: EcoColors.textoSecundario,
          ),
        ),
      ],
    );
  }
}
