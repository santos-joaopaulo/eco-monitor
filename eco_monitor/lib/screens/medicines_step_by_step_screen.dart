import "package:flutter/material.dart";

import "../domain/entities/disposal_guide.dart";
import "../domain/entities/residue.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "../theme/eco_theme.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/eco_app_bar.dart";
import "../widgets/eco_card.dart";
import "../widgets/residue_style.dart";
import "../widgets/step_timeline_item.dart";
import "../widgets/warning_box.dart";

/// Screen 2: step-by-step disposal of expired medicines.
class MedicinesStepByStepScreen extends StatelessWidget {
  const MedicinesStepByStepScreen({
    super.key,
    required this.repository,
    required this.onShowCollectionPoints,
  });

  final DisposalGuideRepository repository;

  /// Called with the residue type when "Ver pontos no mapa" is tapped.
  final ValueChanged<ResidueType> onShowCollectionPoints;

  static const double _buttonHeight = 56;

  @override
  Widget build(BuildContext context) {
    final DisposalGuide? guide = repository.stepsGuideFor(ResidueType.medicine);

    return Scaffold(
      backgroundColor: EcoColors.background,
      appBar: EcoAppBar(
        title: "REMÉDIOS",
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: guide == null
          ? const Center(child: Text("Guia indisponível no momento."))
          : _Content(
              guide: guide,
              buttonHeight: _buttonHeight,
              onShowCollectionPoints: onShowCollectionPoints,
            ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.guide,
    required this.buttonHeight,
    required this.onShowCollectionPoints,
  });

  final DisposalGuide guide;
  final double buttonHeight;
  final ValueChanged<ResidueType> onShowCollectionPoints;

  @override
  Widget build(BuildContext context) {
    final double navBarInset = CustomBottomNavBar.reservedBottomInset(context);
    const ResidueType type = ResidueType.medicine;

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),
            child: ListView(
              // Space for the floating button + bottom menu.
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                navBarInset + buttonHeight + 32,
              ),
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(type.icon, size: 32, color: type.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          guide.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: EcoColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  guide.subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: EcoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                WarningBox(message: guide.warning),
                const SizedBox(height: 16),
                EcoCard(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                    children: [
                      for (var i = 0; i < guide.steps.length; i++)
                        StepTimelineItem(
                          number: i + 1,
                          title: guide.steps[i].title,
                          description: guide.steps[i].description,
                          isLast: i == guide.steps.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Wide floating button, right above the bottom menu.
        Positioned(
          left: 20,
          right: 20,
          bottom: navBarInset + 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kEcoMaxContentWidth - 40,
              ),
              child: ElevatedButton.icon(
                onPressed: () => onShowCollectionPoints(type),
                icon: const Icon(Icons.location_on_outlined, size: 26),
                label: const Text("Ver pontos no mapa"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EcoColors.primaryAccessible,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.black.withAlpha(80),
                  minimumSize: Size(double.infinity, buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
