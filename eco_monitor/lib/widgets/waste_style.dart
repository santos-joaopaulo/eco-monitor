import "package:material_ui/material_ui.dart";

import "../domain/entities/waste_type.dart";
import "../theme/app_colors.dart";


// Extensions --------------------------------------------------------------- //


/// Tokens visuais (ícone, cor e rótulo pt-BR) para cada [WasteType].
extension WasteTypeStyle on WasteType {
  IconData get icon => switch (this) {
    WasteType.medicines => Icons.medication_rounded,
    WasteType.batteries => Icons.battery_full_rounded,
    WasteType.sharps => Icons.vaccines_rounded,
    WasteType.electronics => Icons.devices_other_rounded,
    WasteType.glass => Icons.wine_bar_rounded,
  };

  Color get color => switch (this) {
    WasteType.medicines => AppColors.medicine,
    WasteType.batteries => AppColors.battery,
    WasteType.sharps => AppColors.sharps,
    WasteType.electronics => AppColors.electronics,
    WasteType.glass => AppColors.glass,
  };

  String get label => switch (this) {
    WasteType.medicines => "Remédios",
    WasteType.batteries => "Pilhas e baterias",
    WasteType.sharps => "Seringas e agulhas",
    WasteType.electronics => "Lixo eletrônico",
    WasteType.glass => "Vidro",
  };

  /// Rótulo curto usado pelos filtros compactos do mapa.
  String get filterLabel => switch (this) {
    WasteType.medicines => "Remédios",
    WasteType.batteries => "Pilhas",
    WasteType.sharps => "Seringas",
    WasteType.electronics => "Eletrônicos",
    WasteType.glass => "Vidro",
  };

  /// Título em letras maiúsculas exibido na AppBar da tela de passo a passo.
  String get appBarTitle => label.toUpperCase();
}


// Aliases ------------------------------------------------------------------ //


/// Alias semântico para a categoria ou tipo de resíduo aceito.
typedef WasteCategory = WasteType;


// Classes ------------------------------------------------------------------ //


/// Badge padrão oficial para exibição das categorias e tipos de resíduo.
class WasteTypeBadge extends StatelessWidget {
  const WasteTypeBadge({super.key, required this.type});

  final WasteType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.iconTint,
        borderRadius: BorderRadius.circular(20),
      ),

      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,

        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 18, color: type.color),
            const SizedBox(width: 6),

            Flexible(
              child: Text(
                type.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

