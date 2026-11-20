
import "package:flutter/material.dart";

import "../models/campaign.dart";
import "../models/collection_point.dart";
import "../utils/formatters.dart";
import "eco_card.dart";
import "waste_style.dart";
import "package:eco_monitor/theme/eco_theme.dart";


// Classes ----------------------------------------------------------------- //


/// Card que exibe o resumo de uma campanha de coleta na aba de eventos (RF08).
class CampaignCard extends StatelessWidget {
  const CampaignCard({
    super.key,
    required this.campaign,
    required this.onTap,
    required this.onViewLocation,
  });

  final Campaign campaign;
  final VoidCallback onTap;
  final VoidCallback onViewLocation;

  @override
  Widget build(BuildContext context) {
    final String dateRange = formatCampaignDateRange(
      campaign.startDate,
      campaign.endDate,
    );

    return EcoCard(
      padding: EdgeInsets.zero,

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CampaignStatusBadge(status: campaign.status),
              const SizedBox(height: 12),

              _CampaignBanner(campaign: campaign),
              const SizedBox(height: 14),

              Text(
                campaign.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: EcoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _MetaItem(
                    icon: Icons.location_on_outlined,
                    label: campaign.locationName,
                  ),
                  _MetaItem(
                    icon: Icons.calendar_today_outlined,
                    label: dateRange,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onViewLocation,
                  icon: const Icon(Icons.location_on_outlined, size: 20),
                  label: const Text("Ver local"),
                  style: FilledButton.styleFrom(
                    backgroundColor: EcoColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
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
        ),
      ),
    );
  }
}

/// Distintivo em pílula de alto contraste indicando se a campanha está ativa, prevista ou encerrada (RNF04, RNF17).
class CampaignStatusBadge extends StatelessWidget {
  const CampaignStatusBadge({super.key, required this.status});

  final CampaignStatus status;

  @override
  Widget build(BuildContext context) {
    final _StatusVisual visual = _visualForStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: visual.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            visual.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: visual.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignBanner extends StatelessWidget {
  const _CampaignBanner({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final (Color start, Color end) = switch (campaign.status) {
      CampaignStatus.active => (
        const Color(0xFF9CD4C6),
        const Color(0xFFCDECE4),
      ),
      CampaignStatus.upcoming => (
        const Color(0xFFF6CB94),
        const Color(0xFFFCE4C4),
      ),
      CampaignStatus.finished => (
        const Color(0xFFDDE3E2),
        const Color(0xFFEEF2F1),
      ),
    };

    final WasteType? primaryWaste = campaign.wasteTypes.isNotEmpty
        ? campaign.wasteTypes.first
        : null;

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),

        child: Container(
          height: 116,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [start, end],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),

          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -28,
                child: Container(
                  width: 156,
                  height: 156,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(65),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              if (primaryWaste != null)
                Positioned(
                  right: 16,
                  bottom: 14,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(215),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      primaryWaste.icon,
                      size: 26,
                      color: primaryWaste.color,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: EcoColors.textSecondary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: EcoColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.background,
    required this.dotColor,
    required this.textColor,
  });

  final String label;
  final Color background;
  final Color dotColor;
  final Color textColor;
}


// Methods ----------------------------------------------------------------- //


_StatusVisual _visualForStatus(CampaignStatus status) {
  return switch (status) {
    CampaignStatus.active => const _StatusVisual(
      label: "Ativa",
      background: Color(0xFFE3F5EC),
      dotColor: EcoColors.active,
      textColor: Color(0xFF1B5E20),
    ),
    CampaignStatus.upcoming => const _StatusVisual(
      label: "Em breve",
      background: Color(0xFFFEF3C7),
      dotColor: Color(0xFFD97706),
      textColor: Color(0xFF92400E),
    ),
    CampaignStatus.finished => const _StatusVisual(
      label: "Encerrada",
      background: EcoColors.inactiveBackground,
      dotColor: EcoColors.inactive,
      textColor: EcoColors.textSecondary,
    ),
  };
}
