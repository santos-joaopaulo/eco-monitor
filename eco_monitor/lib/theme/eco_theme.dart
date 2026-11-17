import "package:flutter/material.dart";


// Constantes de layout ---------------------------------------------------- //


/// Largura máxima do conteúdo em telas largas (tablet / web).
const double kEcoMaxContentWidth = 560;


// Paleta ------------------------------------------------------------------ //


abstract final class EcoColors {
  // Identidade: verde-água (rios limpos)
  static const Color primaria = Color(0xFF58A29D);
  static const Color fundo = Color(0xFFF6F9F8);
  static const Color superficie = Colors.white;
  static const Color tintaIcone = Color(0xFFE3F1EF);
  static const Color linhaTimeline = Color(0xFFCFE5E2);

  // Texto
  static const Color textoPrincipal = Color(0xFF1B2B2A);
  static const Color textoSecundario = Color(0xFF5C6F6C);

  // Alerta de biossegurança
  static const Color alertaFundo = Color(0xFFFDE2E2);
  static const Color alertaTexto = Color(0xFF9B1C1C);

  // Código de cores dos resíduos (tons escolhidos com contraste >= 3:1
  // sobre `tintaIcone`, pois o app é usado na rua, sob luz forte).
  static const Color remedio = Color(0xFFE65100); // laranja
  static const Color pilha = Color(0xFF2E7D32); // verde
  static const Color perfurocortante = Color(0xFF5B7C99); // cinza-azulado
}
