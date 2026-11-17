import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../domain/entities/residuo.dart";
import "../domain/repositories/guia_repository.dart";
import "guia_descarte_screen.dart";
import "passo_a_passo_remedios_screen.dart";


/// Navegador aninhado da aba "guia".
///
/// Como o [Navigator] fica *dentro* da aba, o menu inferior do shell
/// (main.dart) continua visível e persistente ao abrir o passo a passo.
class GuiaNavigator extends StatefulWidget {
  const GuiaNavigator({
    super.key,
    required this.repository,
    required this.ativo,
    required this.onVerPontosNoMapa,
  });

  final GuiaRepository repository;

  /// `true` quando a aba "guia" está visível (controla o botão voltar).
  final bool ativo;
  final VoidCallback onVerPontosNoMapa;

  @override
  State<GuiaNavigator> createState() => _GuiaNavigatorState();
}


class _GuiaNavigatorState extends State<GuiaNavigator> {
  static const String _rotaRemedios = "/remedios";

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _iniciarGuia(Residuo residuo) {
    switch (residuo.tipo) {
      case TipoResiduo.medicamento:
        _navigatorKey.currentState?.pushNamed(_rotaRemedios);
      case TipoResiduo.perfurocortante:
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text("O guia de seringas e agulhas chega em breve."),
            ),
          );
      case TipoResiduo.pilha:
        break; // Guia de pilhas ainda não implementado.
    }
  }

  /// Botão voltar do Android: fecha o passo a passo; se já estiver na lista,
  /// comporta-se como o padrão do sistema (sai do app).
  void _aoVoltar(bool didPop, Object? result) {
    if (didPop) return;
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  Route<void> _gerarRota(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (BuildContext context) => switch (settings.name) {
        _rotaRemedios => PassoAPassoRemediosScreen(
            repository: widget.repository,
            onVerPontosNoMapa: widget.onVerPontosNoMapa,
          ),
        _ => GuiaDescarteScreen(
            repository: widget.repository,
            onIniciarGuia: _iniciarGuia,
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Só intercepta o "voltar" quando esta aba está na frente.
      canPop: !widget.ativo,
      onPopInvokedWithResult: _aoVoltar,
      child: Navigator(key: _navigatorKey, onGenerateRoute: _gerarRota),
    );
  }
}
