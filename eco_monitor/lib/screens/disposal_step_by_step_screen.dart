import "package:material_ui/material_ui.dart";

import "../domain/entities/disposal_guide.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../widgets/custom_bottom_nav_bar.dart";
import "../widgets/eco_app_bar.dart";
import "../widgets/eco_card.dart";
import "../widgets/step_timeline_item.dart";
import "../widgets/warning_box.dart";
import "../widgets/waste_style.dart";


// Classes ------------------------------------------------------------------ //


/// Tela de passo a passo de descarte compartilhada por todas as categorias de resíduos (RF07).
class DisposalStepByStepScreen extends StatelessWidget {
  const DisposalStepByStepScreen({
    super.key,
    required this.wasteType,
    required this.repository,
    required this.onShowCollectionPoints,
    this.banner,
  });

  final WasteType wasteType;
  final DisposalGuideRepository repository;

  /// Chamado com o tipo de resíduo quando "Ver pontos no mapa" é tocado.
  final ValueChanged<WasteType> onShowCollectionPoints;

  /// Banner de conectividade exibido abaixo da barra superior.
  final Widget? banner;

  static const double _buttonHeight = 56;

  @override
  Widget build(BuildContext context) {
    final DisposalGuide? guide = repository.stepsGuideFor(wasteType);

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: EcoAppBar(
        title: wasteType.appBarTitle,
        onBack: () => Navigator.of(context).maybePop(),
      ),

      body: Column(
        children: [
          ?banner,

          Expanded(
            child: guide == null
                ? const Center(child: Text("Guia indisponível no momento."))
                : _Content(
                    wasteType: wasteType,
                    guide: guide,
                    buttonHeight: _buttonHeight,
                    onShowCollectionPoints: onShowCollectionPoints,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.wasteType,
    required this.guide,
    required this.buttonHeight,
    required this.onShowCollectionPoints,
  });

  final WasteType wasteType;
  final DisposalGuide guide;
  final double buttonHeight;
  final ValueChanged<WasteType> onShowCollectionPoints;

  @override
  Widget build(BuildContext context) {
    final double navBarInset = CustomBottomNavBar.reservedBottomInset(context);
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final double dynamicButtonHeight =
        (buttonHeight * textScale.clamp(1.0, 1.8)).roundToDouble();

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kEcoContentHorizontalPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

              child: ListView(
                // Espaço reservado para o botão flutuante e o menu inferior.
                padding: EdgeInsets.fromLTRB(
                  0,
                  24,
                  0,
                  navBarInset + dynamicButtonHeight + 36,
                ),
                children: [
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          wasteType.icon,
                          size: 32,
                          color: wasteType.color,
                        ),
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
                              color: AppColors.textPrimary,
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
                      color: AppColors.textSecondary,
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
        ),

        // Botão flutuante largo, posicionado logo acima do menu inferior.
        Positioned(
          left: kEcoContentHorizontalPadding,
          right: kEcoContentHorizontalPadding,
          bottom: navBarInset + 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

              child: ElevatedButton(
                onPressed: () => onShowCollectionPoints(wasteType),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: Colors.black.withAlpha(80),
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Icon(Icons.location_on_outlined, size: 26),
                    SizedBox(width: 8),

                    Flexible(
                      child: Text(
                        "Ver pontos no mapa",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
