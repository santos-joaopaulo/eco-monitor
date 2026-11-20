import "package:flutter/material.dart";

import "package:eco_monitor/theme/eco_theme.dart";


// Classes ----------------------------------------------------------------- //


/// Aviso compacto sobre a permissão ou serviço de localização.
///
/// Nunca bloqueia o mapa: quando o usuário descarta ou ignora o aviso, a tela
/// continua funcionando com os pontos de coleta locais.
class LocationNotice extends StatelessWidget {
  const LocationNotice({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: EcoColors.surface,
        elevation: 3,
        shadowColor: Colors.black.withAlpha(40),
        borderRadius: BorderRadius.circular(16),

        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),

          child: Row(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.location_off_outlined,
                  size: 20,
                  color: EcoColors.textSecondary,
                ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: EcoColors.textPrimary,
                  ),
                ),
              ),

              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: EcoColors.primary,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
