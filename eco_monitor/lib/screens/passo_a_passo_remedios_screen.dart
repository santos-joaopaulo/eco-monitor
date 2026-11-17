import "package:flutter/material.dart";

import "../domain/entities/guia_passos.dart";
import "../domain/entities/residuo.dart";
import "../domain/repositories/guia_repository.dart";
import "../theme/eco_theme.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/eco_app_bar.dart";
import "../widgets/eco_card.dart";
import "../widgets/residuo_estilo.dart";
import "../widgets/step_timeline_item.dart";
import "../widgets/warning_box.dart";


/// Tela 2: passo a passo do descarte de remédios vencidos.
class PassoAPassoRemediosScreen extends StatelessWidget {
  const PassoAPassoRemediosScreen({
    super.key,
    required this.repository,
    required this.onVerPontosNoMapa,
  });

  final GuiaRepository repository;

  /// Chamado ao tocar em "Ver pontos no mapa".
  final VoidCallback onVerPontosNoMapa;

  static const double _alturaBotao = 56;

  @override
  Widget build(BuildContext context) {
    final GuiaPassos? guia = repository.guiaPassosDe(TipoResiduo.medicamento);

    return Scaffold(
      backgroundColor: EcoColors.fundo,
      appBar: EcoAppBar(
        title: "REMÉDIOS",
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: guia == null
          ? const Center(child: Text("Guia indisponível no momento."))
          : _Conteudo(
              guia: guia,
              alturaBotao: _alturaBotao,
              onVerPontosNoMapa: onVerPontosNoMapa,
            ),
    );
  }
}


class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.guia,
    required this.alturaBotao,
    required this.onVerPontosNoMapa,
  });

  final GuiaPassos guia;
  final double alturaBotao;
  final VoidCallback onVerPontosNoMapa;

  @override
  Widget build(BuildContext context) {
    final double reservaMenu = CustomBottomNavBar.alturaReservada(context);
    const TipoResiduo tipo = TipoResiduo.medicamento;

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),
            child: ListView(
              // Espaço para o botão flutuante + menu inferior.
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                reservaMenu + alturaBotao + 32,
              ),
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(tipo.icone, size: 32, color: tipo.cor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          guia.titulo,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: EcoColors.textoPrincipal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  guia.subtitulo,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: EcoColors.textoSecundario,
                  ),
                ),
                const SizedBox(height: 16),
                WarningBox(mensagem: guia.alerta),
                const SizedBox(height: 16),
                EcoCard(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    children: [
                      for (var i = 0; i < guia.passos.length; i++)
                        StepTimelineItem(
                          numero: i + 1,
                          titulo: guia.passos[i].titulo,
                          descricao: guia.passos[i].descricao,
                          ultimo: i == guia.passos.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botão largo flutuante, logo acima do menu inferior.
        Positioned(
          left: 20,
          right: 20,
          bottom: reservaMenu + 16,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: kEcoMaxContentWidth - 40),
              child: ElevatedButton.icon(
                onPressed: onVerPontosNoMapa,
                icon: const Icon(Icons.location_on_outlined, size: 26),
                label: const Text("Ver pontos no mapa"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EcoColors.primaria,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.black.withAlpha(80),
                  minimumSize: Size(double.infinity, alturaBotao),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
