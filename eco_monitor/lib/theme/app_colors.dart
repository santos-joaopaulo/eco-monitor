import "package:flutter/material.dart";

// Palette ----------------------------------------------------------------- //

/// Design tokens shared by every screen of the app.
abstract final class AppColors {
  // Identity: sea green (clean rivers)
  static const Color primary = Color(0xFF58A29D);

  /// Darker primary used behind small white text (contrast 5.4:1, WCAG AA).
  static const Color primaryAccessible = Color(0xFF2F746E);

  static const Color background = Color(0xFFF6F9F8);
  static const Color surface = Colors.white;

  /// Neutral background shown while the map tiles are loading.
  static const Color mapBackground = Color(0xFFE8EFEC);

  static const Color iconTint = Color(0xFFE3F1EF);
  static const Color timelineLine = Color(0xFFCFE5E2);

  // Text
  static const Color textPrimary = Color(0xFF1B2B2A);
  static const Color textSecondary = Color(0xFF5C6F6C);
  static const Color textMuted = Color(0xFF6B7280);

  // State
  static const Color active = Color(0xFF2E7D32);
  static const Color inactive = Color(0xFF9CA3AF);
  static const Color inactiveBackground = Color(0xFFF3F4F6);

  // Biosafety warning
  static const Color warningBackground = Color(0xFFFDE2E2);
  static const Color warningText = Color(0xFF9B1C1C);

  // Residue color code (tones chosen with contrast >= 3:1 over `iconTint`,
  // since the app is used outdoors, under strong light).
  static const Color medicine = Color(0xFFE65100); // orange
  static const Color battery = Color(0xFF2E7D32); // green
  static const Color sharps = Color(0xFF5B7C99); // bluish grey
}
