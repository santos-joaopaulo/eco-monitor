import "package:material_ui/material_ui.dart";


// Paleta ------------------------------------------------------------------ //


/// Tokens de design compartilhados por todas as telas do aplicativo.
abstract final class AppColors {
  // Identidade: verde água (AppBar, marcadores, "Iniciar rota", "1,2 km", aba ativa)
  static const Color primary = Color(0xFF58a29d);

  /// Tom primário mais escuro usado sob texto branco pequeno (contraste 5.4:1, WCAG AA).
  static const Color primaryAccessible = Color(0xFF2F746E);

  /// Superfície verde-água clara
  static const Color primaryTint = Color(0xFFe6f4f1);
  static const Color iconTint = primaryTint;

  static const Color background = Color(0xFFF6F9F8);
  static const Color surface = Colors.white; // Cards, modal e pílulas de filtro

  /// Contêiner cinza interno dentro dos modais (ex.: "MATERIAIS ACEITOS" / "HORÁRIO").
  static const Color surfaceSection = Color(0xFFeef1f1);

  /// Contorno neutro de campos, cards e caixas de seleção não marcadas.
  static const Color outline = Color(0xFFDFE6E5);

  /// Fundo neutro e áreas de parques exibidas no mapa.
  static const Color mapBackground = Color(0xFFE8EFEC);
  static const Color mapPark = Color(0xFFd5ebd3);

  static const Color timelineLine = Color(0xFFCFE5E2);

  // Texto
  static const Color textPrimary = Color(0xFF1c2b2a);
  static const Color textSecondary = Color(0xFF7a8886);
  static const Color textMuted = Color(0xFF757D85);

  // Estado
  /// Indicador verde-água usado no rótulo de status "• Ativo" no card do ponto.
  static const Color active = Color(0xFF58a29d);
  static const Color inactive = Color(0xFF9CA3AF);
  static const Color inactiveBackground = Color(0xFFF3F4F6);

  /// Azul clássico do indicador de localização do usuário (alto contraste sobre mapas claros).
  static const Color userLocation = Color(0xFF1E88E5);

  // Alerta de biossegurança
  static const Color warningBackground = Color(0xFFFDE2E2);
  static const Color warningText = Color(0xFF9B1C1C);

  // Código de cores dos resíduos (tons escolhidos com contraste >= 3:1 sobre `iconTint`,
  // pois o app é usado ao ar livre, sob luz forte).
  static const Color medicine = Color(0xFFE65100);
  static const Color battery = Color(0xFF2E7D32);
  static const Color sharps = Color(0xFF5B7C99);
  static const Color electronics = Color(0xFF5E35B1);
}
