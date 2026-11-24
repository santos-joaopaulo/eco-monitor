import "dart:convert";

import "package:flutter/services.dart";


// Provider ----------------------------------------------------------------- //


/// Resolve o token público do Mapbox na inicialização do app.
///
/// Ordem de resolução:
/// 1. Variável de compilação `--dart-define=MAPBOX_ACCESS_TOKEN` (README);
/// 2. Arquivo local `assets/config/mapbox_token.txt` (gitignored), que faz o
///    `flutter build apk` funcionar sem o `--dart-define`.
class MapboxTokenProvider {
  MapboxTokenProvider._();

  /// Token resolvido; vazio quando nenhuma fonte está disponível.
  static String token = "";

  /// Token capturado em tempo de compilação via `--dart-define`.
  static const String compileToken = String.fromEnvironment("MAPBOX_ACCESS_TOKEN");

  /// Carrega o token local opcional. Deve ser chamado antes de `runApp`.
  static Future<void> loadLocalToken() async {
    if (compileToken.isNotEmpty) {
      token = compileToken;
      return;
    }

    try {
      final bytes = await rootBundle.load("assets/config/mapbox_token.txt");
      final String content = utf8.decode(bytes.buffer.asUint8List()).trim();
      if (content.isNotEmpty) {
        token = content;
      }
    } catch (_) {
      // Arquivo ausente ou ilegível: o app segue em modo de lista.
    }
  }
}
