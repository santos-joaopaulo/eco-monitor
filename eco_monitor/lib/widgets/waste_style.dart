import "package:flutter/material.dart";

import "../models/collection_point.dart";
import "../theme/app_colors.dart";

// Extensions -------------------------------------------------------------- //

/// Visual tokens (icon, color and pt-BR label) for each [WasteType].
extension WasteTypeStyle on WasteType {
  IconData get icon => switch (this) {
    WasteType.medicines => Icons.medication_rounded,
    WasteType.batteries => Icons.battery_full_rounded,
    WasteType.sharps => Icons.vaccines_rounded,
    WasteType.electronics => Icons.devices_other_rounded,
  };

  Color get color => switch (this) {
    WasteType.medicines => AppColors.medicine,
    WasteType.batteries => AppColors.battery,
    WasteType.sharps => AppColors.sharps,
    WasteType.electronics => AppColors.electronics,
  };

  String get label => switch (this) {
    WasteType.medicines => "Remédios",
    WasteType.batteries => "Pilhas e baterias",
    WasteType.sharps => "Seringas e agulhas",
    WasteType.electronics => "Lixo eletrônico",
  };

  /// Short label used by the compact map filters.
  String get filterLabel => switch (this) {
    WasteType.medicines => "Remédios",
    WasteType.batteries => "Pilhas",
    WasteType.sharps => "Seringas",
    WasteType.electronics => "Eletrônicos",
  };
}
