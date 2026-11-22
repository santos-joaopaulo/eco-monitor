import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";




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
          ? " · ${_pendingLabel(pendingSuggestionsCount)}"
          : "";
      message = "Sem conexão — exibindo dados salvos$pendingSuffix";
      icon = Icons.wifi_off_rounded;
    } else if (isStale) {
      final String dateSuffix = _formatDateSuffix(lastUpdated);
      message = "Dados podem estar desatualizados$dateSuffix";
      icon = Icons.update_rounded;
    } else {
      message = isSyncing
          ? "Sincronizando ${_pendingLabel(pendingSuggestionsCount)}..."
          : "${_pendingLabel(pendingSuggestionsCount)} aguardando envio";
      icon = Icons.cloud_upload_outlined;
    }

    return Semantics(
      liveRegion: true,
      label: message,
      child: Material(
        color: AppColors.offlineSurface,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.outline, width: 0.8)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 15),
              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              if (!isOffline && isSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else if (!isOffline && onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(48, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
          ),
        ),
      ),
    );
  }
}


// Methods ----------------------------------------------------------------- //


String _pendingLabel(int count) {
  return count == 1 ? "1 sugestão na fila" : "$count sugestões na fila";
}

String _formatDateSuffix(DateTime? date) {
  if (date == null || date.millisecondsSinceEpoch == 0) {
    return "";
  }

  final DateTime local = date.toLocal();
  final String day = local.day.toString().padLeft(2, "0");
  final String month = local.month.toString().padLeft(2, "0");
  return " (última atualização em $day/$month/${local.year})";
}
