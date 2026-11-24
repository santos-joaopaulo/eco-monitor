import "dart:async";

import "package:flutter/foundation.dart";

import "../models/campaign.dart";
import "../models/collection_point.dart";
import "../models/point_review.dart";
import "../models/point_suggestion.dart";
import "campaigns_repository.dart";
import "collect_points_fetcher_firestore.dart";
import "collect_points_repository.dart";
import "connectivity_service.dart";
import "disposal_guide_repository_synced.dart";
import "firebase_service.dart";
import "point_reviews_repository.dart";
import "point_suggestions_repository.dart";


// Classes ----------------------------------------------------------------- //


/// Coordena a sincronização online com o Firebase e o armazenamento local offline
/// entre todos os repositórios do EcoMonitor (RF05, RNF09, RNF10, RNF11, RNF17).
class AppDataSync extends ChangeNotifier {
  AppDataSync({
    required this.collectPointsRepository,
    required this.campaignsRepository,
    required this.suggestionsRepository,
    required this.guideRepository,
    required this.connectivityService,
    this.reviewsRepository,
    this.syncInterval,
  });

  /// Constrói a instância de produção de [AppDataSync] conectada ao Cloud Firestore
  /// quando o Firebase estiver inicializado, ou apenas offline caso contrário.
  factory AppDataSync.createDefault({
    bool? firebaseEnabled,
    Duration? syncInterval,
  }) {
    final bool useRemote = firebaseEnabled ?? isFirebaseReady;
    final ConnectivityService connectivity = ConnectivityService();

    return AppDataSync(
      collectPointsRepository: CollectPointsRepository(
        fetcher: useRemote ? createFirestoreFetcher() : null,
        deltaFetcher: useRemote ? createFirestoreDeltaFetcher() : null,
      ),
      campaignsRepository: CampaignsRepository(
        fetcher: useRemote ? createFirestoreCampaignsFetcher() : null,
      ),
      suggestionsRepository: PointSuggestionsRepository(
        sender: useRemote ? createFirestoreSuggestionSender() : null,
        isOnlineChecker: () => connectivity.checkNow(),
      ),
      guideRepository: DisposalGuideRepositorySynced(
        fetcher: useRemote ? createFirestoreGuidesFetcher() : null,
      ),
      reviewsRepository: PointReviewsRepository(
        sender: useRemote ? createFirestorePointReviewSender() : null,
        isOnlineChecker: () => connectivity.checkNow(),
      ),
      connectivityService: connectivity,
      syncInterval: syncInterval ?? const Duration(hours: 6),
    );
  }

  final CollectPointsRepository collectPointsRepository;
  final CampaignsRepository campaignsRepository;
  final PointSuggestionsRepository suggestionsRepository;
  final DisposalGuideRepositorySynced guideRepository;
  final ConnectivityService connectivityService;
  final PointReviewsRepository? reviewsRepository;
  final Duration? syncInterval;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _periodicSyncTimer;
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


  /// Carrega os conjuntos de dados offline imediatamente, monitora mudanças de conectividade
  /// e atualiza a partir do Firebase quando online.
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

    // Configura checagem periódica silenciosa de deltas em segundo plano (T11.4)
    final Duration? interval = syncInterval;
    if (interval != null) {
      _periodicSyncTimer = Timer.periodic(
        interval,
        (_) => unawaited(checkDeltaSilently()),
      );
    }
  }

  /// Executa checagem periódica silenciosa de deltas em segundo plano sem bloquear a interface (T11.4).
  Future<void> checkDeltaSilently() async {
    if (_disposed || _isSyncing) {
      return;
    }

    final bool online = await connectivityService.checkNow();
    if (!online) {
      return;
    }

    try {
      final List<CollectionPoint> refreshedPoints =
          await collectPointsRepository.refresh();
      _points = List<CollectionPoint>.unmodifiable(refreshedPoints);
      _isStale = collectPointsRepository.isStale;
      _notifySafely();
    } catch (_) {
      // Ignora falhas em background para não degradar a experiência do usuário
    }
  }

  /// Atualiza pontos de coleta, campanhas e guias de descarte a partir do
  /// backend remoto e envia quaisquer sugestões offline enfileiradas.
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
        await reviewsRepository?.flushPending();

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

  /// Envia uma sugestão anônima de ponto, enfileirando-a offline automaticamente
  /// caso o dispositivo esteja desconectado ou a chamada remota falhe.
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

  /// Envia uma avaliação de ecoponto anonimamente, enfileirando-a offline
  /// caso o usuário esteja sem conexão com a internet.
  Future<PointReviewSubmitResult> submitReview(
    PointReview review,
  ) async {
    final PointReviewsRepository? repo = reviewsRepository;
    if (repo == null) {
      return PointReviewSubmitResult.queuedOffline;
    }
    final PointReviewSubmitResult result = await repo.submitReview(review);
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
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _connectivitySubscription?.cancel();
    connectivityService.dispose();
    super.dispose();
  }
}
