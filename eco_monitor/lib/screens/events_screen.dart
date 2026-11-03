
import 'package:flutter/material.dart';


// Classes ----------------------------------------------------------------- //


class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: Color(0xFF58A29D),
          ),

          SizedBox(height: 16),

          Text(
            "Campanhas Ativas",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 8),

          Text(
            "Mutirões e campanhas temporárias de descarte.",
            style: TextStyle(color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
