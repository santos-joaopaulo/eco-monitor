import "package:flutter/material.dart";

import "app_colors.dart";


// Layout constants -------------------------------------------------------- //


/// Largura máxima de uma superfície de conteúdo centralizada em telas largas (tablet / web).
///
/// Superfícies full-bleed, como o mapa e a barra superior, são isentas. Cards,
/// modais, filtros e outros componentes flutuantes usam esta mesma largura de superfície
/// para que o layout preserve uma largura de leitura confortável semelhante à de um smartphone.
const double kEcoMaxContentWidth = 500;

/// Margem horizontal entre a superfície de conteúdo centralizada e as bordas da tela.
const double kEcoContentHorizontalPadding = 16;


// Palette ----------------------------------------------------------------- //


/// Apelidos semânticos mantidos para compatibilidade com as telas existentes.
/// Código novo deve utilizar [AppColors] diretamente.
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
