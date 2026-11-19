import "package:flutter/material.dart";

import "app_colors.dart";

// Layout constants -------------------------------------------------------- //

/// Maximum width of a centered content surface on wide screens (tablet / web).
///
/// Full-bleed surfaces such as the map and the app bar are exempt. Cards,
/// sheets, filters and other floating components use this same surface width
/// so the layout keeps a smartphone-like reading width.
const double kEcoMaxContentWidth = 500;

/// Horizontal margin between the centered content surface and the screen edges.
const double kEcoContentHorizontalPadding = 16;

// Palette ----------------------------------------------------------------- //

/// Semantic aliases kept for the existing screens. New code should use
/// [AppColors] directly.
abstract final class EcoColors {
  static const Color primary = AppColors.primary;
  static const Color primaryAccessible = AppColors.primaryAccessible;
  static const Color primaryTint = AppColors.primaryTint;

  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color surfaceSection = AppColors.surfaceSection;
  static const Color iconTint = AppColors.iconTint;
  static const Color timelineLine = AppColors.timelineLine;

  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textMuted = AppColors.textMuted;

  static const Color active = AppColors.active;
  static const Color inactive = AppColors.inactive;
  static const Color inactiveBackground = AppColors.inactiveBackground;

  static const Color warningBackground = AppColors.warningBackground;
  static const Color warningText = AppColors.warningText;

  static const Color medicine = AppColors.medicine;
  static const Color battery = AppColors.battery;
  static const Color sharps = AppColors.sharps;
  static const Color electronics = AppColors.electronics;
}
