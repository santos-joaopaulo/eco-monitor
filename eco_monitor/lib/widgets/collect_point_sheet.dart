import "package:flutter/material.dart";

import "../models/collection_point.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "waste_style.dart";


// Classes ----------------------------------------------------------------- //


/// Painel inferior com os detalhes do ponto de coleta selecionado (RF03).
class CollectPointSheet extends StatelessWidget {
  const CollectPointSheet({
    super.key,
    required this.point,
    required this.distanceMeters,
    required this.activeFilter,
    required this.isDataStale,
    required this.onCancel,
    required this.onStartRoute,
  });

  final CollectionPoint point;
  final double? distanceMeters;
  final Set<WasteType> activeFilter;
  final bool isDataStale;
  final VoidCallback onCancel;
  final VoidCallback onStartRoute;


  // Methods --------------------------------------------------------------- //


  @override
  Widget build(BuildContext context) {
    final List<WasteType> sortedWasteTypes = point.acceptedWasteTypes.toList()
      ..sort((WasteType first, WasteType second) {
        return first.index.compareTo(second.index);
      });

    final bool filterIncompatible =
        activeFilter.isNotEmpty && !point.acceptsAny(activeFilter);

    final double maxHeight = MediaQuery.sizeOf(context).height * 0.45;

    return SafeArea(
      top: false,

      child: Align(
        alignment: Alignment.bottomCenter,

        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: kEcoMaxContentWidth,
            maxHeight: maxHeight,
          ),

          child: Material(
            color: AppColors.surface,
            elevation: 12,
            shadowColor: Colors.black.withAlpha(60),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,

            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TypeIcon(type: point.type),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,

                              child: Text(
                                point.name,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _TypeBadge(type: point.type),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      Text(
                        distanceMeters == null
                            ? "Distância indisponível"
                            : formatDistance(distanceMeters!),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _InfoRow(icon: Icons.place_outlined, text: point.address),
                  const SizedBox(height: 10),

                  _StatusRow(point: point),
                  const SizedBox(height: 12),

                  if (filterIncompatible) ...[
                    _Notice(
                      message: _filterWarning(activeFilter),
                      background: AppColors.warningBackground,
                      foreground: AppColors.warningText,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (isDataStale) ...[
                    const _Notice(
                      message:
                          "Os dados deste ponto podem estar desatualizados.",
                      background: AppColors.warningBackground,
                      foreground: AppColors.warningText,
                    ),
                    const SizedBox(height: 12),
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
                        const _SectionLabel(label: "MATERIAIS ACEITOS"),
                        const SizedBox(height: 8),

                        if (sortedWasteTypes.isEmpty)
                          const Text(
                            "Nenhum material informado.",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final WasteType type in sortedWasteTypes)
                                _WasteChip(type: type),
                            ],
                          ),

                        const SizedBox(height: 16),
                        const _SectionLabel(label: "HORÁRIO"),
                        const SizedBox(height: 6),

                        Text(
                          point.hours.isEmpty
                              ? "Horário não informado."
                              : point.hours,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onCancel,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: EcoColors.primary,
                            side: const BorderSide(
                              color: AppColors.timelineLine,
                              width: 1.5,
                            ),
                            minimumSize: const Size(0, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text("Cancelar"),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: onStartRoute,
                          icon: const Icon(Icons.navigation_rounded, size: 20),
                          label: const Text("Iniciar rota"),
                          style: FilledButton.styleFrom(
                            backgroundColor: EcoColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 52),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// Classes ----------------------------------------------------------------- //


class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final PointType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.iconTint,
        borderRadius: BorderRadius.circular(16),
      ),

      child: Icon(type.icon, size: 26, color: type.color),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final PointType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: type.color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: EcoColors.primary),
        const SizedBox(width: 8),

        Expanded(
          child: Text(
            text.isEmpty ? "Endereço não informado." : text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.point});

  final CollectionPoint point;

  @override
  Widget build(BuildContext context) {
    final bool active = point.isActive;

    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: active ? AppColors.active : AppColors.inactive,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),

        Text(
          active ? "Ativo" : "Inativo",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.active : AppColors.textSecondary,
          ),
        ),

        if (!active) ...[
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Este ponto não está recebendo resíduos.",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
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

class _WasteChip extends StatelessWidget {
  const _WasteChip({required this.type});

  final WasteType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
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

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    required this.background,
    required this.foreground,
  });

  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),

      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}


// Extensions -------------------------------------------------------------- //


extension _PointTypeStyle on PointType {
  String get label => switch (this) {
    PointType.pharmacy => "Farmácia",
    PointType.healthCenter => "UBS",
    PointType.ecoPoint => "Ecoponto",
  };

  IconData get icon => switch (this) {
    PointType.pharmacy => Icons.local_pharmacy_rounded,
    PointType.healthCenter => Icons.local_hospital_rounded,
    PointType.ecoPoint => Icons.recycling_rounded,
  };

  Color get color => switch (this) {
    PointType.pharmacy => AppColors.medicine,
    PointType.healthCenter => AppColors.userLocation,
    PointType.ecoPoint => AppColors.battery,
  };
}


// Methods ----------------------------------------------------------------- //


String _filterWarning(Set<WasteType> activeFilter) {
  if (activeFilter.length == 1) {
    return "Este ponto não aceita ${activeFilter.first.label}.";
  }

  return "Este ponto não aceita os resíduos selecionados.";
}
