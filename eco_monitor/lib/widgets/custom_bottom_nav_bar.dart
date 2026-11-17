import "package:flutter/material.dart";

import "../theme/eco_theme.dart";


/// Altura da barra flutuante e margem inferior (usadas para reservar
/// espaço em listas e botões que ficam "acima" do menu).
const double kEcoNavBarHeight = 64;
const double kEcoNavBarMargin = 16;


/// Menu inferior flutuante com as 4 abas do app: home, guia, eventos, sugerir.
///
/// É um widget "burro": quem controla a aba atual é o pai
/// ([currentIndex] / [onTap]).
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _itens = [
    _NavItem("home", Icons.home_outlined),
    _NavItem("guia", Icons.map_outlined),
    _NavItem("eventos", Icons.calendar_today_outlined),
    _NavItem("sugerir", Icons.chat_bubble_outline),
  ];

  /// Espaço total ocupado pela barra no rodapé (inclui a área do gesto de
  /// navegação do sistema). Use como padding inferior de conteúdo rolável.
  static double alturaReservada(BuildContext context) {
    return kEcoNavBarHeight +
        kEcoNavBarMargin +
        MediaQuery.viewPaddingOf(context).bottom;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, kEcoNavBarMargin),
            child: Material(
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withAlpha(64),
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: kEcoNavBarHeight,
                // Altura fixa: limita o escalonamento de fonte do sistema.
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.2,
                  child: Row(
                    children: [
                      for (var i = 0; i < _itens.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: _itens[i],
                            selecionado: i == currentIndex,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _NavItem {
  const _NavItem(this.rotulo, this.icone);

  final String rotulo;
  final IconData icone;
}


class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selecionado,
    required this.onTap,
  });

  final _NavItem item;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color cor =
        selecionado ? EcoColors.primaria : EcoColors.textoSecundario;

    return Semantics(
      button: true,
      selected: selecionado,
      label: item.rotulo,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icone, size: 26, color: cor),
            const SizedBox(height: 4),
            Text(
              item.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cor,
                fontSize: 11,
                fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
