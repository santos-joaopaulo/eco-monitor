import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

import "../domain/entities/waste_type.dart";
import "../domain/entities/campaign.dart";
import "../presentation/state/campaign_reminders_notifier.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "eco_card.dart";
import "waste_style.dart";


// Classes ------------------------------------------------------------------ //


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
                  color: AppColors.textPrimary,
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

              Row(
                children: [
                  Expanded(
                    child: _CampaignReminderButton(campaign: campaign),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onViewLocation,
                      icon: const Icon(Icons.location_on_outlined, size: 20),
                      label: const Text("Ver local"),
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
        AppColors.campaignActiveGradientStart,
        AppColors.campaignActiveGradientEnd,
      ),
      CampaignStatus.upcoming => (
        AppColors.campaignUpcomingGradientStart,
        AppColors.campaignUpcomingGradientEnd,
      ),
      CampaignStatus.finished => (
        AppColors.campaignFinishedGradientStart,
        AppColors.campaignFinishedGradientEnd,
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
    final double maxItemWidth =
        MediaQuery.sizeOf(context).width - (kEcoContentHorizontalPadding * 2) - 32;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxItemWidth.clamp(120.0, kEcoMaxContentWidth)),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 5),

          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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


// Methods ------------------------------------------------------------------ //


_StatusVisual _visualForStatus(CampaignStatus status) {
  return switch (status) {
    CampaignStatus.active => const _StatusVisual(
      label: "Ativa",
      background: AppColors.campaignActiveBadgeBackground,
      dotColor: AppColors.active,
      textColor: AppColors.campaignActiveBadgeText,
    ),
    CampaignStatus.upcoming => const _StatusVisual(
      label: "Em breve",
      background: AppColors.campaignUpcomingBadgeBackground,
      dotColor: AppColors.campaignUpcomingBadgeDot,
      textColor: AppColors.campaignUpcomingBadgeText,
    ),
    CampaignStatus.finished => const _StatusVisual(
      label: "Encerrada",
      background: AppColors.inactiveBackground,
      dotColor: AppColors.inactive,
      textColor: AppColors.textSecondary,
    ),
  };
}


// Campaign Reminders ------------------------------------------------------- //


class _CampaignReminderButton extends StatelessWidget {
  const _CampaignReminderButton({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    CampaignRemindersNotifier? notifier;
    try {
      notifier = Provider.of<CampaignRemindersNotifier>(context);
    } catch (_) {
      notifier = null;
    }

    final bool isReminderActive =
        notifier?.isReminderActive(campaign.id) ?? false;

    if (isReminderActive) {
      return FilledButton.icon(
        onPressed: () async {
          final ScaffoldMessengerState? messenger =
              ScaffoldMessenger.maybeOf(context);
          if (notifier != null) {
            await notifier.toggleReminder(campaign);
          }
          messenger
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text("Lembrete cancelado."),
                duration: Duration(seconds: 2),
              ),
            );
        },
        icon: const Icon(Icons.notifications_active_rounded, size: 18),
        label: const Text(
          "Lembrete ativado",
          overflow: TextOverflow.ellipsis,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryAccessible,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () async {
        final ScaffoldMessengerState? messenger =
            ScaffoldMessenger.maybeOf(context);
        if (notifier != null) {
          await notifier.toggleReminder(campaign);
        }
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("Lembrete ativado para esta campanha!"),
              backgroundColor: AppColors.primaryAccessible,
              duration: Duration(seconds: 2),
            ),
          );
      },
      icon: const Icon(Icons.notifications_none_outlined, size: 18),
      label: const Text(
        "Lembrar-me",
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
