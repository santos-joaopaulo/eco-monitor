import "package:flutter/material.dart";

import "../theme/eco_theme.dart";
import "eco_card.dart";


/// Card of one residue in the guide list: icon, title, description, action
/// button and side indicator (time/steps or progress).
///
/// With [onPressed] null the button appears disabled.
class ResidueCard extends StatelessWidget {
  const ResidueCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.info,
    this.infoWithClock = false,
    this.onPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String buttonLabel;
  final String info;
  final bool infoWithClock;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: EcoColors.iconTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: iconColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: EcoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: EcoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Wrap: button on the left and indicator on the right; if there is
          // not enough space (narrow screen / large font) the indicator drops
          // to the next line.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionButton(label: buttonLabel, onPressed: onPressed),
                _Indicator(text: info, withClock: infoWithClock),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: EcoColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: EcoColors.iconTint,
        disabledForegroundColor: EcoColors.textSecondary,

        // Comfortable touch target.
        minimumSize: const Size(120, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }
}


class _Indicator extends StatelessWidget {
  const _Indicator({required this.text, required this.withClock});

  final String text;
  final bool withClock;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (withClock) ...[
          const Icon(
            Icons.schedule_outlined,
            size: 18,
            color: EcoColors.textSecondary,
          ),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: EcoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
