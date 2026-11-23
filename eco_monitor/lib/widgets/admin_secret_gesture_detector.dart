import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";


// Classes ----------------------------------------------------------------- //


/// Detector de gesto secreto para ativação do painel de administração.
///
/// Monitora eventos brutos de ponteiro: o usuário deve tocar uma vez e, no segundo
/// toque, manter pressionado pelo tempo de [holdDuration] (padrão de 3 segundos).
/// Ao atingir o tempo limite, aciona [onTrigger] com feedback háptico.
class AdminSecretGestureDetector extends StatefulWidget {
  const AdminSecretGestureDetector({
    super.key,
    required this.child,
    required this.onTrigger,
    this.holdDuration = const Duration(seconds: 3),
    this.doubleTapTimeout = const Duration(milliseconds: 600),
  });

  final Widget child;
  final VoidCallback onTrigger;

  /// Duração contínua necessária no segundo toque para disparar a ação.
  final Duration holdDuration;

  /// Tempo máximo permitido entre o primeiro e o segundo toque.
  final Duration doubleTapTimeout;

  @override
  State<AdminSecretGestureDetector> createState() =>
      _AdminSecretGestureDetectorState();
}

class _AdminSecretGestureDetectorState
    extends State<AdminSecretGestureDetector> {
  int _tapCount = 0;
  int? _activePointerId;
  Timer? _holdTimer;
  Timer? _expirationTimer;


  // Lifecycle ------------------------------------------------------------- //


  @override
  void dispose() {
    _cancelHoldTimer();
    _cancelExpirationTimer();
    super.dispose();
  }


  // Methods --------------------------------------------------------------- //


  void _onPointerDown(PointerDownEvent event) {
    if (_activePointerId != null) {
      return;
    }
    _activePointerId = event.pointer;

    if (_tapCount == 0) {
      _cancelExpirationTimer();
      _tapCount = 1;
    } else if (_tapCount == 1) {
      _cancelExpirationTimer();
      _tapCount = 2;
      _holdTimer = Timer(widget.holdDuration, _triggerAdminAction);
    } else {
      _resetState();
      _tapCount = 1;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointerId) {
      return;
    }
    _activePointerId = null;

    if (_tapCount == 1) {
      _expirationTimer = Timer(widget.doubleTapTimeout, () {
        if (mounted) {
          setState(() {
            _tapCount = 0;
          });
        }
      });
    } else if (_tapCount == 2) {
      // Soltou o dedo antes de completar os 3 segundos
      _cancelHoldTimer();
      _tapCount = 0;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointerId) {
      return;
    }
    _activePointerId = null;
    _resetState();
  }

  void _triggerAdminAction() {
    _resetState();
    HapticFeedback.heavyImpact();
    widget.onTrigger();
  }

  void _resetState() {
    _cancelHoldTimer();
    _cancelExpirationTimer();
    _tapCount = 0;
    _activePointerId = null;
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  void _cancelExpirationTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
