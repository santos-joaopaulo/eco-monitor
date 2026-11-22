import "package:material_ui/material_ui.dart";

import "../domain/entities/waste_type.dart";
import "../models/campaign.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "campaign_card.dart";
import "waste_style.dart";


// Methods ----------------------------------------------------------------- //


/// Abre um modal bottom sheet com os detalhes completos de uma [Campaign] (RF09).
Future<void> showCampaignDetailsSheet({
  required BuildContext context,
  required Campaign campaign,
  required VoidCallback onViewLocation,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return CampaignDetailsSheet(
        campaign: campaign,
        onClose: () => Navigator.of(sheetContext).pop(),
        onViewLocation: () {
          Navigator.of(sheetContext).pop();
          onViewLocation();
        },
      );
    },
  );
}


// Classes ----------------------------------------------------------------- //


/// Visualização detalhada de uma campanha de coleta (RF09): descrição, tipos de
/// resíduos aceitos, endereço completo, cronograma e ação para inspecionar o local no mapa.
class CampaignDetailsSheet extends StatelessWidget {
  const CampaignDetailsSheet({
    super.key,
    required this.campaign,
    required this.onClose,
    required this.onViewLocation,
  });

  final Campaign campaign;
  final VoidCallback onClose;
  final VoidCallback onViewLocation;

  @override
  Widget build(BuildContext context) {
    final List<WasteType> sortedWasteTypes = campaign.wasteTypes.toList()
      ..sort((WasteType a, WasteType b) => a.index.compareTo(b.index));

    final bool isLargeFont = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final double maxSheetHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: kEcoMaxContentWidth,
            maxHeight: maxSheetHeight,
          ),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),

            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.inactive.withAlpha(140),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  CampaignStatusBadge(status: campaign.status),
                  const SizedBox(height: 10),

                  Semantics(
                    header: true,
                    child: Text(
                      campaign.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (campaign.description.isNotEmpty) ...[
                    Text(
                      campaign.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  if (sortedWasteTypes.isNotEmpty) ...[
                    const _SectionLabel(label: "MATERIAIS COLETADOS"),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final WasteType type in sortedWasteTypes)
                          _WasteChip(type: type),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel(label: "LOCAL"),
                        const SizedBox(height: 6),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    campaign.locationName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (campaign.address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      campaign.address,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        const _SectionLabel(label: "PERÍODO"),
                        const SizedBox(height: 6),

                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                formatCampaignPeriod(
                                  campaign.startDate,
                                  campaign.endDate,
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (isLargeFont) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onViewLocation,
                        icon: const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                        ),
                        label: const Text("Ver no mapa"),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onClose,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.timelineLine,
                            width: 1.5,
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text("Fechar"),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onClose,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                color: AppColors.timelineLine,
                                width: 1.5,
                              ),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text("Fechar"),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: onViewLocation,
                            icon: const Icon(
                              Icons.location_on_outlined,
                              size: 20,
                            ),
                            label: const Text("Ver no mapa"),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _WasteChip extends StatelessWidget {
  const _WasteChip({required this.type});

  final WasteType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.iconTint,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 18, color: type.color),
          const SizedBox(width: 6),
          Text(
            type.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
