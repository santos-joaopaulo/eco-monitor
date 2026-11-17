import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/services.dart";

// Classes ----------------------------------------------------------------- //

/// Lightweight wrapper around [Connectivity] that exposes the device's online
/// status as a broadcast stream and a one-shot check (RNF10).
///
/// Accepts optional [connectivityStream] and [checkConnectivity] overrides for
/// deterministic unit and widget tests.
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
        // Ignore platform stream errors (e.g. missing plugin in tests).
      },
    );
  }

  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  bool _lastKnownOnline = true;

  /// Most recently observed connectivity state.
  bool get lastKnownOnline => _lastKnownOnline;

  /// Emits `true` when the device is online, `false` otherwise.
  Stream<bool> get isOnline => _controller.stream;

  // Methods --------------------------------------------------------------- //

  /// Returns whether the device currently has a network interface available.
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

  /// Cancels the underlying connectivity subscription and closes the stream.
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

/// Returns `true` when at least one connectivity result is not `none`.
bool isConnectedResults(List<ConnectivityResult> results) {
  return results.isNotEmpty &&
      !results.every(
        (ConnectivityResult result) => result == ConnectivityResult.none,
      );
}
