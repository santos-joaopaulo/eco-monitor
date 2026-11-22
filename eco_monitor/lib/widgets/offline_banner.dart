import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";


// Classes ----------------------------------------------------------------- //


/// Banner de status informando modo offline, dados em cache desatualizados
/// ou sugestões offline pendentes aguardando sincronização (RNF10, RNF17).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.isOffline,
    required this.isStale,
    this.lastUpdated,
    this.pendingSuggestionsCount = 0,
    this.isSyncing = false,
    this.onRetry,
  });

  final bool isOffline;
  final bool isStale;
  final DateTime? lastUpdated;
  final int pendingSuggestionsCount;
  final bool isSyncing;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final bool hasPending = pendingSuggestionsCount > 0;
    if (!isOffline && !isStale && !hasPending) {
      return const SizedBox.shrink();
    }

    final String message;
    final IconData icon;

    if (isOffline) {
      final String pendingSuffix = hasPending
          ? " (+$pendingSuggestionsCount)"
          : "";
      message = "Sem conexão · Dados salvos$pendingSuffix";
      icon = Icons.wifi_off_rounded;
    } else if (isStale) {
      final String dateSuffix = _formatDateSuffix(lastUpdated);
      message = "Dados desatualizados$dateSuffix";
      icon = Icons.update_rounded;
    } else {
      message = isSyncing
          ? "Sincronizando..."
          : "$pendingSuggestionsCount pendente${pendingSuggestionsCount > 1 ? "s" : ""} para envio";
      icon = Icons.cloud_upload_outlined;
    }

    return Semantics(
      liveRegion: true,
      label: message,

      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: kEcoContentHorizontalPadding,
              vertical: 6,
            ),

            child: Material(
              color: AppColors.offlineSurface,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,

              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.outline, width: 0.8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),

                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: AppColors.textSecondary, size: 15),
                    const SizedBox(width: 8),

                    Flexible(
                      child: Text(
                        message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    if (!isOffline && isSyncing) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,

                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ] else if (!isOffline && onRetry != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          minimumSize: const Size(48, 26),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),

                        child: const Text(
                          "Atualizar",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// Methods ----------------------------------------------------------------- //


String _formatDateSuffix(DateTime? date) {
  if (date == null || date.millisecondsSinceEpoch == 0) {
    return "";
  }

  final DateTime local = date.toLocal();
  final String day = local.day.toString().padLeft(2, "0");
  final String month = local.month.toString().padLeft(2, "0");
  return " ($day/$month)";
}
