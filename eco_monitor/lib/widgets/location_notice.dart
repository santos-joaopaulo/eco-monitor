import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";



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
    this.icon = Icons.location_off_outlined,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final bool isLargeFont =
        MediaQuery.textScalerOf(context).scale(1) > 1.25 && actionLabel != null;

    if (isLargeFont) {
      return Semantics(
        container: true,
        liveRegion: true,
        child: Material(
          color: AppColors.surface,
          elevation: 3,
          shadowColor: Colors.black.withAlpha(40),
          borderRadius: BorderRadius.circular(16),

          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        icon,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 6),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(48, 44),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: AppColors.surface,
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
                Icon(
                  icon,
                  size: 20,
                  color: AppColors.textSecondary,
                ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
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
