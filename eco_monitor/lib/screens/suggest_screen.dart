
import 'package:flutter/material.dart';


// Classes ----------------------------------------------------------------- //


class SuggestScreen extends StatelessWidget {
  const SuggestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            Icons.add_location_alt_outlined,
            size: 64,
            color: Color(0xFF58A29D),
          ),

          SizedBox(height: 16),

          Text(
            "Sugerir Novo Ponto",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 8),

          Text(
            "Ajude a cadastrar novos pontos de coleta.",
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
