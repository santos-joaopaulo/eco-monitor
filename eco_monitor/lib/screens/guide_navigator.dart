import "package:material_ui/material_ui.dart";

import "../domain/entities/residue.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "disposal_guide_screen.dart";
import "disposal_step_by_step_screen.dart";


// Classes ------------------------------------------------------------------ //


/// Observador de rotas para sincronizar o estado de canPop do navegador aninhado.
class _GuideRouteObserver extends NavigatorObserver {
  _GuideRouteObserver(this.onChanged);

  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onChanged();
  }
}

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
    this.onBackToHome,
    this.banner,
  });

  final DisposalGuideRepository repository;

  /// `true` quando a aba "guia" está visível (controla o botão voltar).
  final bool active;

  /// Chamado com o tipo de resíduo ao sair da aba do guia, permitindo que o mapa
  /// filtre os pontos de coleta (RF12/RF13).
  final ValueChanged<WasteType> onShowCollectionPoints;

  /// Chamado quando o usuário aciona o botão voltar na raiz do guia,
  /// permitindo redirecionar para a aba inicial (HomeScreen) em vez de fechar o app.
  final VoidCallback? onBackToHome;

  /// Banner de conectividade posicionado sob a AppBar das telas do guia.
  final Widget? banner;

  @override
  State<GuideNavigator> createState() => _GuideNavigatorState();
}

class _GuideNavigatorState extends State<GuideNavigator> {
  static const Map<WasteType, String> _routesByType = {
    WasteType.medicines: "/remedios",
    WasteType.batteries: "/pilhas",
    WasteType.sharps: "/seringas",
    WasteType.electronics: "/eletronicos",
    WasteType.glass: "/vidro",
  };

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final _GuideRouteObserver _routeObserver = _GuideRouteObserver(
    _updateCanPop,
  );
  bool _canPopInternal = false;

  void _updateCanPop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool canPopNow = _navigatorKey.currentState?.canPop() ?? false;
      if (_canPopInternal != canPopNow) {
        setState(() {
          _canPopInternal = canPopNow;
        });
      }
    });
  }

  WasteType? _typeForRoute(String? routeName) {
    for (final MapEntry<WasteType, String> entry in _routesByType.entries) {
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
  void _showCollectionPoints(WasteType type) {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
    widget.onShowCollectionPoints(type);
  }

  /// Trata o retorno no Android: desempilha rotas internas do guia quando houver;
  /// se já estiver na raiz do guia, redireciona para a aba Home caso configurado,
  /// sem invocar SystemNavigator.pop().
  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }

    widget.onBackToHome?.call();
  }

  Route<void> _generateRoute(RouteSettings settings) {
    final WasteType? wasteType = _typeForRoute(settings.name);

    return MaterialPageRoute<void>(
      settings: settings,
      builder: (BuildContext context) {
        if (wasteType != null) {
          return DisposalStepByStepScreen(
            wasteType: wasteType,
            repository: widget.repository,
            onShowCollectionPoints: _showCollectionPoints,
            banner: widget.banner,
          );
        }

        return DisposalGuideScreen(
          repository: widget.repository,
          onStartGuide: _startGuide,
          banner: widget.banner,
          onShowCollectionPoints: _showCollectionPoints,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop =
        !widget.active || (!_canPopInternal && widget.onBackToHome == null);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: _onBack,
      child: Navigator(
        key: _navigatorKey,
        observers: [_routeObserver],
        onGenerateRoute: _generateRoute,
      ),
    );
  }
}
