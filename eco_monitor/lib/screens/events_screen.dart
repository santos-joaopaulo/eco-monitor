import "package:flutter/material.dart";

import "../data/app_data_sync.dart";
import "../data/campaigns_repository.dart";
import "../theme/app_colors.dart";

// Classes ----------------------------------------------------------------- //

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, this.repository, this.dataSync});

  final CampaignsRepository? repository;
  final AppDataSync? dataSync;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: AppColors.primary,
          ),

          SizedBox(height: 16),

          Text(
            "Campanhas Ativas",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 8),

          Text(
            "Mutirões e campanhas temporárias de descarte.",
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
