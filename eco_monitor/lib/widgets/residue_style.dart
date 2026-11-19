import "package:flutter/material.dart";

import "../domain/entities/residue.dart";
import "../theme/eco_theme.dart";

/// Ícone, cor e rótulos de cada tipo de resíduo (código de cores do projeto:
/// laranja = remédios, verde = baterias, cinza-azulado = seringas,
/// roxo escuro = eletrônicos).
extension ResidueStyle on ResidueType {
  IconData get icon => switch (this) {
    ResidueType.medicine => Icons.medication_rounded,
    ResidueType.battery => Icons.battery_full_rounded,
    ResidueType.sharps => Icons.vaccines_rounded,
    ResidueType.electronics => Icons.devices_other_rounded,
  };

  Color get color => switch (this) {
    ResidueType.medicine => EcoColors.medicine,
    ResidueType.battery => EcoColors.battery,
    ResidueType.sharps => EcoColors.sharps,
    ResidueType.electronics => EcoColors.electronics,
  };

  /// Rótulo exibido ao usuário (filtro do mapa, por exemplo).
  String get label => switch (this) {
    ResidueType.medicine => "Remédios",
    ResidueType.battery => "Pilhas e baterias",
    ResidueType.sharps => "Seringas e agulhas",
    ResidueType.electronics => "Lixo eletrônico",
  };

  /// Título em letras maiúsculas exibido na AppBar da tela de passo a passo.
  String get appBarTitle => switch (this) {
    ResidueType.medicine => "REMÉDIOS",
    ResidueType.battery => "PILHAS E BATERIAS",
    ResidueType.sharps => "SERINGAS E AGULHAS",
    ResidueType.electronics => "LIXO ELETRÔNICO",
  };
}
