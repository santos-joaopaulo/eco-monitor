import "dart:async";

import "package:flutter/foundation.dart";

import "../models/campaign.dart";
import "../models/collection_point.dart";
import "../models/point_suggestion.dart";
import "campaigns_repository.dart";
import "collect_points_fetcher_firestore.dart";
import "collect_points_repository.dart";
import "connectivity_service.dart";
import "disposal_guide_repository_synced.dart";
import "firebase_service.dart";
import "point_suggestions_repository.dart";

// Classes ----------------------------------------------------------------- //

/// Coordinates online Firebase synchronization with local offline storage across
/// all EcoMonitor repositories (RF05, RNF09, RNF10, RNF11, RNF17).
class AppDataSync extends ChangeNotifier {
  AppDataSync({
    required this.collectPointsRepository,
    required this.campaignsRepository,
    required this.suggestionsRepository,
    required this.guideRepository,
    required this.connectivityService,
  });

  /// Builds the production [AppDataSync] wired to Cloud Firestore when
  /// Firebase has been initialized, or offline-only otherwise.
  factory AppDataSync.createDefault({bool? firebaseEnabled}) {
    final bool useRemote = firebaseEnabled ?? isFirebaseReady;

    return AppDataSync(
      collectPointsRepository: CollectPointsRepository(
        fetcher: useRemote ? createFirestoreFetcher() : null,
      ),
      campaignsRepository: CampaignsRepository(
        fetcher: useRemote ? createFirestoreCampaignsFetcher() : null,
      ),
      suggestionsRepository: PointSuggestionsRepository(
        sender: useRemote ? createFirestoreSuggestionSender() : null,
      ),
      guideRepository: DisposalGuideRepositorySynced(
        fetcher: useRemote ? createFirestoreGuidesFetcher() : null,
      ),
      connectivityService: ConnectivityService(),
    );
  }

  final CollectPointsRepository collectPointsRepository;
  final CampaignsRepository campaignsRepository;
  final PointSuggestionsRepository suggestionsRepository;
  final DisposalGuideRepositorySynced guideRepository;
  final ConnectivityService connectivityService;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _initialized = false;
  bool _disposed = false;

  List<CollectionPoint> _points = const <CollectionPoint>[];
  List<Campaign> _campaigns = const <Campaign>[];
  bool _isOnline = true;
  bool _isSyncing = false;
  bool _isStale = false;
  int _pendingSuggestionsCount = 0;

  List<CollectionPoint> get points => _points;
  List<Campaign> get campaigns => _campaigns;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  bool get isStale => _isStale;
  int get pendingSuggestionsCount => _pendingSuggestionsCount;
  DateTime? get lastUpdated => collectPointsRepository.lastUpdated;
  DataSourceOrigin? get sourceOrigin => collectPointsRepository.sourceOrigin;

  // Methods --------------------------------------------------------------- //

  /// Loads offline datasets immediately, subscribes to connectivity changes,
  /// and refreshes from Firebase when online.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;

    _connectivitySubscription = connectivityService.isOnline.listen(
      _onConnectivityChanged,
    );

    await _loadOfflineDatasets();
    _isOnline = await connectivityService.checkNow();
    _notifySafely();

    if (_isOnline) {
      await refreshAll();
    }
  }

  /// Refreshes collection points, campaigns, and disposal guides from the
  /// remote backend and flushes any queued offline suggestions.
  Future<void> refreshAll() async {
    if (_disposed || _isSyncing) {
      return;
    }

    _isSyncing = true;
    _notifySafely();

    try {
      _isOnline = await connectivityService.checkNow();

      if (_isOnline) {
        final List<CollectionPoint> fetchedPoints =
            await collectPointsRepository.refresh();
        final List<Campaign> fetchedCampaigns = await campaignsRepository
            .refresh();
        await guideRepository.refresh();
        await suggestionsRepository.flushPending();

        _points = List<CollectionPoint>.unmodifiable(fetchedPoints);
        _campaigns = List<Campaign>.unmodifiable(fetchedCampaigns);
      } else {
        await _loadOfflineDatasets();
      }

      _pendingSuggestionsCount = await suggestionsRepository.pendingCount();
      _isStale = collectPointsRepository.isStale;
    } finally {
      _isSyncing = false;
      _notifySafely();
    }
  }

  /// Submits an anonymous point suggestion, automatically queueing it offline
  /// if the device is disconnected or the remote call fails.
  Future<SuggestionSubmitResult> submitSuggestion(
    PointSuggestion suggestion,
  ) async {
    final SuggestionSubmitResult result = await suggestionsRepository.submit(
      suggestion,
    );
    _pendingSuggestionsCount = await suggestionsRepository.pendingCount();
    _notifySafely();
    return result;
  }

  Future<void> _loadOfflineDatasets() async {
    final List<CollectionPoint> offlinePoints = await collectPointsRepository
        .loadOffline();
    final List<Campaign> offlineCampaigns = await campaignsRepository
        .loadOffline();
    await guideRepository.loadOffline();

    _points = List<CollectionPoint>.unmodifiable(offlinePoints);
    _campaigns = List<Campaign>.unmodifiable(offlineCampaigns);
    _pendingSuggestionsCount = await suggestionsRepository.pendingCount();
    _isStale = collectPointsRepository.isStale;
    _notifySafely();
  }

  void _onConnectivityChanged(bool online) {
    if (_disposed) {
      return;
    }

    final bool reconnected = !_isOnline && online;
    _isOnline = online;
    _notifySafely();

    if (reconnected || (online && (_isStale || _pendingSuggestionsCount > 0))) {
      unawaited(refreshAll());
    }
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySubscription?.cancel();
    connectivityService.dispose();
    super.dispose();
  }
}
