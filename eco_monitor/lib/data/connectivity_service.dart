import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/services.dart";


// Classes ----------------------------------------------------------------- //


/// Encapsulamento leve em torno de [Connectivity] que expõe o status online
/// do dispositivo como uma stream de broadcast e uma verificação pontual (RNF10).
///
/// Aceita sobreposições opcionais de [connectivityStream] e [checkConnectivity] para
/// testes unitários e de widgets determinísticos.
class ConnectivityService {
  ConnectivityService({
    Stream<List<ConnectivityResult>>? connectivityStream,
    this.checkConnectivity,
  }) {
    final Stream<List<ConnectivityResult>> sourceStream =
        connectivityStream ?? _defaultStream();

    _subscription = sourceStream.listen(
      (List<ConnectivityResult> results) {
        final bool online = isConnectedResults(results);
        _lastKnownOnline = online;
        if (!_controller.isClosed) {
          _controller.add(online);
        }
      },
      onError: (_) {
        // Ignora erros de stream da plataforma (ex.: plugin ausente em testes).
      },
    );
  }

  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  bool _lastKnownOnline = true;

  /// Estado de conectividade observado mais recentemente.
  bool get lastKnownOnline => _lastKnownOnline;

  /// Emite `true` quando o dispositivo está online e `false` caso contrário.
  Stream<bool> get isOnline => _controller.stream;


  // Methods --------------------------------------------------------------- //


  /// Retorna se o dispositivo possui uma interface de rede disponível no momento.
  Future<bool> checkNow() async {
    try {
      final Future<List<ConnectivityResult>> Function() checker =
          checkConnectivity ?? Connectivity().checkConnectivity;
      final List<ConnectivityResult> results = await checker();
      final bool online = isConnectedResults(results);
      _lastKnownOnline = online;
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
    _subscription.cancel();
    _controller.close();
  }
}


// Methods ----------------------------------------------------------------- //


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
