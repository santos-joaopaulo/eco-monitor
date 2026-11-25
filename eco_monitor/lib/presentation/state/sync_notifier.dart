import "package:flutter/foundation.dart";

import "../../data/app_data_sync.dart";


// Notifiers ---------------------------------------------------------------- //


/// Notificador reativo de estado de sincronização e rede (Presentation).
class SyncNotifier extends ChangeNotifier {
  SyncNotifier(this._dataSync) {
    _dataSync.addListener(_onSyncChanged);
  }

  final AppDataSync _dataSync;

  bool get isOnline => _dataSync.isOnline;

  bool get isSyncing => _dataSync.isSyncing;

  bool get isStale => _dataSync.isStale;

  DateTime? get lastUpdated => _dataSync.lastUpdated;

  int get pendingSyncCount => _dataSync.pendingSyncCount;

  int get pendingSuggestionsCount => _dataSync.pendingSyncCount;

  AppDataSync get dataSync => _dataSync;


// Methods ------------------------------------------------------------------ //


  void _onSyncChanged() {
    notifyListeners();
  }

  /// Dispara atualização forçada de todas as coleções.
  Future<void> refreshAll() async {
    await _dataSync.refreshAll();
  }

  @override
  void dispose() {
    _dataSync.removeListener(_onSyncChanged);
    super.dispose();
  }
}
