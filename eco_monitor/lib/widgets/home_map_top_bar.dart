import "package:flutter/material.dart";

import "../domain/entities/waste_type.dart";
import "../models/campaign.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "filter_bar.dart";


// Home map top bar -------------------------------------------------------- //


/// Barra superior flutuante do mapa: filtros, campanha focada e avisos de status.
class HomeMapTopBar extends StatelessWidget {
  const HomeMapTopBar({
    super.key,
    required this.selectedWasteTypes,
    required this.onFilterChanged,
    required this.focusedCampaign,
    required this.onClearCampaign,
    required this.showMapboxTokenWarning,
    required this.isLoadingPoints,
    required this.isEmptyResult,
    required this.emptyMessage,
    required this.locationNotice,
    required this.isListMode,
  });

  final Set<WasteType> selectedWasteTypes;
  final ValueChanged<Set<WasteType>> onFilterChanged;
  final Campaign? focusedCampaign;
  final VoidCallback? onClearCampaign;
  final bool showMapboxTokenWarning;
  final bool isLoadingPoints;
  final bool isEmptyResult;
  final String emptyMessage;
  final Widget? locationNotice;
  final bool isListMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,

      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kEcoContentHorizontalPadding,
          12,
          kEcoContentHorizontalPadding,
          0,
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (focusedCampaign != null) ...[
              _FocusedCampaignChip(
                campaign: focusedCampaign!,
                onClear: onClearCampaign,
              ),
              const SizedBox(height: 8),
            ],

            FilterBar(
              selectedTypes: selectedWasteTypes,
              onChanged: onFilterChanged,
            ),

            if (showMapboxTokenWarning) ...[
              const SizedBox(height: 8),
              const _MapStatusPill(
                message: "Configure o token do Mapbox",
                icon: Icons.info_outline,
              ),
            ],

            if (isLoadingPoints) ...[
              const SizedBox(height: 8),
              const _MapStatusPill(
                message: "Carregando pontos...",
                isLoading: true,
              ),
            ] else if (!isListMode && isEmptyResult) ...[
              const SizedBox(height: 8),

              _MapStatusPill(
                message: emptyMessage,
                icon: Icons.location_off_outlined,
              ),
            ],

            if (locationNotice != null) ...[
              const SizedBox(height: 8),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kEcoMaxContentWidth,
                  ),
                  child: locationNotice,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


// Classes ----------------------------------------------------------------- //


class _FocusedCampaignChip extends StatelessWidget {
  const _FocusedCampaignChip({required this.campaign, this.onClear});

  final Campaign campaign;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

      child: Material(
        color: AppColors.surface,
        elevation: 4,
        shadowColor: Colors.black.withAlpha(45),
        borderRadius: BorderRadius.circular(18),

        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),

          child: Row(
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 22,
                color: AppColors.primaryAccessible,
              ),
              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      campaign.locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: "Fechar campanha",
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapStatusPill extends StatelessWidget {
  const _MapStatusPill({
    required this.message,
    this.icon,
    this.isLoading = false,
  });

  final String message;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

      child: Material(
        color: AppColors.surface.withValues(alpha: 0.95),
        elevation: 2,
        shadowColor: Colors.black.withAlpha(30),
        borderRadius: BorderRadius.circular(20),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon ?? Icons.info_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),

              const SizedBox(width: 8),

              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
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
