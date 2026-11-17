import "package:flutter/material.dart";

import "../domain/entities/residue.dart";
import "../theme/eco_theme.dart";

/// Icon and color of each residue type (color code of the project:
/// orange = medicines, green = batteries, bluish grey = syringes).
extension ResidueStyle on ResidueType {
  IconData get icon => switch (this) {
    ResidueType.medicine => Icons.medication_rounded,
    ResidueType.battery => Icons.battery_full_rounded,
    ResidueType.sharps => Icons.vaccines_rounded,
  };

  Color get color => switch (this) {
    ResidueType.medicine => EcoColors.medicine,
    ResidueType.battery => EcoColors.battery,
    ResidueType.sharps => EcoColors.sharps,
  };

  /// Label shown to the user (filter of the map, for example).
  String get label => switch (this) {
    ResidueType.medicine => "Remédios",
    ResidueType.battery => "Pilhas e baterias",
    ResidueType.sharps => "Seringas e agulhas",
  };
}
