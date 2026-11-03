
import 'package:flutter/material.dart';


// Classes ----------------------------------------------------------------- //


class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Color(0xFF58A29D),
          ),

          SizedBox(height: 16),

          Text(
            "Guia de Descarte",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 8),

          Text(
            "Instruções para descartar remédios, pilhas e seringas.",
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
