
import 'package:flutter/material.dart';


// Classes ----------------------------------------------------------------- //


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            Icons.compass_calibration_outlined,
            size: 64,
            color: Color(0xFF58A29D),
          ),

          SizedBox(height: 16),

          Text(
            "Mapa de Pontos de Coleta",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 8),

          Text(
            "Visualização do mapa e filtros de resíduos.",
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
