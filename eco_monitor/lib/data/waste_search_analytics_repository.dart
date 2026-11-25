import "dart:async";
import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";

import "../domain/entities/brazil_state.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/waste_search_analytics_repository_contract.dart";
import "firebase_service.dart";
import "local_store.dart";


// Constants ---------------------------------------------------------------- //


/// Coleção do Cloud Firestore onde o ranking agregado de pesquisas é armazenado.
const String kWasteSearchAnalyticsCollection = "waste_search_analytics";

/// Identificador de documento para o ranking nacional padrão (todos os dispositivos).
const String kGlobalAnalyticsScope = "ALL";

const String _remoteCacheKeyPrefix = "waste_search_remote_cache_v1_";
const String _pendingQueueKey = "waste_search_pending_queue_v1";


// Types -------------------------------------------------------------------- //


/// Função usada para enviar incrementos de contagem de pesquisa para o backend remoto.
typedef WasteSearchSender = Future<void> Function(
  String scope,
  Map<WasteType, int> increments,
);

/// Função usada para buscar contagens agregadas remotas para um escopo ("ALL" ou UF).
typedef WasteSearchFetcher = Future<Map<WasteType, int>> Function(String scope);


// Methods ------------------------------------------------------------------ //


/// Cria um [WasteSearchSender] integrado ao Cloud Firestore com incremento atômico.
WasteSearchSender createFirestoreWasteSearchSender({
  FirebaseFirestore? firestore,
}) {
  return (String scope, Map<WasteType, int> increments) async {
    if (increments.isEmpty) {
      return;
    }
    if (firestore == null && !isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }

    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final Map<String, Object> countUpdates = <String, Object>{};
    for (final MapEntry<WasteType, int> entry in increments.entries) {
      if (entry.value > 0) {
        countUpdates[entry.key.name] = FieldValue.increment(entry.value);
      }
    }
    if (countUpdates.isEmpty) {
      return;
    }

    await db
        .collection(kWasteSearchAnalyticsCollection)
        .doc(scope)
        .set(<String, Object?>{
          "scope": scope,
          "counts": countUpdates,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  };
}

/// Cria um [WasteSearchFetcher] integrado à coleção `waste_search_analytics` do Firestore.
WasteSearchFetcher createFirestoreWasteSearchFetcher({
  FirebaseFirestore? firestore,
}) {
  return (String scope) async {
    if (firestore == null && !isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }

    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final DocumentSnapshot<Map<String, dynamic>> doc = await db
        .collection(kWasteSearchAnalyticsCollection)
        .doc(scope)
        .get();

    if (!doc.exists) {
      return <WasteType, int>{};
    }

    final Object? rawCounts = doc.data()?["counts"];
    if (rawCounts is! Map) {
      return <WasteType, int>{};
    }

    final Map<WasteType, int> parsed = <WasteType, int>{};
    for (final WasteType type in WasteType.values) {
      final Object? value = rawCounts[type.name];
      if (value is num && value > 0) {
        parsed[type] = value.toInt();
      }
    }
    return parsed;
  };
}


// Repositories ------------------------------------------------------------- //


/// Repositório offline-first e sincronizado com Cloud Firestore para o ranking
/// comunitário de pesquisas de resíduos (nacional e por UF).
class WasteSearchAnalyticsRepository
    implements IWasteSearchAnalyticsRepository {
  WasteSearchAnalyticsRepository({
    LocalStore? localStore,
    this.sender,
    this.fetcher,
    this.isOnlineChecker,
    this.onPendingChanged,
  }) : _store = localStore ?? SharedPreferencesLocalStore();

  final LocalStore _store;
  final WasteSearchSender? sender;
  final WasteSearchFetcher? fetcher;
  final Future<bool> Function()? isOnlineChecker;

  /// Callback opcional acionado quando a fila offline de incrementos é alterada.
  void Function()? onPendingChanged;

  Future<void> _lock = Future<void>.value();


// Public Methods ----------------------------------------------------------- //


  @override
  Future<void> recordSearch(WasteType type, {String? stateCode}) {
    return _synchronized(() async {
      final String? normalizedState = BrazilStates.normalizeCode(stateCode);
      final List<String> scopes = <String>[
        kGlobalAnalyticsScope,
        ?normalizedState,
      ];

      final bool canSendRemotely = sender != null && await _isOnline();

      for (final String scope in scopes) {
        if (canSendRemotely) {
          try {
            await sender!(scope, <WasteType, int>{type: 1});
            await _incrementLocalCacheUnsafe(scope, type, 1);
            continue;
          } catch (_) {
            // Em caso de falha na rede/Firestore, enfileira localmente para envio posterior.
          }
        }
        await _enqueuePendingUnsafe(scope, type, 1);
      }
    });
  }

  @override
  Future<int> getSearchCount(WasteType type, {String? stateCode}) async {
    final List<WasteSearchStat> stats = await getRankedStats(
      stateCode: stateCode,
    );
    for (final WasteSearchStat stat in stats) {
      if (stat.type == type) {
        return stat.count;
      }
    }
    return 0;
  }

  @override
  Future<List<WasteSearchStat>> getRankedStats({String? stateCode}) {
    return _synchronized(() async {
      final String scope =
          BrazilStates.normalizeCode(stateCode) ?? kGlobalAnalyticsScope;

      Map<WasteType, int> baseCounts = await _readLocalCacheUnsafe(scope);

      if (fetcher != null && await _isOnline()) {
        await _flushPendingUnsafe();
        try {
          final Map<WasteType, int> remoteCounts = await fetcher!(scope);
          baseCounts = remoteCounts;
          await _writeLocalCacheUnsafe(scope, remoteCounts);
        } catch (_) {
          // Mantém o cache local quando a leitura remota falhar.
        }
      }

      final Map<String, Map<WasteType, int>> pendingAll =
          await _readPendingUnsafe();
      final Map<WasteType, int> pendingScope =
          pendingAll[scope] ?? const <WasteType, int>{};

      final Map<WasteType, int> combined = <WasteType, int>{};
      int total = 0;

      for (final WasteType type in WasteType.values) {
        final int count =
            (baseCounts[type] ?? 0) + (pendingScope[type] ?? 0);
        combined[type] = count;
        total += count;
      }

      final List<WasteSearchStat> stats = <WasteSearchStat>[];
      for (final WasteType type in WasteType.values) {
        final int count = combined[type] ?? 0;
        final double percentage = total > 0 ? (count / total) * 100.0 : 0.0;
        stats.add(
          WasteSearchStat(
            type: type,
            count: count,
            percentage: percentage,
          ),
        );
      }

      stats.sort((WasteSearchStat a, WasteSearchStat b) {
        final int cmp = b.count.compareTo(a.count);
        if (cmp != 0) {
          return cmp;
        }
        return a.type.index.compareTo(b.type.index);
      });

      return stats;
    });
  }

  @override
  Future<void> flushPending() {
    return _synchronized(_flushPendingUnsafe);
  }

  @override
  Future<int> pendingCount() {
    return _synchronized(() async {
      final Map<String, Map<WasteType, int>> pending =
          await _readPendingUnsafe();
      final Map<WasteType, int>? globalPending =
          pending[kGlobalAnalyticsScope];
      if (globalPending != null) {
        return globalPending.values.fold<int>(
          0,
          (int sum, int count) => sum + count,
        );
      }
      int total = 0;
      for (final Map<WasteType, int> scopeMap in pending.values) {
        for (final int count in scopeMap.values) {
          total += count;
        }
      }
      return total;
    });
  }

  @override
  Future<void> clear() {
    return _synchronized(() async {
      await _store.remove(_pendingQueueKey);
      await _store.remove("$_remoteCacheKeyPrefix$kGlobalAnalyticsScope");
      for (final BrazilState state in kBrazilStates) {
        await _store.remove("$_remoteCacheKeyPrefix${state.code}");
      }
      onPendingChanged?.call();
    });
  }


// Private Methods ---------------------------------------------------------- //


  Future<T> _synchronized<T>(Future<T> Function() action) {
    final Completer<T> completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<bool> _isOnline() async {
    if (isOnlineChecker == null) {
      return true;
    }
    try {
      return await isOnlineChecker!();
    } catch (_) {
      return true;
    }
  }

  Future<void> _flushPendingUnsafe() async {
    final WasteSearchSender? remoteSender = sender;
    if (remoteSender == null || !await _isOnline()) {
      return;
    }

    final Map<String, Map<WasteType, int>> pending = await _readPendingUnsafe();
    if (pending.isEmpty) {
      return;
    }

    final List<String> flushedScopes = <String>[];
    for (final MapEntry<String, Map<WasteType, int>> entry in pending.entries) {
      final String scope = entry.key;
      final Map<WasteType, int> increments = entry.value;
      if (increments.isEmpty) {
        flushedScopes.add(scope);
        continue;
      }

      try {
        await remoteSender(scope, increments);
        for (final MapEntry<WasteType, int> typeEntry in increments.entries) {
          await _incrementLocalCacheUnsafe(
            scope,
            typeEntry.key,
            typeEntry.value,
          );
        }
        flushedScopes.add(scope);
      } catch (_) {
        // Mantém este escopo na fila para tentar novamente no próximo sync.
      }
    }

    if (flushedScopes.isNotEmpty) {
      for (final String scope in flushedScopes) {
        pending.remove(scope);
      }
      await _writePendingUnsafe(pending);
      onPendingChanged?.call();
    }
  }

  Future<Map<WasteType, int>> _readLocalCacheUnsafe(String scope) async {
    final String? raw = await _store.getString("$_remoteCacheKeyPrefix$scope");
    if (raw == null || raw.isEmpty) {
      return <WasteType, int>{};
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <WasteType, int>{};
      }
      return _decodeCountsMap(decoded);
    } catch (_) {
      return <WasteType, int>{};
    }
  }

  Future<void> _writeLocalCacheUnsafe(
    String scope,
    Map<WasteType, int> counts,
  ) async {
    final Map<String, int> encoded = _encodeCountsMap(counts);
    await _store.setString("$_remoteCacheKeyPrefix$scope", jsonEncode(encoded));
  }

  Future<void> _incrementLocalCacheUnsafe(
    String scope,
    WasteType type,
    int delta,
  ) async {
    if (delta <= 0) {
      return;
    }
    final Map<WasteType, int> current = await _readLocalCacheUnsafe(scope);
    current[type] = (current[type] ?? 0) + delta;
    await _writeLocalCacheUnsafe(scope, current);
  }

  Future<Map<String, Map<WasteType, int>>> _readPendingUnsafe() async {
    final String? raw = await _store.getString(_pendingQueueKey);
    if (raw == null || raw.isEmpty) {
      return <String, Map<WasteType, int>>{};
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, Map<WasteType, int>>{};
      }

      final Map<String, Map<WasteType, int>> result =
          <String, Map<WasteType, int>>{};
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        if (entry.value is Map<String, dynamic>) {
          final Map<WasteType, int> counts = _decodeCountsMap(
            entry.value as Map<String, dynamic>,
          );
          if (counts.isNotEmpty) {
            result[entry.key] = counts;
          }
        }
      }
      return result;
    } catch (_) {
      return <String, Map<WasteType, int>>{};
    }
  }

  Future<void> _writePendingUnsafe(
    Map<String, Map<WasteType, int>> pending,
  ) async {
    if (pending.isEmpty) {
      await _store.remove(_pendingQueueKey);
      return;
    }

    final Map<String, Map<String, int>> encoded =
        <String, Map<String, int>>{};
    for (final MapEntry<String, Map<WasteType, int>> entry in pending.entries) {
      final Map<String, int> scopeEncoded = _encodeCountsMap(entry.value);
      if (scopeEncoded.isNotEmpty) {
        encoded[entry.key] = scopeEncoded;
      }
    }

    if (encoded.isEmpty) {
      await _store.remove(_pendingQueueKey);
    } else {
      await _store.setString(_pendingQueueKey, jsonEncode(encoded));
    }
  }

  Future<void> _enqueuePendingUnsafe(
    String scope,
    WasteType type,
    int delta,
  ) async {
    if (delta <= 0) {
      return;
    }
    final Map<String, Map<WasteType, int>> pending = await _readPendingUnsafe();
    final Map<WasteType, int> scopeMap =
        pending.putIfAbsent(scope, () => <WasteType, int>{});
    scopeMap[type] = (scopeMap[type] ?? 0) + delta;
    await _writePendingUnsafe(pending);
    onPendingChanged?.call();
  }

  Map<WasteType, int> _decodeCountsMap(Map<String, dynamic> raw) {
    final Map<WasteType, int> parsed = <WasteType, int>{};
    for (final WasteType type in WasteType.values) {
      final Object? value = raw[type.name];
      if (value is num && value > 0) {
        parsed[type] = value.toInt();
      }
    }
    return parsed;
  }

  Map<String, int> _encodeCountsMap(Map<WasteType, int> counts) {
    final Map<String, int> encoded = <String, int>{};
    for (final MapEntry<WasteType, int> entry in counts.entries) {
      if (entry.value > 0) {
        encoded[entry.key.name] = entry.value;
      }
    }
    return encoded;
  }
}
