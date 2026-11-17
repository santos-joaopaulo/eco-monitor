import "package:flutter/material.dart";

import "../domain/entities/residuo.dart";
import "../theme/eco_theme.dart";


/// Ícone e cor de cada tipo de resíduo (código de cores do projeto:
/// laranja = remédios, verde = pilhas, cinza-azulado = seringas).
extension ResiduoEstilo on TipoResiduo {
  IconData get icone => switch (this) {
        TipoResiduo.medicamento => Icons.medication_rounded,
        TipoResiduo.pilha => Icons.battery_full_rounded,
        TipoResiduo.perfurocortante => Icons.vaccines_rounded,
      };

  Color get cor => switch (this) {
        TipoResiduo.medicamento => EcoColors.remedio,
        TipoResiduo.pilha => EcoColors.pilha,
        TipoResiduo.perfurocortante => EcoColors.perfurocortante,
      };
}
