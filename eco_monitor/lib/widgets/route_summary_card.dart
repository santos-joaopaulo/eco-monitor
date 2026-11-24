import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../domain/entities/collection_point.dart";
import "../services/route_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "../utils/geo.dart";


// Classes ------------------------------------------------------------------ //


/// Painel de navegação ativa exibido durante o traçado da rota (RF04, RF05).
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.point,
    required this.summary,
    required this.onClose,
    this.activeTravelMode = TravelMode.walking,
    this.onTravelModeChanged,
    this.onOpenExternal,
  });

  final CollectionPoint point;
  final RouteSummary? summary;
  final VoidCallback onClose;
  final TravelMode activeTravelMode;
  final ValueChanged<TravelMode>? onTravelModeChanged;
  final VoidCallback? onOpenExternal;


// Methods ------------------------------------------------------------------ //


  @override
  Widget build(BuildContext context) {
    final RouteSummary? route = summary;
    final TravelMode currentMode = route?.travelMode ?? activeTravelMode;
    final bool isArrived = route?.isArrived ?? false;
    final bool isLargeFont = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    // Ocupa no máximo 1/3 da tela
    final double maxSheetHeight = screenHeight * (1.0 / 3.0);

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

          child: Material(
            color: AppColors.surface,
            elevation: 16,
            shadowColor: Colors.black.withAlpha(60),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,

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
                        onClose();
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            const Text(
                              "DESTINO",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),

                            Semantics(
                              header: true,

                              child: Text(
                                point.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: onClose,
                        tooltip: "Fechar rota",
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,

                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.2,
                      child: SegmentedButton<TravelMode>(
                        segments: const <ButtonSegment<TravelMode>>[
                          ButtonSegment<TravelMode>(
                            value: TravelMode.walking,
                            icon: Icon(Icons.directions_walk_rounded, size: 18),
                            label: Text("A pé"),
                          ),
                          ButtonSegment<TravelMode>(
                            value: TravelMode.cycling,
                            icon: Icon(Icons.directions_bike_rounded, size: 18),
                            label: Text("Bicicleta"),
                          ),
                          ButtonSegment<TravelMode>(
                            value: TravelMode.driving,
                            icon: Icon(Icons.directions_car_rounded, size: 18),
                            label: Text("Carro"),
                          ),
                        ],
                        selected: <TravelMode>{currentMode},
                        onSelectionChanged: (Set<TravelMode> selection) {
                          if (selection.isNotEmpty) {
                            onTravelModeChanged?.call(selection.first);
                          }
                        },
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: AppColors.primary,
                          selectedForegroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.outline),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _RouteMetric(
                          label: "DISTÂNCIA",
                          value: route == null
                              ? "Indisponível"
                              : (isArrived ? "Chegou" : formatDistance(route.distanceMeters)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RouteMetric(
                          label: "TEMPO ESTIMADO",
                          value: route == null
                              ? "Indisponível"
                              : (isArrived
                                  ? "0 min"
                                  : formatDuration(route.estimatedMinutes.toDouble())),
                        ),
                      ),
                    ],
                  ),
                  if (isArrived || (route != null && (route.isOfflineFallback || route.isFromCache))) ...[
                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isArrived || (route?.isFromCache ?? false)
                            ? AppColors.primaryTint
                            : AppColors.surfaceSection,
                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          if (isArrived)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: AppColors.primary,
                            )
                          else if (route?.isFromCache ?? false)
                            const Icon(
                              Icons.offline_pin_rounded,
                              size: 20,
                              color: AppColors.primaryAccessible,
                            )
                          else
                            Transform.rotate(
                              angle: (route?.bearingDegrees ?? 0) * math.pi / 180,

                              child: const Icon(
                                Icons.navigation_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  isArrived
                                      ? "Você chegou ao ponto de coleta!"
                                      : ((route?.isFromCache ?? false)
                                          ? "Rota viária recuperada do cache local"
                                          : "Siga rumo ao ${route?.cardinalDirection ?? ""}."),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isArrived || (route?.isFromCache ?? false)
                                        ? AppColors.primaryAccessible
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),

                                Text(
                                  isArrived
                                      ? "Realize seu descarte consciente nos coletores disponíveis."
                                      : ((route?.isFromCache ?? false)
                                          ? "Navegação disponível sem internet com base no trajeto salvo."
                                          : "Modo offline: traçado direto por vetor e estimativa local."),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isArrived || (route?.isFromCache ?? false)
                                        ? AppColors.primaryAccessible
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  if (isLargeFont) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onClose,
                        style: FilledButton.styleFrom(
                          backgroundColor: isArrived
                              ? AppColors.primary
                              : AppColors.surfaceSection,
                          foregroundColor: isArrived
                              ? Colors.white
                              : AppColors.textPrimary,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(isArrived ? "Concluir" : "Encerrar rota"),
                      ),
                    ),
                    if (onOpenExternal != null) ...[
                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onOpenExternal,
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text("App externo"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.outline),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        if (onOpenExternal != null) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onOpenExternal,
                              icon: const Icon(Icons.open_in_new_rounded, size: 17),
                              label: const Text("App externo"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.outline),
                                minimumSize: const Size(0, 46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],

                        Expanded(
                          child: FilledButton(
                            onPressed: onClose,
                            style: FilledButton.styleFrom(
                              backgroundColor: isArrived
                                  ? AppColors.primary
                                  : AppColors.surfaceSection,
                              foregroundColor: isArrived
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              minimumSize: const Size(0, 46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(isArrived ? "Concluir" : "Encerrar rota"),
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


// Classes ------------------------------------------------------------------ //


class _RouteMetric extends StatelessWidget {
  const _RouteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),

        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
