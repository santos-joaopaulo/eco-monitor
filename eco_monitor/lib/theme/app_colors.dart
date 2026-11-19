import "package:flutter/material.dart";

// Palette ----------------------------------------------------------------- //

/// Design tokens shared by every screen of the app.
abstract final class AppColors {
  // Identity: sea green (AppBar, pins, "Iniciar rota", "1,2 km", aba ativa)
  static const Color primary = Color(0xFF58a29d);

  /// Darker primary used behind small white text (contrast 5.4:1, WCAG AA).
  static const Color primaryAccessible = Color(0xFF2F746E);

  /// Light teal surface
  static const Color primaryTint = Color(0xFFe6f4f1);
  static const Color iconTint = primaryTint;

  static const Color background = Color(0xFFF6F9F8);
  static const Color surface = Colors.white; // Cards, modal e pílulas de filtro

  /// Inner grey container inside modals (e.g., "MATERIAIS ACEITOS" / "HORÁRIO").
  static const Color surfaceSection = Color(0xFFeef1f1);

  /// Neutral background and park areas shown on the map.
  static const Color mapBackground = Color(0xFFE8EFEC);
  static const Color mapPark = Color(0xFFd5ebd3);

  static const Color timelineLine = Color(0xFFCFE5E2);

  // Text
  static const Color textPrimary = Color(0xFF1c2b2a);
  static const Color textSecondary = Color(0xFF7a8886);
  static const Color textMuted = Color(0xFF757D85);

  // State
  /// Teal indicator used in the "• Ativo" status label on the point card.
  static const Color active = Color(0xFF58a29d);
  static const Color inactive = Color(0xFF9CA3AF);
  static const Color inactiveBackground = Color(0xFFF3F4F6);

  /// Classic blue of the user location puck (high contrast over light maps).
  static const Color userLocation = Color(0xFF1E88E5);

  // Biosafety warning
  static const Color warningBackground = Color(0xFFFDE2E2);
  static const Color warningText = Color(0xFF9B1C1C);

  // Residue color code (tones chosen with contrast >= 3:1 over `iconTint`,
  // since the app is used outdoors, under strong light).
  static const Color medicine = Color(0xFFE65100); // orange
  static const Color battery = Color(0xFF2E7D32); // green
  static const Color sharps = Color(0xFF5B7C99); // bluish grey
  static const Color electronics = Color(0xFF5E35B1); // deep purple
}
