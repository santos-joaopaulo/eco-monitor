import "package:material_ui/material_ui.dart";

import "../domain/entities/waste_type.dart";
import "../theme/app_colors.dart";


// Extensions -------------------------------------------------------------- //


/// Tokens visuais (ícone, cor e rótulo pt-BR) para cada [WasteType].
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

  /// Rótulo curto usado pelos filtros compactos do mapa.
  String get filterLabel => switch (this) {
    WasteType.medicines => "Remédios",
    WasteType.batteries => "Pilhas",
    WasteType.sharps => "Seringas",
    WasteType.electronics => "Eletrônicos",
  };

  /// Título em letras maiúsculas exibido na AppBar da tela de passo a passo.
  String get appBarTitle => label.toUpperCase();
}
