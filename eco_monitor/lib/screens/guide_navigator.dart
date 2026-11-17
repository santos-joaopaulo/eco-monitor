import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../domain/entities/residue.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "disposal_guide_screen.dart";
import "medicines_step_by_step_screen.dart";


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
  static const String _medicinesRoute = "/remedios";

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _startGuide(Residue residue) {
    switch (residue.type) {
      case ResidueType.medicine:
        _navigatorKey.currentState?.pushNamed(_medicinesRoute);
      case ResidueType.battery:
        _showGuideUnavailable("O guia de pilhas e baterias chega em breve.");
      case ResidueType.sharps:
        _showGuideUnavailable("O guia de seringas e agulhas chega em breve.");
    }
  }

  /// Floating warning shown when the residue guide is not available yet.
  void _showGuideUnavailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
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
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (BuildContext context) => switch (settings.name) {
        _medicinesRoute => MedicinesStepByStepScreen(
          repository: widget.repository,
          onShowCollectionPoints: _showCollectionPoints,
        ),
        _ => DisposalGuideScreen(
          repository: widget.repository,
          onStartGuide: _startGuide,
        ),
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
