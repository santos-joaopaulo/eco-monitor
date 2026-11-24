// Classes ------------------------------------------------------------------ //


/// Utilitário centralizado de sanitização e esterilização de dados de entrada,
/// prevenindo injeções de scripts (XSS), caracteres de controle e estouro de buffers (RNF06, RNF07).
abstract final class InputSanitizer {
  /// Expressão regular para identificar e remover blocos completos de script e seu conteúdo interno.
  static final RegExp _scriptBlockPattern = RegExp(
    r"<script[\s\S]*?<\/script>",
    caseSensitive: false,
  );

  /// Expressão regular para identificar e remover blocos completos de style e seu conteúdo interno.
  static final RegExp _styleBlockPattern = RegExp(
    r"<style[\s\S]*?<\/style>",
    caseSensitive: false,
  );

  /// Expressão regular para identificar tags HTML e de script perigosas.
  static final RegExp _htmlTagPattern = RegExp(
    r"<[^>]*>",
    multiLine: true,
    caseSensitive: false,
  );

  /// Expressão regular para identificar caracteres ASCII de controle e Unicode invisíveis/direcionais.
  static final RegExp _controlCharactersPattern = RegExp(
    r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\u200B-\u200F\u202A-\u202E\uFEFF]",
  );

  /// Expressão regular para normalizar espaços e tabs repetidos.
  static final RegExp _multipleWhitespacePattern = RegExp(r"[ \t]+");


// Methods ------------------------------------------------------------------ //


  /// Sanitiza um texto puro removendo tags HTML, caracteres de controle e truncando
  /// no tamanho máximo especificado por [maxLength].
  static String sanitizeText(String? input, {int maxLength = 250}) {
    if (input == null || input.isEmpty) {
      return "";
    }

    // 1. Remove caracteres de controle e invisíveis
    String sanitized = input.replaceAll(_controlCharactersPattern, "");

    // 2. Remove blocos inteiros de script e style com seu conteúdo interno
    sanitized = sanitized.replaceAll(_scriptBlockPattern, " ");
    sanitized = sanitized.replaceAll(_styleBlockPattern, " ");

    // 3. Remove tags HTML residuais
    sanitized = sanitized.replaceAll(_htmlTagPattern, "");

    // 4. Normaliza espaços múltiplos mantendo quebras de linha se existirem
    sanitized = sanitized.replaceAll(_multipleWhitespacePattern, " ");

    // 5. Trunca no limite máximo seguro
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized.trim();
  }
}
