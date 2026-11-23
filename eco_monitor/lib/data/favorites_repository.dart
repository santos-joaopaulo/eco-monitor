import "dart:async";
import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

import "../domain/repositories/favorites_repository_contract.dart";
import "local_store.dart";


// Constants ---------------------------------------------------------------- //


const String _favoritesStoreKey = "favorite_collect_points_ids_v1";


// Classes ----------------------------------------------------------------- //


/// Implementação offline-first de [IFavoritesRepository] persistida no [LocalStore]
/// (SharedPreferences), garantindo disponibilidade 100% offline e retenção permanente.
class FavoritesRepository implements IFavoritesRepository {
  FavoritesRepository({
    LocalStore? localStore,
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _store = localStore ??
           SharedPreferencesLocalStore(
             preferencesFactory: preferencesFactory,
           );

  final LocalStore _store;
  final StreamController<Set<String>> _favoritesController =
      StreamController<Set<String>>.broadcast();

  Set<String>? _cachedIds;
  Future<void> _lock = Future<void>.value();


  // Methods --------------------------------------------------------------- //


  @override
  Future<Set<String>> getFavoriteIds() {
    return _synchronized(() async {
      return _loadIdsUnsafe();
    });
  }

  @override
  Future<bool> isFavorite(String pointId) {
    return _synchronized(() async {
      final Set<String> ids = await _loadIdsUnsafe();
      return ids.contains(pointId);
    });
  }

  @override
  Future<void> addFavorite(String pointId) {
    return _synchronized(() async {
      final Set<String> ids = await _loadIdsUnsafe();
      if (!ids.contains(pointId)) {
        ids.add(pointId);
        await _persistIdsUnsafe(ids);
      }
    });
  }

  @override
  Future<void> removeFavorite(String pointId) {
    return _synchronized(() async {
      final Set<String> ids = await _loadIdsUnsafe();
      if (ids.contains(pointId)) {
        ids.remove(pointId);
        await _persistIdsUnsafe(ids);
      }
    });
  }

  @override
  Future<bool> toggleFavorite(String pointId) {
    return _synchronized(() async {
      final Set<String> ids = await _loadIdsUnsafe();
      final bool nowFavorite;
      if (ids.contains(pointId)) {
        ids.remove(pointId);
        nowFavorite = false;
      } else {
        ids.add(pointId);
        nowFavorite = true;
      }
      await _persistIdsUnsafe(ids);
      return nowFavorite;
    });
  }

  @override
  Stream<Set<String>> watchFavoriteIds() {
    return _favoritesController.stream;
  }

  /// Libera recursos do repositório.
  void dispose() {
    _favoritesController.close();
  }


  // Helpers ----------------------------------------------------------------- //


  Future<Set<String>> _loadIdsUnsafe() async {
    final Set<String>? cached = _cachedIds;
    if (cached != null) {
      return Set<String>.of(cached);
    }

    final String? rawJson = await _store.getString(_favoritesStoreKey);
    if (rawJson == null || rawJson.trim().isEmpty) {
      _cachedIds = <String>{};
      return <String>{};
    }

    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is List) {
        final Set<String> parsed = decoded
            .whereType<String>()
            .toSet();
        _cachedIds = parsed;
        return Set<String>.of(parsed);
      }
    } catch (_) {
      // Ignora payload corrompido e recupera conjunto vazio seguro
    }

    _cachedIds = <String>{};
    return <String>{};
  }

  Future<void> _persistIdsUnsafe(Set<String> ids) async {
    _cachedIds = Set<String>.of(ids);
    final String encoded = jsonEncode(ids.toList()..sort());
    await _store.setString(_favoritesStoreKey, encoded);
    if (!_favoritesController.isClosed) {
      _favoritesController.add(Set<String>.unmodifiable(ids));
    }
  }

  Future<T> _synchronized<T>(Future<T> Function() computation) {
    final Completer<T> completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        final T result = await computation();
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
