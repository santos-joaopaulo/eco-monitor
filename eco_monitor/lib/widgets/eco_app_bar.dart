import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../theme/app_colors.dart";


/// AppBar padrão do EcoMonitor: fundo verde-água, título branco centralizado.
///
/// Sem [onBack], exibe o logo (ícone de reciclagem branco) à esquerda;
/// com [onBack], exibe a seta de retorno.
class EcoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EcoAppBar({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,

      leading: onBack == null
          ? const _Logo()
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 28,
              tooltip: "Voltar",
              onPressed: onBack,
            ),

      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 24),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Image(
          image: AssetImage("assets/logo.png"),
          semanticLabel: "EcoMonitor",
        ),
      ),
    );
  }
}
