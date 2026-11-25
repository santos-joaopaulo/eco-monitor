import "package:material_ui/material_ui.dart";

import "../theme/eco_theme.dart";
import "location_notice.dart";


// Classes ------------------------------------------------------------------ //


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
    this.padding,
  });

  final bool isOffline;
  final bool isStale;
  final DateTime? lastUpdated;
  final int pendingSuggestionsCount;
  final bool isSyncing;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bool hasPending = pendingSuggestionsCount > 0;
    if (!isOffline && !isStale && !hasPending) {
      return const SizedBox.shrink();
    }

    final String message;
    final IconData icon;
    final String? actionLabel;
    final VoidCallback? onAction;

    if (isOffline) {
      final String pendingSuffix = hasPending
          ? " (+$pendingSuggestionsCount)"
          : "";
      message = "Sem conexão · Dados salvos$pendingSuffix";
      icon = Icons.wifi_off_rounded;
      actionLabel = null;
      onAction = null;
    } else if (isStale) {
      final String dateSuffix = _formatDateSuffix(lastUpdated);
      message = "Dados desatualizados$dateSuffix";
      icon = Icons.update_rounded;
      actionLabel = onRetry != null ? "Atualizar" : null;
      onAction = onRetry;
    } else {
      message = isSyncing
          ? "Sincronizando..."
          : "$pendingSuggestionsCount pendente${pendingSuggestionsCount > 1 ? "s" : ""} para envio";
      icon = Icons.cloud_upload_outlined;
      actionLabel = null;
      onAction = null;
    }

    final Widget notice = LocationNotice(
      icon: icon,
      message: message,
      isLoading: !isOffline && isSyncing,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: kEcoContentHorizontalPadding,
                vertical: 6,
              ),

          child: notice,
        ),
      ),
    );
  }
}


// Methods ------------------------------------------------------------------ //


String _formatDateSuffix(DateTime? date) {
  if (date == null || date.millisecondsSinceEpoch == 0) {
    return "";
  }

  final DateTime local = date.toLocal();
  final String day = local.day.toString().padLeft(2, "0");
  final String month = local.month.toString().padLeft(2, "0");
  return " ($day/$month)";
}
