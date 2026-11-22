import "package:shared_preferences/shared_preferences.dart";


// Interfaces -------------------------------------------------------------- //


/// Contrato abstrato para operações assíncronas de armazenamento chave-valor local.
abstract interface class LocalStore {
  /// Obtém a string associada a [key], ou `null` se ausente.
  Future<String?> getString(String key);

  /// Salva [value] na [key] especificada.
  Future<void> setString(String key, String value);

  /// Obtém o inteiro associado a [key], ou `null` se ausente.
  Future<int?> getInt(String key);

  /// Salva [value] inteiro na [key] especificada.
  Future<void> setInt(String key, int value);

  /// Remove a entrada sob [key].
  Future<void> remove(String key);
}


// Implementations --------------------------------------------------------- //


/// Implementação de [LocalStore] sobre [SharedPreferences].
class SharedPreferencesLocalStore implements LocalStore {
  SharedPreferencesLocalStore({
    Future<SharedPreferences> Function()? preferencesFactory,
  }) : _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferencesFactory;

  @override
  Future<String?> getString(String key) async {
    final SharedPreferences preferences = await _preferencesFactory();
    return preferences.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    final SharedPreferences preferences = await _preferencesFactory();
    await preferences.setString(key, value);
  }

  @override
  Future<int?> getInt(String key) async {
    final SharedPreferences preferences = await _preferencesFactory();
    return preferences.getInt(key);
  }

  @override
  Future<void> setInt(String key, int value) async {
    final SharedPreferences preferences = await _preferencesFactory();
    await preferences.setInt(key, value);
  }

  @override
  Future<void> remove(String key) async {
    final SharedPreferences preferences = await _preferencesFactory();
    await preferences.remove(key);
  }
}

/// Implementação em memória de [LocalStore] para testes e isolamento de estado.
class InMemoryLocalStore implements LocalStore {
  InMemoryLocalStore([Map<String, Object>? initialValues])
    : _storage = <String, Object>{...?initialValues};

  final Map<String, Object> _storage;

  @override
  Future<String?> getString(String key) async {
    final Object? value = _storage[key];
    return value is String ? value : null;
  }

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<int?> getInt(String key) async {
    final Object? value = _storage[key];
    return value is int ? value : null;
  }

  @override
  Future<void> setInt(String key, int value) async {
    _storage[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}
