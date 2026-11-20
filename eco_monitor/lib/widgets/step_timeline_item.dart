import "package:flutter/material.dart";

import "../theme/eco_theme.dart";

/// Item de uma linha do tempo vertical: círculo verde-água numerado à esquerda, título
/// e descrição à direita, conectados por uma linha fina.
///
/// Marque o último item com [isLast] para ocultar a linha conectora.
class StepTimelineItem extends StatelessWidget {
  const StepTimelineItem({
    super.key,
    required this.number,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  final int number;
  final String title;
  final String description;
  final bool isLast;

  static const double _diameter = 34;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _diameter,
              child: Column(
                children: [
                  Container(
                    width: _diameter,
                    height: _diameter,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: EcoColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "$number",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: EcoColors.timelineLine,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 2, bottom: isLast ? 0 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: EcoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: EcoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
