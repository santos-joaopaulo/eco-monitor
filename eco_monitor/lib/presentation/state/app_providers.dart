import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:provider/single_child_widget.dart";

import "../../data/app_data_sync.dart";
import "../../data/favorites_repository.dart";
import "../../data/point_reviews_repository.dart";
import "../../data/waste_search_analytics_repository.dart";
import "../../domain/repositories/campaigns_repository_contract.dart";
import "../../domain/repositories/collect_points_repository_contract.dart";
import "../../domain/repositories/favorites_repository_contract.dart";
import "../../domain/repositories/point_reviews_repository_contract.dart";
import "../../domain/repositories/point_suggestions_repository_contract.dart";
import "../../domain/repositories/waste_search_analytics_repository_contract.dart";
import "../../domain/usecases/filter_points_use_case.dart";
import "../../domain/usecases/get_campaigns_use_case.dart";
import "../../domain/usecases/get_nearest_point_use_case.dart";
import "../../domain/usecases/submit_suggestion_use_case.dart";
import "../../services/campaign_reminder_service.dart";
import "../../services/location_service.dart";
import "../../services/offline_package_manager.dart";
import "../../services/residue_search_service.dart";
import "campaign_reminders_notifier.dart";
import "campaigns_notifier.dart";
import "favorites_notifier.dart";
import "location_notifier.dart";
import "offline_packages_notifier.dart";
import "points_notifier.dart";
import "sync_notifier.dart";


// Providers --------------------------------------------------------------- //


/// Constrói a lista de provedores de dependências e gerenciadores de estado
/// da aplicação (Provider / Clean Architecture).
List<SingleChildWidget> buildAppProviders({
  required AppDataSync dataSync,
  LocationService locationService = const LocationService(),
  IWasteSearchAnalyticsRepository? analyticsRepository,
  ResidueSearchService searchService = const ResidueSearchService(),
  IFavoritesRepository? favoritesRepository,
  IPointReviewsRepository? pointReviewsRepository,
  CampaignReminderService? reminderService,
  IOfflinePackageManager? offlinePackageManager,
}) {
  final IFavoritesRepository favRepo =
      favoritesRepository ?? FavoritesRepository();
  final IPointReviewsRepository revRepo = pointReviewsRepository ??
      (dataSync.reviewsRepository ?? PointReviewsRepository());
  final CampaignReminderService campaignReminderService =
      reminderService ?? CampaignReminderService();
  final IOfflinePackageManager packageManager =
      offlinePackageManager ?? OfflinePackageManager.instance;

  return <SingleChildWidget>[
    // Data & Repositórios (Contratos de Domínio)
    ChangeNotifierProvider<AppDataSync>.value(value: dataSync),
    Provider<ICollectPointsRepository>.value(
      value: dataSync.collectPointsRepository,
    ),
    Provider<ICampaignsRepository>.value(value: dataSync.campaignsRepository),
    Provider<IPointSuggestionsRepository>.value(
      value: dataSync.suggestionsRepository,
    ),
    Provider<IWasteSearchAnalyticsRepository>.value(
      value: analyticsRepository ?? WasteSearchAnalyticsRepository(),
    ),
    Provider<IFavoritesRepository>.value(value: favRepo),
    Provider<IPointReviewsRepository>.value(value: revRepo),
    Provider<CampaignReminderService>.value(value: campaignReminderService),
    Provider<LocationService>.value(value: locationService),
    Provider<ResidueSearchService>.value(value: searchService),
    Provider<IOfflinePackageManager>.value(value: packageManager),

    // Casos de Uso (Camada de Domínio)
    Provider<FilterPointsUseCase>(
      create: (_) => const FilterPointsUseCase(),
    ),
    Provider<GetNearestPointUseCase>(
      create: (_) => const GetNearestPointUseCase(),
    ),
    ProxyProvider<IPointSuggestionsRepository, SubmitSuggestionUseCase>(
      update: (_, IPointSuggestionsRepository repo, _) =>
          SubmitSuggestionUseCase(repo),
    ),
    ProxyProvider<ICampaignsRepository, GetCampaignsUseCase>(
      update: (_, ICampaignsRepository repo, _) =>
          GetCampaignsUseCase(repo),
    ),

    // Gerenciadores de Estado Reativo (Camada de Apresentação)
    ChangeNotifierProvider<FavoritesNotifier>(
      create: (_) => FavoritesNotifier(favRepo),
    ),
    ChangeNotifierProvider<CampaignRemindersNotifier>(
      create: (_) =>
          CampaignRemindersNotifier(campaignReminderService),
    ),
    ChangeNotifierProvider<PointsNotifier>(
      create: (BuildContext context) => PointsNotifier(
        repository: context.read<ICollectPointsRepository>(),
        dataSync: dataSync,
        filterUseCase: context.read<FilterPointsUseCase>(),
        nearestUseCase: context.read<GetNearestPointUseCase>(),
      ),
    ),
    ChangeNotifierProvider<LocationNotifier>(
      create: (BuildContext context) => LocationNotifier(
        locationService: context.read<LocationService>(),
      ),
    ),
    ChangeNotifierProvider<CampaignsNotifier>(
      create: (BuildContext context) => CampaignsNotifier(
        repository: context.read<ICampaignsRepository>(),
        dataSync: dataSync,
        useCase: context.read<GetCampaignsUseCase>(),
      ),
    ),
    ChangeNotifierProvider<OfflinePackagesNotifier>(
      create: (BuildContext context) {
        final OfflinePackagesNotifier notifier = OfflinePackagesNotifier(
          packageManager: context.read<IOfflinePackageManager>(),
        );
        unawaited(notifier.loadPackages());
        return notifier;
      },
    ),
    ChangeNotifierProvider<SyncNotifier>(
      create: (_) => SyncNotifier(dataSync),
    ),
  ];
}
