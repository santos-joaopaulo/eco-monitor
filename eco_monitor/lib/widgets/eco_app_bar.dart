import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:provider/provider.dart";

import "../data/app_data_sync.dart";
import "../presentation/state/location_notifier.dart";
import "../presentation/state/offline_packages_notifier.dart";
import "../screens/admin/admin_dashboard_screen.dart";
import "../screens/admin/admin_key_screen.dart";
import "../screens/offline_maps_screen.dart";
import "../services/admin_auth_service.dart";
import "../theme/app_colors.dart";
import "admin_secret_gesture_detector.dart";

// Classes ----------------------------------------------------------------- //

/// AppBar padrão do EcoMonitor: fundo verde-água, título branco centralizado.
///
/// Sem [onBack], exibe o logo (ícone de reciclagem branco) à esquerda com suporte
/// ao gesto secreto de administrador; com [onBack], exibe a seta de retorno.
/// Inclui atalho direto de 1 toque para o gerenciador de mapas offline (T14.4).
class EcoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EcoAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.onAdminTrigger,
    this.authService,
    this.dataSync,
    this.enableAdminTrigger = true,
    this.adminHoldDuration = const Duration(seconds: 3),
    this.actions,
    this.showOfflineMapsAction,
    this.onOfflineMapsPressed,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onAdminTrigger;
  final AdminAuthService? authService;
  final AppDataSync? dataSync;
  final bool enableAdminTrigger;
  final Duration adminHoldDuration;
  final List<Widget>? actions;
  final bool? showOfflineMapsAction;
  final VoidCallback? onOfflineMapsPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  // Methods --------------------------------------------------------------- //

  Future<void> _handleDefaultAdminTrigger(BuildContext context) async {
    final AdminAuthService service = authService ?? AdminAuthService();
    final bool authorized = await service.isAuthorized();

    if (!context.mounted) {
      return;
    }

    if (authorized) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AdminDashboardScreen(authService: service, dataSync: dataSync),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AdminKeyScreen(authService: service, dataSync: dataSync),
        ),
      );
    }
  }

  List<Widget>? _buildEffectiveActions(BuildContext context) {
    final bool shouldShowOffline = showOfflineMapsAction ?? (onBack == null);
    final Widget offlineButton = IconButton(
      icon: const Icon(Icons.download_for_offline_rounded),
      iconSize: 24,
      tooltip: "Mapas offline",
      onPressed: onOfflineMapsPressed ??
          () {
            OfflinePackagesNotifier? notifier;
            try {
              notifier = Provider.of<OfflinePackagesNotifier>(
                context,
                listen: false,
              );
            } catch (_) {}

            try {
              final LocationNotifier locationNotifier =
                  Provider.of<LocationNotifier>(context, listen: false);
              if (locationNotifier.userLocation != null && notifier != null) {
                notifier.updateUserLocation(locationNotifier.userLocation);
              }
            } catch (_) {}

            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext routeContext) =>
                    OfflineMapsScreen(notifier: notifier),
              ),
            );
          },
    );

    if (actions == null) {
      return shouldShowOffline ? <Widget>[offlineButton] : null;
    }

    if (showOfflineMapsAction == true) {
      return <Widget>[offlineButton, ...actions!];
    }

    if (shouldShowOffline) {
      final bool alreadyPresent = actions!.any(
        (Widget w) =>
            w is IconButton &&
            w.icon is Icon &&
            (w.icon as Icon).icon == Icons.download_for_offline_rounded,
      );
      if (!alreadyPresent) {
        return <Widget>[offlineButton, ...actions!];
      }
    }

    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,

      leading: onBack == null
          ? (enableAdminTrigger
                ? AdminSecretGestureDetector(
                    holdDuration: adminHoldDuration,
                    onTrigger: () {
                      if (onAdminTrigger != null) {
                        onAdminTrigger!();
                      } else {
                        _handleDefaultAdminTrigger(context);
                      }
                    },
                    child: const _Logo(),
                  )
                : const _Logo())
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 28,
              tooltip: "Voltar",
              onPressed: onBack,
            ),

      title: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.35,
        child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),

      actions: _buildEffectiveActions(context),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 24),
      child: SizedBox(
        width: 24,
        height: 24,
        child: Image(
          image: AssetImage("assets/logo.png"),
          semanticLabel: "EcoMonitor",
        ),
      ),
    );
  }
}
