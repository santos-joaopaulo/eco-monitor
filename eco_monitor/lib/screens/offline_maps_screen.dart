import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

import "../domain/entities/offline_package.dart";
import "../presentation/state/location_notifier.dart";
import "../presentation/state/offline_packages_notifier.dart";
import "../services/offline_package_manager.dart";
import "../theme/app_colors.dart";
import "../theme/eco_theme.dart";
import "../widgets/eco_app_bar.dart";
import "../widgets/offline_package_card.dart";
import "../widgets/offline_storage_summary_card.dart";


// Classes ------------------------------------------------------------------ //


/// Tela de gerenciamento e download de pacotes de mapas offline por estado (T14.3).
class OfflineMapsScreen extends StatelessWidget {
  const OfflineMapsScreen({
    super.key,
    this.notifier,
    this.packageManager,
  });

  /// Notifier reativo opcional; se omitido, reutiliza o provider do contexto
  /// ou instancia um gerenciador autônomo conectado ao catálogo nacional.
  final OfflinePackagesNotifier? notifier;

  /// Gerenciador de pacotes opcional para inicialização autônoma.
  final IOfflinePackageManager? packageManager;

  @override
  Widget build(BuildContext context) {
    OfflinePackagesNotifier? resolvedNotifier = notifier;
    if (resolvedNotifier == null) {
      try {
        resolvedNotifier = Provider.of<OfflinePackagesNotifier>(
          context,
          listen: false,
        );
      } catch (_) {
        resolvedNotifier = null;
      }
    }

    if (resolvedNotifier != null) {
      return ChangeNotifierProvider<OfflinePackagesNotifier>.value(
        value: resolvedNotifier,
        child: const _OfflineMapsContent(),
      );
    }

    return ChangeNotifierProvider<OfflinePackagesNotifier>(
      create: (BuildContext ctx) {
        IOfflinePackageManager? manager = packageManager;
        if (manager == null) {
          try {
            manager = Provider.of<IOfflinePackageManager>(ctx, listen: false);
          } catch (_) {
            manager = OfflinePackageManager.instance;
          }
        }
        final OfflinePackagesNotifier created = OfflinePackagesNotifier(
          packageManager: manager,
        );
        unawaited(created.loadPackages());
        return created;
      },
      child: const _OfflineMapsContent(),
    );
  }
}

class _OfflineMapsContent extends StatefulWidget {
  const _OfflineMapsContent();

  @override
  State<_OfflineMapsContent> createState() => _OfflineMapsContentState();
}

class _OfflineMapsContentState extends State<_OfflineMapsContent> {
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _kRegions = <String>[
    "Todos",
    "Nordeste",
    "Sudeste",
    "Sul",
    "Centro-Oeste",
    "Norte",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncUserLocation();
      _ensurePackagesLoaded();
    });
  }

  void _syncUserLocation() {
    if (!mounted) {
      return;
    }
    try {
      final LocationNotifier locationNotifier =
          Provider.of<LocationNotifier>(context, listen: false);
      final OfflinePackagesNotifier packageNotifier =
          Provider.of<OfflinePackagesNotifier>(context, listen: false);
      if (locationNotifier.userLocation != null) {
        packageNotifier.updateUserLocation(locationNotifier.userLocation);
      }
    } catch (_) {}
  }

  void _ensurePackagesLoaded() {
    if (!mounted) {
      return;
    }
    try {
      final OfflinePackagesNotifier packageNotifier =
          Provider.of<OfflinePackagesNotifier>(context, listen: false);
      if (packageNotifier.packages.isEmpty && !packageNotifier.isLoading) {
        unawaited(packageNotifier.loadPackages());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: EcoAppBar(
        title: "Mapas Offline",
        onBack: () => Navigator.of(context).pop(),
      ),

      body: Consumer<OfflinePackagesNotifier>(
        builder: (
          BuildContext context,
          OfflinePackagesNotifier notifier,
          _,
        ) {
          if (notifier.isLoading && notifier.packages.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final List<OfflinePackage> filtered = notifier.filteredPackages;
          final OfflinePackage? suggested = notifier.suggestedPackage;
          final String currentRegion = notifier.selectedRegion ?? "Todos";

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: notifier.loadPackages,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kEcoMaxContentWidth),

                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kEcoContentHorizontalPadding,
                    vertical: 16,
                  ),
                  children: <Widget>[
                    // Card Superior de Armazenamento
                    OfflineStorageSummaryCard(
                      totalBytes: notifier.totalStorageBytes,
                      hasExtraPackages: notifier.hasExtraPackages,
                      onClearExtras: notifier.clearExtraPackages,
                    ),
                    const SizedBox(height: 16),

                    // Barra de Busca
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: notifier.setSearchQuery,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: "Buscar estado ou sigla...",
                          hintStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    notifier.setSearchQuery("");
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filtros por Região
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _kRegions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (BuildContext context, int index) {
                          final String region = _kRegions[index];
                          final bool isSelected = currentRegion == region;
                          return ChoiceChip(
                            label: Text(region),
                            selected: isSelected,
                            onSelected: (_) => notifier.setSelectedRegion(region),
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.outline,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Seção Sugerido para você
                    if (suggested != null &&
                        notifier.searchQuery.isEmpty &&
                        (notifier.selectedRegion == null ||
                            notifier.selectedRegion == suggested.region)) ...<Widget>[
                      const Text(
                        "Sugerido para você",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OfflinePackageCard(
                        package: suggested,
                        isSuggested: true,
                        onDownload: () =>
                            notifier.downloadPackage(suggested.id),
                        onDelete: () => notifier.deletePackage(suggested.id),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Lista de Estados
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: <Widget>[
                        const Text(
                          "Estados Brasileiros",
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${filtered.length} disponíveis",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (filtered.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        alignment: Alignment.center,

                        child: Column(
                          children: const <Widget>[
                            Icon(
                              Icons.map_outlined,
                              size: 44,
                              color: AppColors.inactive,
                            ),
                            SizedBox(height: 10),
                            Text(
                              "Nenhum estado encontrado.",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...filtered.map(
                        (OfflinePackage pkg) => OfflinePackageCard(
                          key: ValueKey<String>(pkg.id),
                          package: pkg,
                          isSuggested: false,
                          onDownload: () => notifier.downloadPackage(pkg.id),
                          onDelete: () => notifier.deletePackage(pkg.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
