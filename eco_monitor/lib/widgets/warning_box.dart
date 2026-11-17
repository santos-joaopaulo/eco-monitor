import "package:flutter/material.dart";

import "../theme/eco_theme.dart";


/// Biosafety warning box (pink background, red icon and text).
class WarningBox extends StatelessWidget {
  const WarningBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: "Atenção. $message",
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: EcoColors.warningBackground,
          borderRadius: BorderRadius.circular(16),
        ),

        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 26,
              color: EcoColors.warningText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: EcoColors.warningText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
