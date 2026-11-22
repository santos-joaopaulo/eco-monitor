import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";

/// Altura da barra flutuante e margem inferior (usadas para reservar espaço em
/// listas e botões posicionados acima do menu).
const double kEcoNavBarHeight = 64;
const double kEcoNavBarMargin = 16;

/// Menu inferior flutuante com as 4 abas do aplicativo: home, guia, eventos,
/// sugerir.
///
/// É um widget de apresentação: o widget pai gerencia a aba atual
/// ([currentIndex] / [onTap]).
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem("home", Icons.home_outlined),
    _NavItem("guia", Icons.map_outlined),
    _NavItem("eventos", Icons.calendar_today_outlined),
    _NavItem("sugerir", Icons.chat_bubble_outline),
  ];

  /// Espaço total ocupado pela barra na parte inferior (incluindo a barra de navegação
  /// do sistema de 3 botões ou área de gestos do Android/iOS).
  ///
  /// Obtém o padding inferior diretamente da View raiz para garantir que o inset de
  /// botões de navegação do sistema (~48px) nunca seja zerado por Scaffolds internos.
  static double reservedBottomInset(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return 0;
    }

    final double windowBottom =
        View.of(context).viewPadding.bottom / MediaQuery.devicePixelRatioOf(context);
    final double mediaQueryBottom = MediaQuery.viewPaddingOf(context).bottom;
    final double systemInset =
        windowBottom > mediaQueryBottom ? windowBottom : mediaQueryBottom;

    return kEcoNavBarHeight + kEcoNavBarMargin + systemInset;
  }

  @override
  Widget build(BuildContext context) {
    // Quando o teclado virtual está aberto, oculta o menu flutuante para não
    // cobrir os campos e botões do formulário.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1.0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kEcoContentHorizontalPadding,
            0,
            kEcoContentHorizontalPadding,
            kEcoNavBarMargin,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),
            child: Material(
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withAlpha(64),
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,

              child: SizedBox(
                height: kEcoNavBarHeight,
                // Altura fixa: limita a escala de fonte do sistema.
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.2,
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: _items[i],
                            selected: i == currentIndex,
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
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 24, color: color),
            const SizedBox(height: 2),

            Flexible(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
