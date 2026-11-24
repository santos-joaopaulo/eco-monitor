import "package:material_ui/material_ui.dart";

import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";


// Classes ------------------------------------------------------------------ //


/// Card de resumo do armazenamento local utilizado por mapas e pacotes de navegação offline.
class OfflineStorageSummaryCard extends StatelessWidget {
  const OfflineStorageSummaryCard({
    super.key,
    required this.totalBytes,
    required this.hasExtraPackages,
    this.onClearExtras,
  });

  /// Total de bytes ocupados pelos pacotes instalados.
  final int totalBytes;

  /// Indica se existem pacotes instalados adicionais além do padrão de Sergipe.
  final bool hasExtraPackages;

  /// Callback disparado quando o usuário confirma a remoção dos pacotes extras.
  final VoidCallback? onClearExtras;

  String _formatBytes(int bytes) {
    final double mb = bytes / (1024 * 1024);
    if (mb < 0.1) {
      return "${(bytes / 1024).toStringAsFixed(0)} KB";
    }
    return "${mb.toStringAsFixed(1).replaceAll('.', ',')} MB";
  }

  Future<void> _handleClearConfirmation(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Limpar mapas extras?",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: const Text(
            "Isso removerá todos os pacotes de outros estados baixados no seu aparelho. O mapa base de Sergipe continuará disponível permanentemente.",
            style: TextStyle(
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
                "Limpar",
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

    if (confirmed == true && onClearExtras != null) {
      onClearExtras!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowSubtle,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sd_storage_rounded,
                  color: AppColors.primaryAccessible,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: <Widget>[
                    const Text(
                      "Armazenamento de Mapas",
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Espaço offline utilizado: ${_formatBytes(totalBytes)}",
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasExtraPackages)
                TextButton.icon(
                  onPressed: () => _handleClearConfirmation(context),
                  icon: const Icon(
                    Icons.delete_sweep_rounded,
                    size: 18,
                    color: AppColors.warningText,
                  ),
                  label: const Text(
                    "Limpar extras",
                    style: TextStyle(
                      color: AppColors.warningText,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.warningBackground,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
