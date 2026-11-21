import "package:material_ui/material_ui.dart";

import "../models/collection_point.dart";
import "../services/route_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";


// Classes ----------------------------------------------------------------- //


/// Painel compacto da rota exibido após iniciar a navegação (RF04).
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({
    super.key,
    required this.point,
    required this.summary,
    required this.onClose,
  });

  final CollectionPoint point;
  final RouteSummary? summary;
  final VoidCallback onClose;


  // Methods --------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final RouteSummary? route = summary;

    return SafeArea(
      top: false,

      child: Align(
        alignment: Alignment.bottomCenter,

        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

          child: Material(
            color: AppColors.surface,
            elevation: 12,
            shadowColor: Colors.black.withAlpha(60),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,

            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: _RouteMetric(
                          label: "DISTÂNCIA",
                          value: route == null
                              ? "Indisponível"
                              : formatDistance(route.distanceMeters),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RouteMetric(
                          label: "TEMPO",
                          value: route == null
                              ? "Indisponível"
                              : formatDuration(
                                  route.estimatedMinutes.toDouble(),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: route == null
                          ? AppColors.surfaceSection
                          : AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          route == null
                              ? Icons.location_off_outlined
                              : Icons.info_outline,
                          size: 18,
                          color: route == null
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            route == null
                                ? "Sem a sua localização, distância e tempo não podem ser estimados."
                                : "Linha reta aproximada. Abra no aplicativo de mapas para a rota de trânsito real.",
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: route == null
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              color: route == null
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
