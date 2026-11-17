import "package:flutter/material.dart";

// Layout constants -------------------------------------------------------- //

/// Maximum content width on wide screens (tablet / web).
const double kEcoMaxContentWidth = 560;

// Palette ----------------------------------------------------------------- //

abstract final class EcoColors {
  // Identity: sea green (clean rivers)
  static const Color primary = Color(0xFF58A29D);

  /// Darker primary used behind small white text (contrast 5.4:1, WCAG AA).
  static const Color primaryAccessible = Color(0xFF2F746E);

  static const Color background = Color(0xFFF6F9F8);
  static const Color surface = Colors.white;
  static const Color iconTint = Color(0xFFE3F1EF);
  static const Color timelineLine = Color(0xFFCFE5E2);

  // Text
  static const Color textPrimary = Color(0xFF1B2B2A);
  static const Color textSecondary = Color(0xFF5C6F6C);

  // Biosafety warning
  static const Color warningBackground = Color(0xFFFDE2E2);
  static const Color warningText = Color(0xFF9B1C1C);

  // Residue color code (tones chosen with contrast >= 3:1 over `iconTint`,
  // since the app is used outdoors, under strong light).
  static const Color medicine = Color(0xFFE65100); // orange
  static const Color battery = Color(0xFF2E7D32); // green
  static const Color sharps = Color(0xFF5B7C99); // bluish grey
}
