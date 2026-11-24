import "dart:async";

import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

import "../data/app_data_sync.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/point_reviews_repository_contract.dart";
import "../domain/entities/collection_point.dart";
import "../domain/entities/point_review.dart";
import "../presentation/state/favorites_notifier.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../utils/formatters.dart";
import "waste_style.dart";


// Classes ------------------------------------------------------------------ //


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


// Methods ------------------------------------------------------------------ //


  @override
  Widget build(BuildContext context) {
    final List<WasteType> sortedWasteTypes = point.acceptedWasteTypes.toList()
      ..sort((WasteType first, WasteType second) {
        return first.index.compareTo(second.index);
      });

    final bool filterIncompatible =
        activeFilter.isNotEmpty && !point.acceptsAny(activeFilter);

    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double maxSheetHeight = screenHeight * (2.0 / 3.0);
    final bool isLargeFont = MediaQuery.textScalerOf(context).scale(1) > 1.25;

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
                        onCancel();
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

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,

                        children: [
                          _FavoriteHeartButton(pointId: point.id),
                          const SizedBox(height: 4),
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
                    ],
                  ),
                  const SizedBox(height: 14),

                  _InfoRow(icon: Icons.place_outlined, text: point.address),
                  const SizedBox(height: 10),

                  _StatusRow(point: point),
                  const SizedBox(height: 10),

                  _PointReviewStatsDisplay(pointId: point.id),
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
                  const SizedBox(height: 16),

                  if (isLargeFont) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onStartRoute,
                        icon: const Icon(Icons.navigation_rounded, size: 20),
                        label: const Text("Iniciar rota"),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
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
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.timelineLine,
                            width: 1.5,
                          ),
                          minimumSize: const Size.fromHeight(52),
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
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
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
                              backgroundColor: AppColors.primary,
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
                  const SizedBox(height: 16),

                  _PointReviewSection(pointId: point.id),
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
        Icon(icon, size: 18, color: AppColors.primary),
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

      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 18, color: type.color),
            const SizedBox(width: 6),

            Flexible(
              child: Text(
                type.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
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


// Extensions --------------------------------------------------------------- //


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


// Methods ------------------------------------------------------------------ //


String _filterWarning(Set<WasteType> activeFilter) {
  if (activeFilter.length == 1) {
    return "Este ponto não aceita ${activeFilter.first.label}.";
  }

  return "Este ponto não aceita os resíduos selecionados.";
}


// Favorites and Reviews ---------------------------------------------------- //


class _FavoriteHeartButton extends StatefulWidget {
  const _FavoriteHeartButton({required this.pointId});

  final String pointId;

  @override
  State<_FavoriteHeartButton> createState() => _FavoriteHeartButtonState();
}

class _FavoriteHeartButtonState extends State<_FavoriteHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FavoritesNotifier? notifier;
    try {
      notifier = Provider.of<FavoritesNotifier>(context);
    } catch (_) {
      notifier = null;
    }

    final bool isFav = notifier?.isFavorite(widget.pointId) ?? false;

    return Semantics(
      button: true,
      label: isFav ? "Remover dos favoritos" : "Adicionar aos favoritos",
      child: Tooltip(
        message: isFav ? "Remover dos favoritos" : "Adicionar aos favoritos",
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: IconButton(
            iconSize: 26,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? AppColors.favorite : AppColors.textSecondary,
            ),
            onPressed: () async {
              unawaited(HapticFeedback.lightImpact());
              _animController.forward(from: 0.0);
              if (notifier != null) {
                await notifier.toggleFavorite(widget.pointId);
              }
            },
          ),
        ),
      ),
    );
  }
}

class _PointReviewStatsDisplay extends StatefulWidget {
  const _PointReviewStatsDisplay({required this.pointId});

  final String pointId;

  @override
  State<_PointReviewStatsDisplay> createState() =>
      _PointReviewStatsDisplayState();
}

class _PointReviewStatsDisplayState extends State<_PointReviewStatsDisplay> {
  PointReviewStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      Provider.of<AppDataSync>(context);
    } catch (_) {}
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant _PointReviewStatsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pointId != widget.pointId) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    IPointReviewsRepository? repo;
    try {
      repo = Provider.of<IPointReviewsRepository>(context, listen: false);
    } catch (_) {
      repo = null;
    }

    if (repo != null) {
      final PointReviewStats stats = await repo.getStatsForPoint(widget.pointId);
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PointReviewStats? stats = _stats;
    if (stats == null || !stats.hasReviews) {
      return Row(
        children: const [
          Icon(
            Icons.star_outline_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              "Sem avaliações ainda",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,

          children: [
            const Icon(
              Icons.star_rounded,
              size: 18,
              color: AppColors.ratingStar,
            ),
            Text(
              "${stats.averageRating.toStringAsFixed(1)} ",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              "(${stats.totalReviews} ${stats.totalReviews == 1 ? "avaliação" : "avaliações"})",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (stats.topTags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,

            children: [
              for (final String tag in stats.topTags.take(3))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryAccessible,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PointReviewSection extends StatefulWidget {
  const _PointReviewSection({required this.pointId});

  final String pointId;

  @override
  State<_PointReviewSection> createState() => _PointReviewSectionState();
}

class _PointReviewSectionState extends State<_PointReviewSection> {
  int _selectedRating = 5;
  final Set<String> _selectedTags = <String>{};
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) {
      return;
    }

    final ScaffoldMessengerState? messenger =
        ScaffoldMessenger.maybeOf(context);

    setState(() {
      _isSubmitting = true;
    });

    final PointReview review = PointReview(
      id: "rev_${DateTime.now().millisecondsSinceEpoch}",
      pointId: widget.pointId,
      rating: _selectedRating,
      tags: _selectedTags.toList(),
      createdAt: DateTime.now(),
    );

    PointReviewSubmitResult? result;

    try {
      AppDataSync? sync;
      try {
        sync = Provider.of<AppDataSync>(context, listen: false);
      } catch (_) {
        sync = null;
      }

      if (sync != null) {
        result = await sync.submitReview(review);
      } else {
        IPointReviewsRepository? repo;
        try {
          repo = Provider.of<IPointReviewsRepository>(context, listen: false);
        } catch (_) {
          repo = null;
        }
        if (repo != null) {
          result = await repo.submitReview(review);
        }
      }
    } catch (_) {
      result = PointReviewSubmitResult.queuedOffline;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
      _isSubmitted = true;
    });

    final String message = result == PointReviewSubmitResult.sent
        ? "Avaliação enviada com sucesso! Obrigado pela colaboração."
        : "Avaliação salva offline. Será sincronizada assim que você reconectar.";

    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primaryAccessible,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const _SectionLabel(label: "AVALIAÇÃO DO ECOPONTO"),
          const SizedBox(height: 8),

          if (_isSubmitted) ...[
            Row(
              children: const [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.primaryAccessible,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Obrigado! Sua avaliação foi registrada.",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryAccessible,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                for (int star = 1; star <= 5; star++)
                  Semantics(
                    button: true,
                    label: "$star ${star == 1 ? "estrela" : "estrelas"}",
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedRating = star;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Icon(
                          star <= _selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 32,
                          color: star <= _selectedRating
                              ? AppColors.ratingStar
                              : AppColors.ratingStarEmpty,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,

              children: [
                for (final String tag in PointReviewTags.all)
                  _ReviewTagChip(
                    label: tag,
                    isSelected: _selectedTags.contains(tag),
                    onTap: () => _toggleTag(tag),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitReview,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmitting ? "Enviando..." : "Enviar avaliação",
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
    );
  }
}

class _ReviewTagChip extends StatelessWidget {
  const _ReviewTagChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Material(
        color: isSelected ? AppColors.primaryTint : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.outline,
                width: 1.2,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? AppColors.primaryAccessible
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
