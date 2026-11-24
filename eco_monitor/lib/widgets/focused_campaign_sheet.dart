import "package:material_ui/material_ui.dart";

import "../models/campaign.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "campaign_card.dart";


// Classes ----------------------------------------------------------------- //


/// Painel inferior com os detalhes e ações da campanha em foco no mapa (RF09).
///
/// Segue o mesmo padrão visual do CollectPointSheet, posicionando-se na área inferior
/// e sobrepondo a barra de navegação para manter o topo do mapa limpo e desobstruído.
class FocusedCampaignSheet extends StatelessWidget {
  const FocusedCampaignSheet({
    super.key,
    required this.campaign,
    required this.onClearCampaign,
    this.onStartRoute,
  });

  final Campaign campaign;
  final VoidCallback onClearCampaign;
  final VoidCallback? onStartRoute;


  // Methods --------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double maxSheetHeight = screenHeight * (2.0 / 3.0);
    final String dateRange = formatCampaignDateRange(
      campaign.startDate,
      campaign.endDate,
    );

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
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),

            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (DragEndDetails details) {
                      if ((details.primaryVelocity ?? 0) > 200) {
                        onClearCampaign();
                      }
                    },

                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.inactive.withAlpha(140),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(14),
                        ),

                        child: const Icon(
                          Icons.event_available_rounded,
                          size: 24,
                          color: AppColors.primaryAccessible,
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,

                              child: Text(
                                campaign.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            CampaignStatusBadge(status: campaign.status),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: onClearCampaign,
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: "Fechar campanha",
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _CampaignInfoRow(
                    icon: Icons.location_on_outlined,
                    title: campaign.locationName,
                    subtitle:
                        campaign.address.isNotEmpty &&
                            campaign.address != campaign.locationName
                        ? campaign.address
                        : null,
                  ),
                  const SizedBox(height: 10),

                  _CampaignInfoRow(
                    icon: Icons.calendar_today_outlined,
                    title: dateRange,
                  ),

                  if (campaign.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      campaign.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],

                  if (onStartRoute != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,

                      child: FilledButton.icon(
                        onPressed: onStartRoute,
                        icon: const Icon(Icons.directions_rounded, size: 20),
                        label: const Text("Traçar rota para a campanha"),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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


// Classes ----------------------------------------------------------------- //


class _CampaignInfoRow extends StatelessWidget {
  const _CampaignInfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryAccessible),
        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
