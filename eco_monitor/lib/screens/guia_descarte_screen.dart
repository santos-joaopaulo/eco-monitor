import "package:flutter/material.dart";

import "../domain/entities/residuo.dart";
import "../domain/repositories/guia_repository.dart";
import "../theme/eco_theme.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/eco_app_bar.dart";
import "../widgets/residuo_card.dart";
import "../widgets/residuo_estilo.dart";


/// Tela 1: lista de resíduos com o botão para iniciar cada guia.
class GuiaDescarteScreen extends StatelessWidget {
  const GuiaDescarteScreen({
    super.key,
    required this.repository,
    required this.onIniciarGuia,
  });

  final GuiaRepository repository;
  final ValueChanged<Residuo> onIniciarGuia;

  @override
  Widget build(BuildContext context) {
    final List<Residuo> residuos = repository.listarResiduos();

    return Scaffold(
      backgroundColor: EcoColors.fundo,
      appBar: const EcoAppBar(title: "GUIA DE DESCARTE"),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),
          child: ListView(
            // O menu inferior flutua sobre o conteúdo: reserva o espaço dele.
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              CustomBottomNavBar.alturaReservada(context),
            ),
            children: [
              const _Cabecalho(),
              const SizedBox(height: 24),
              for (final Residuo residuo in residuos) ...[
                ResiduoCard(
                  icone: residuo.tipo.icone,
                  corIcone: residuo.tipo.cor,
                  titulo: residuo.titulo,
                  descricao: residuo.descricao,
                  rotuloBotao: residuo.emAndamento ? "Continuar" : "Iniciar",
                  info: residuo.emAndamento
                      ? "${residuo.passosConcluidos} de ${residuo.totalPassos} passos"
                      : "${residuo.minutos} min · ${residuo.totalPassos} passos",
                  infoComRelogio: !residuo.emAndamento,
                  // Protótipo: "Continuar" aparece desabilitado (ver
                  // Guia-descarte.png). Quando existir retomada de progresso,
                  // troque `null` por `() => onIniciarGuia(residuo)`.
                  onPressed:
                      residuo.emAndamento ? null : () => onIniciarGuia(residuo),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _Cabecalho extends StatelessWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            "Como descartar certo?",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: EcoColors.textoPrincipal,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Escolha o material e siga o passo a passo antes de levar ao ponto de coleta.",
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: EcoColors.textoSecundario,
          ),
        ),
      ],
    );
  }
}
