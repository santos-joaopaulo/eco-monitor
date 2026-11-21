import "package:flutter/material.dart";

import "../theme/app_colors.dart";




// Constants ---------------------------------------------------------------- //


/// Cores de superfície de alto contraste compatíveis com WCAG AA com texto branco (RNF04).
const Color _offlineSurface = Color(0xFFB45309);
const Color _staleSurface = Color(0xFF92400E);


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
    final Color backgroundColor;
    final IconData icon;

    if (isOffline) {
      final String pendingSuffix = hasPending
          ? " · ${_pendingLabel(pendingSuggestionsCount)}"
          : "";
      message = "Sem conexão — exibindo dados salvos$pendingSuffix";
      backgroundColor = _offlineSurface;
      icon = Icons.wifi_off;
    } else if (isStale) {
      final String dateSuffix = _formatDateSuffix(lastUpdated);
      message = "Dados podem estar desatualizados$dateSuffix";
      backgroundColor = _staleSurface;
      icon = Icons.update;
    } else {
      message = isSyncing
          ? "Sincronizando ${_pendingLabel(pendingSuggestionsCount)}..."
          : "${_pendingLabel(pendingSuggestionsCount)} aguardando envio";
      backgroundColor = AppColors.primary;
      icon = Icons.cloud_upload_outlined;
    }

    return Semantics(
      liveRegion: true,
      label: message,
      child: Material(
        color: backgroundColor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                if (!isOffline && isSyncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else if (!isOffline && onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      "Atualizar",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
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
