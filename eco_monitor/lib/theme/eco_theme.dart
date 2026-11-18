import "package:flutter/material.dart";

import "app_colors.dart";

// Layout constants -------------------------------------------------------- //

/// Maximum content width on wide screens (tablet / web).
const double kEcoMaxContentWidth = 560;

// Palette ----------------------------------------------------------------- //

/// Semantic aliases kept for the existing screens. New code should use
/// [AppColors] directly.
abstract final class EcoColors {
  static const Color primary = AppColors.primary;
  static const Color primaryAccessible = AppColors.primaryAccessible;
  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color iconTint = AppColors.iconTint;
  static const Color timelineLine = AppColors.timelineLine;

  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;

  static const Color warningBackground = AppColors.warningBackground;
  static const Color warningText = AppColors.warningText;

  static const Color medicine = AppColors.medicine;
  static const Color battery = AppColors.battery;
  static const Color sharps = AppColors.sharps;
  static const Color electronics = AppColors.electronics;
}
