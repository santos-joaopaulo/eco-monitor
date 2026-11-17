import "package:flutter/material.dart";

import "../data/app_data_sync.dart";
import "../data/point_suggestions_repository.dart";
import "../theme/app_colors.dart";

// Classes ----------------------------------------------------------------- //

class SuggestScreen extends StatelessWidget {
  const SuggestScreen({super.key, this.repository, this.dataSync});

  final PointSuggestionsRepository? repository;
  final AppDataSync? dataSync;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            Icons.add_location_alt_outlined,
            size: 64,
            color: AppColors.primary,
          ),

          SizedBox(height: 16),

          Text(
            "Sugerir Novo Ponto",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          SizedBox(height: 8),

          Text(
            "Ajude a cadastrar novos pontos de coleta.",
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
