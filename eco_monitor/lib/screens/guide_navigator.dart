import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../domain/entities/residue.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "disposal_guide_screen.dart";
import "disposal_step_by_step_screen.dart";

/// Navegador aninhado da aba "guia".
///
/// Como o [Navigator] reside *dentro* da aba, a barra inferior principal
/// (main.dart) permanece visível e persistente enquanto o passo a passo está aberto.
class GuideNavigator extends StatefulWidget {
  const GuideNavigator({
    super.key,
    required this.repository,
    required this.active,
    required this.onShowCollectionPoints,
  });

  final DisposalGuideRepository repository;

  /// `true` quando a aba "guia" está visível (controla o botão voltar).
  final bool active;

  /// Chamado com o tipo de resíduo ao sair da aba do guia, permitindo que o mapa
  /// filtre os pontos de coleta (RF12/RF13).
  final ValueChanged<ResidueType> onShowCollectionPoints;

  @override
  State<GuideNavigator> createState() => _GuideNavigatorState();
}

class _GuideNavigatorState extends State<GuideNavigator> {
  static const Map<ResidueType, String> _routesByType = {
    ResidueType.medicine: "/remedios",
    ResidueType.battery: "/pilhas",
    ResidueType.sharps: "/seringas",
    ResidueType.electronics: "/eletronicos",
  };

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  ResidueType? _typeForRoute(String? routeName) {
    for (final MapEntry<ResidueType, String> entry in _routesByType.entries) {
      if (entry.value == routeName) {
        return entry.key;
      }
    }
    return null;
  }

  void _startGuide(Residue residue) {
    if (widget.repository.stepsGuideFor(residue.type) == null) {
      _showGuideUnavailable(
        "O guia de ${residue.title.toLowerCase()} está indisponível no momento.",
      );
      return;
    }

    final String? routeName = _routesByType[residue.type];
    if (routeName != null) {
      _navigatorKey.currentState?.pushNamed(routeName);
    }
  }

  /// Alerta flutuante exibido quando o guia do resíduo ainda não está disponível.
  void _showGuideUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  /// Fecha a rota interna (quando o passo a passo está aberto) e só então
  /// repassa o tipo de resíduo para a casca do app, que alterna para a aba do mapa.
  void _showCollectionPoints(ResidueType type) {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
    widget.onShowCollectionPoints(type);
  }

  /// Botão voltar do Android: fecha o passo a passo; se já estiver na listagem,
  /// tem o comportamento padrão do sistema (sai do app).
  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      SystemNavigator.pop();
    }
  }

  Route<void> _generateRoute(RouteSettings settings) {
    final ResidueType? residueType = _typeForRoute(settings.name);

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (BuildContext context) {
        if (residueType != null) {
          return DisposalStepByStepScreen(
            residueType: residueType,
            repository: widget.repository,
            onShowCollectionPoints: _showCollectionPoints,
          );
        }

        return DisposalGuideScreen(
          repository: widget.repository,
          onStartGuide: _startGuide,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Só intercepta o "voltar" quando esta aba estiver ativa na frente.
      canPop: !widget.active,
      onPopInvokedWithResult: _onBack,
      child: Navigator(key: _navigatorKey, onGenerateRoute: _generateRoute),
    );
  }
}
