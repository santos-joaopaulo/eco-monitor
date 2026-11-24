import "package:material_ui/material_ui.dart";

import "../models/offline_package.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";


// Classes ----------------------------------------------------------------- //


/// Card individual de um pacote estadual de mapa offline (T14.3).
class OfflinePackageCard extends StatelessWidget {
  const OfflinePackageCard({
    super.key,
    required this.package,
    this.onDownload,
    this.onDelete,
    this.isSuggested = false,
  });

  final OfflinePackage package;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final bool isSuggested;

  Future<void> _handleDeleteConfirmation(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Excluir mapa de ${package.name}?",
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            "O arquivo do pacote será removido do dispositivo. Você poderá baixá-lo novamente a qualquer momento.",
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                "Cancelar",
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                "Excluir",
                style: TextStyle(
                  color: AppColors.warningText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && onDelete != null) {
      onDelete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSuggested ? AppColors.primary : AppColors.outline,
          width: isSuggested ? 1.6 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isSuggested)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: const <Widget>[
                  Icon(
                    Icons.my_location_rounded,
                    size: 14,
                    color: AppColors.primaryAccessible,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Sugerido para a sua localização",
                    style: TextStyle(
                      color: AppColors.primaryAccessible,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: <Widget>[
              // Sigla do Estado
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSuggested
                      ? AppColors.primary
                      : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  package.stateCode,
                  style: TextStyle(
                    color: isSuggested
                        ? Colors.white
                        : AppColors.primaryAccessible,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Informações do Estado
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      package.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${package.region} · ${package.formattedSize}",
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Ações de Download / Exclusão / Progresso
              _buildActionWidget(context),
            ],
          ),
          if (package.isDownloading) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: package.downloadProgress > 0 ? package.downloadProgress : null,
                color: AppColors.primary,
                backgroundColor: AppColors.primaryTint,
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionWidget(BuildContext context) {
    if (package.isDownloading) {
      final int percent = (package.downloadProgress * 100).toInt();
      return SizedBox(
        width: 70,
        child: Text(
          "$percent%",
          textAlign: TextAlign.end,
          style: const TextStyle(
            color: AppColors.primaryAccessible,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      );
    }

    if (package.isBuiltIn) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: AppColors.primaryAccessible,
            ),
            SizedBox(width: 4),
            Text(
              "Padrão",
              style: TextStyle(
                color: AppColors.primaryAccessible,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (package.isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: AppColors.primaryAccessible,
                ),
                SizedBox(width: 4),
                Text(
                  "Instalado",
                  style: TextStyle(
                    color: AppColors.primaryAccessible,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            tooltip: "Excluir pacote",
            onPressed: () => _handleDeleteConfirmation(context),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: onDownload,
      icon: const Icon(Icons.download_rounded, size: 16),
      label: const Text("Baixar"),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryAccessible,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
