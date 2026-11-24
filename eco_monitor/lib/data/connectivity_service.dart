import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";


// Classes ------------------------------------------------------------------ //


/// Encapsulamento leve em torno de [Connectivity] que expõe o status online
/// do dispositivo como uma stream de broadcast e uma verificação pontual (RNF10).
///
/// Aceita sobreposições opcionais de [connectivityStream] e [checkConnectivity] para
/// testes unitários e de widgets determinísticos.
class ConnectivityService with WidgetsBindingObserver {
  ConnectivityService({
    Stream<List<ConnectivityResult>>? connectivityStream,
    this.checkConnectivity,
  }) : _isTestStream = connectivityStream != null {
    final Stream<List<ConnectivityResult>> sourceStream =
        connectivityStream ?? _defaultStream();

    _subscription = sourceStream.listen(
      (List<ConnectivityResult> results) {
        final bool online = isConnectedResults(results);
        _updateOnlineState(online);
      },
      onError: (_) {
        // Ignora erros de stream da plataforma (ex.: plugin ausente em testes).
      },
    );

    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {
      // Ignora quando WidgetsBinding não está instanciado (ex.: testes de unidade).
    }

    if (!_isTestStream) {
      _schedulePoll();
    }
  }

  final bool _isTestStream;
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  Timer? _pollTimer;

  bool _lastKnownOnline = true;

  /// Estado de conectividade observado mais recentemente.
  bool get lastKnownOnline => _lastKnownOnline;

  /// Emite `true` quando o dispositivo está online e `false` caso contrário.
  Stream<bool> get isOnline => _controller.stream;


// Methods ------------------------------------------------------------------ //


  void _updateOnlineState(bool online) {
    final bool changed = _lastKnownOnline != online;
    _lastKnownOnline = online;
    if (changed && !_controller.isClosed) {
      _controller.add(online);
      if (!_isTestStream) {
        _schedulePoll();
      }
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (_controller.isClosed) {
      return;
    }

    // Intervalo reduzido (2s) quando offline para reconexão imediata;
    // verificação periódica de 15s quando online para manter o sincronismo.
    final Duration interval = _lastKnownOnline
        ? const Duration(seconds: 15)
        : const Duration(seconds: 2);

    _pollTimer = Timer(interval, () async {
      if (_controller.isClosed) {
        return;
      }
      await checkNow();
      if (!_controller.isClosed && !_isTestStream) {
        _schedulePoll();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkNow());
    }
  }

  /// Retorna se o dispositivo possui uma interface de rede disponível no momento.
  Future<bool> checkNow() async {
    try {
      final Future<List<ConnectivityResult>> Function() checker =
          checkConnectivity ?? Connectivity().checkConnectivity;
      final List<ConnectivityResult> results = await checker();
      final bool online = isConnectedResults(results);
      _updateOnlineState(online);
      return online;
    } on MissingPluginException {
      return _lastKnownOnline;
    } on PlatformException {
      return _lastKnownOnline;
    } catch (_) {
      return _lastKnownOnline;
    }
  }

  /// Cancela a inscrição de conectividade subjacente e fecha a stream.
  void dispose() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _pollTimer?.cancel();
    _pollTimer = null;
    _subscription.cancel();
    _controller.close();
  }
}


// Methods ------------------------------------------------------------------ //


Stream<List<ConnectivityResult>> _defaultStream() {
  try {
    return Connectivity().onConnectivityChanged;
  } on MissingPluginException {
    return const Stream<List<ConnectivityResult>>.empty();
  } catch (_) {
    return const Stream<List<ConnectivityResult>>.empty();
  }
}

/// Retorna `true` quando pelo menos um resultado de conectividade não for `none`.
bool isConnectedResults(List<ConnectivityResult> results) {
  return results.isNotEmpty &&
      !results.every(
        (ConnectivityResult result) => result == ConnectivityResult.none,
      );
}
