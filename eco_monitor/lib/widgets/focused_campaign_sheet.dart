import "dart:async";

import "package:material_ui/material_ui.dart";

import "../models/campaign.dart";
import "../services/location_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "../utils/geo.dart";
import "campaign_card.dart";
import "waste_style.dart";


// Classes ----------------------------------------------------------------- //


/// Painel inferior padronizado com os detalhes e ações da campanha em foco no mapa (RF09).
///
/// Segue rigorosamente o padrão visual do [CollectPointSheet], posicionando-se na área inferior
/// e sobrepondo a barra de navegação para manter a experiência limpa e focada no mapa.
class FocusedCampaignSheet extends StatefulWidget {
  const FocusedCampaignSheet({
    super.key,
    required this.campaign,
    required this.onClearCampaign,
    this.onStartRoute,
    this.distanceMeters,
    this.locationService,
  });

  final Campaign campaign;
  final VoidCallback onClearCampaign;
  final VoidCallback? onStartRoute;
  final double? distanceMeters;
  final LocationService? locationService;

  @override
  State<FocusedCampaignSheet> createState() => _FocusedCampaignSheetState();
}

class _FocusedCampaignSheetState extends State<FocusedCampaignSheet> {
  double? _distanceMeters;
  double _dragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _distanceMeters = widget.distanceMeters;
    if (_distanceMeters == null) {
      unawaited(_calculateDistance());
    }
  }

  @override
  void didUpdateWidget(covariant FocusedCampaignSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.distanceMeters != oldWidget.distanceMeters) {
      _distanceMeters = widget.distanceMeters;
    }
    if (widget.campaign.id != oldWidget.campaign.id ||
        widget.campaign.latitude != oldWidget.campaign.latitude ||
        widget.campaign.longitude != oldWidget.campaign.longitude) {
      if (widget.distanceMeters == null) {
        unawaited(_calculateDistance());
      }
    }
  }

  Future<void> _calculateDistance() async {
    final LocationService service =
        widget.locationService ?? const LocationService();
    try {
      final UserLocation? position = await service.currentPosition();
      if (!mounted || position == null) {
        return;
      }

      final double distance = distanceInMeters(
        position.latitude,
        position.longitude,
        widget.campaign.latitude,
        widget.campaign.longitude,
      );

      setState(() {
        _distanceMeters = distance;
      });
    } catch (_) {
      // Falhas no GPS mantêm o estado como nulo (distância indisponível).
    }
  }


  // Methods --------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double maxSheetHeight = screenHeight * (2.0 / 3.0);
    final List<WasteCategory> sortedWasteTypes =
        widget.campaign.wasteTypes.toList()
          ..sort(
            (WasteCategory a, WasteCategory b) => a.index.compareTo(b.index),
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

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => _dragDistance = 0.0,
                  onVerticalDragUpdate: (DragUpdateDetails details) {
                    _dragDistance += details.primaryDelta ?? 0.0;
                  },
                  onVerticalDragEnd: (DragEndDetails details) {
                    final double velocity = details.primaryVelocity ?? 0.0;
                    if (velocity > 200 || _dragDistance > 20) {
                      widget.onClearCampaign();
                    }
                  },

                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.transparent,
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

                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),

                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                      widget.campaign.title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  CampaignStatusBadge(
                                    status: widget.campaign.status,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 8),

                            IconButton(
                              onPressed: widget.onClearCampaign,
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

                        Row(
                          children: [
                            const Icon(
                              Icons.directions_walk_rounded,
                              size: 18,
                              color: AppColors.primaryAccessible,
                            ),
                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                _distanceMeters == null
                                    ? "Distância indisponível"
                                    : formatDistance(_distanceMeters!),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        _CampaignInfoRow(
                          icon: Icons.place_outlined,
                          title: widget.campaign.locationName,
                          subtitle: widget.campaign.address.isNotEmpty &&
                                  widget.campaign.address !=
                                      widget.campaign.locationName
                              ? widget.campaign.address
                              : null,
                        ),
                        const SizedBox(height: 10),

                        _CampaignInfoRow(
                          icon: Icons.calendar_today_outlined,
                          title: formatCampaignPeriod(
                            widget.campaign.startDate,
                            widget.campaign.endDate,
                          ),
                        ),

                        if (sortedWasteTypes.isNotEmpty) ...[
                          const SizedBox(height: 14),
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
                                const _SectionLabel(
                                  label: "MATERIAIS COLETADOS",
                                ),
                                const SizedBox(height: 8),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final WasteCategory type
                                        in sortedWasteTypes)
                                      WasteTypeBadge(type: type),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (widget.campaign.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.campaign.description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],

                        if (widget.onStartRoute != null) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,

                            child: FilledButton.icon(
                              onPressed: widget.onStartRoute,
                              icon: const Icon(
                                Icons.directions_rounded,
                                size: 20,
                              ),
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
              ],
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
