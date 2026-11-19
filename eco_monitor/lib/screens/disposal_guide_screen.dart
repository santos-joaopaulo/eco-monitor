import "package:flutter/material.dart";

import "../domain/entities/residue.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "../theme/eco_theme.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/eco_app_bar.dart";
import "../widgets/residue_card.dart";
import "../widgets/residue_style.dart";

/// Screen 1: list of residues with the button that starts each guide.
class DisposalGuideScreen extends StatelessWidget {
  const DisposalGuideScreen({
    super.key,
    required this.repository,
    required this.onStartGuide,
  });

  final DisposalGuideRepository repository;
  final ValueChanged<Residue> onStartGuide;

  @override
  Widget build(BuildContext context) {
    final List<Residue> residues = repository.listResidues();

    return Scaffold(
      backgroundColor: EcoColors.background,
      appBar: const EcoAppBar(title: "GUIA DE DESCARTE"),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kEcoContentHorizontalPadding,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),
            child: ListView(
              // The bottom menu floats over the content: reserve its space.
              padding: EdgeInsets.fromLTRB(
                0,
                24,
                0,
                CustomBottomNavBar.reservedBottomInset(context),
              ),
              children: [
                const _Header(),
                const SizedBox(height: 24),
                for (final Residue residue in residues) ...[
                  ResidueCard(
                    icon: residue.type.icon,
                    iconColor: residue.type.color,
                    title: residue.title,
                    description: residue.description,
                    buttonLabel: "Iniciar",
                    info:
                        "${residue.minutes} min · ${residue.totalSteps} passos",
                    infoWithClock: true,
                    // Progress resume does not exist yet: every category starts
                    // the guide from the first step.
                    onPressed: () => onStartGuide(residue),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            "Como descartar certo?",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: EcoColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Escolha o material e siga o passo a passo antes de levar ao ponto de coleta.",
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: EcoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
