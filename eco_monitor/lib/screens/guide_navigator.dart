import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../domain/entities/residue.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "disposal_guide_screen.dart";
import "disposal_step_by_step_screen.dart";

/// Nested navigator of the "guia" tab.
///
/// Because the [Navigator] lives *inside* the tab, the shell bottom menu
/// (main.dart) stays visible and persistent while the step-by-step is open.
class GuideNavigator extends StatefulWidget {
  const GuideNavigator({
    super.key,
    required this.repository,
    required this.active,
    required this.onShowCollectionPoints,
  });

  final DisposalGuideRepository repository;

  /// `true` when the "guia" tab is visible (controls the back button).
  final bool active;

  /// Called with the residue type after leaving the guide tab, so the map can
  /// filter the collection points (RF12/RF13).
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

  /// Floating warning shown when the residue guide is not available yet.
  void _showGuideUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  /// Closes the internal route (when the step-by-step is open) and only then
  /// hands the residue type to the shell, which switches to the map tab.
  void _showCollectionPoints(ResidueType type) {
    final NavigatorState? navigator = _navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
    widget.onShowCollectionPoints(type);
  }

  /// Android back button: closes the step-by-step; if already on the list,
  /// behaves like the system default (exits the app).
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
      // Only intercepts "back" when this tab is in front.
      canPop: !widget.active,
      onPopInvokedWithResult: _onBack,
      child: Navigator(key: _navigatorKey, onGenerateRoute: _generateRoute),
    );
  }
}
