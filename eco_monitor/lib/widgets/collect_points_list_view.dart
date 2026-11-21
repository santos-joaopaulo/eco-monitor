import "package:flutter/material.dart";

import "../domain/entities/waste_type.dart";
import "../models/collection_point.dart";
import "../services/location_service.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "../utils/geo.dart";
import "custom_bottom_nav_bar.dart";
import "waste_style.dart";


// Classes ----------------------------------------------------------------- //


/// Visualização em lista de pontos de coleta (fallback offline e modo alternativo - RF01, RF05, RNF09).
class CollectPointsListView extends StatelessWidget {
  const CollectPointsListView({
    super.key,
    required this.points,
    required this.onPointSelected,
    this.userLocation,
    this.activeFilter = const <WasteType>{},
    this.isDataStale = false,
  });

  final List<CollectionPoint> points;
  final ValueChanged<CollectionPoint> onPointSelected;
  final UserLocation? userLocation;
  final Set<WasteType> activeFilter;
  final bool isDataStale;


  // Methods --------------------------------------------------------------- //


  List<CollectionPoint> _sortedPoints() {
    final UserLocation? location = userLocation;
    if (location == null) {
      return points;
    }

    final List<CollectionPoint> sorted = List<CollectionPoint>.of(points);
    sorted.sort((CollectionPoint a, CollectionPoint b) {
      final double distA = distanceInMeters(
        location.latitude,
        location.longitude,
        a.latitude,
        a.longitude,
      );
      final double distB = distanceInMeters(
        location.latitude,
        location.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    return sorted;
  }

  double? _distanceFor(CollectionPoint point) {
    final UserLocation? location = userLocation;
    if (location == null) {
      return null;
    }

    return distanceInMeters(
      location.latitude,
      location.longitude,
      point.latitude,
      point.longitude,
    );
  }


  // Build ----------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final List<CollectionPoint> sorted = _sortedPoints();
    final double bottomPadding =
        CustomBottomNavBar.reservedBottomInset(context) + 80;

    if (sorted.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off_outlined,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),

              Text(
                activeFilter.isEmpty
                    ? "Nenhum ponto de coleta cadastrado."
                    : "Nenhum ponto aceita os resíduos selecionados.",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              const Text(
                "Tente alterar os filtros acima para encontrar outros pontos.",
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            kEcoContentHorizontalPadding,
            8,
            kEcoContentHorizontalPadding,
            bottomPadding,
          ),
          itemCount: sorted.length,
          separatorBuilder: (BuildContext context, int index) {
            return const SizedBox(height: 12);
          },
          itemBuilder: (BuildContext context, int index) {
            final CollectionPoint point = sorted[index];
            final double? distance = _distanceFor(point);

            return _CollectPointCard(
              point: point,
              distanceMeters: distance,
              onTap: () => onPointSelected(point),
            );
          },
        ),
      ),
    );
  }
}


// Classes ----------------------------------------------------------------- //


class _CollectPointCard extends StatelessWidget {
  const _CollectPointCard({
    required this.point,
    required this.distanceMeters,
    required this.onTap,
  });

  final CollectionPoint point;
  final double? distanceMeters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final List<WasteType> wasteTypes = point.acceptedWasteTypes.toList()
      ..sort((WasteType a, WasteType b) => a.index.compareTo(b.index));

    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: Colors.black.withAlpha(25),
      borderRadius: BorderRadius.circular(16),

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.iconTint,
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Icon(
                      _pointIcon(point.type),
                      size: 22,
                      color: _pointColor(point.type),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),

                        Text(
                          _pointLabel(point.type),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _pointColor(point.type),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (distanceMeters != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Text(
                        formatDistance(distanceMeters!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: EcoColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),

                  Expanded(
                    child: Text(
                      point.address.isEmpty
                          ? "Endereço não informado."
                          : point.address,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: point.isActive
                          ? AppColors.active
                          : AppColors.inactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),

                  Text(
                    point.isActive ? "Ativo" : "Inativo",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: point.isActive
                          ? AppColors.active
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              if (wasteTypes.isNotEmpty) ...[
                const SizedBox(height: 12),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final WasteType type in wasteTypes)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(type.icon, size: 14, color: type.color),
                            const SizedBox(width: 4),

                            Text(
                              type.filterLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


// Methods ----------------------------------------------------------------- //


IconData _pointIcon(PointType type) {
  return switch (type) {
    PointType.pharmacy => Icons.local_pharmacy_rounded,
    PointType.healthCenter => Icons.local_hospital_rounded,
    PointType.ecoPoint => Icons.recycling_rounded,
  };
}

Color _pointColor(PointType type) {
  return switch (type) {
    PointType.pharmacy => AppColors.medicine,
    PointType.healthCenter => AppColors.userLocation,
    PointType.ecoPoint => AppColors.battery,
  };
}

String _pointLabel(PointType type) {
  return switch (type) {
    PointType.pharmacy => "Farmácia",
    PointType.healthCenter => "UBS",
    PointType.ecoPoint => "Ecoponto",
  };
}
