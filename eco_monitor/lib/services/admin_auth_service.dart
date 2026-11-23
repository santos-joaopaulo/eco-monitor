import "dart:convert";

import "package:crypto/crypto.dart";

import "../data/local_store.dart";


// Constants ---------------------------------------------------------------- //


const String _kAuthorizedTokenKey = "admin_auth_token";
const String _kFailedAttemptsKey = "admin_failed_attempts";
const String _kLockoutUntilKey = "admin_lockout_until";
const String _kSalt = "eco_monitor_admin_salt_2026";

/// Chave padrão de desenvolvimento caso nenhuma seja injetada via compilação.
const String kDefaultAdminKey = "eco@admin2026";

/// Limite de tentativas consecutivas incorretas antes do bloqueio temporário.
const int kMaxFailedAttempts = 5;

/// Duração do bloqueio em segundos após atingir o limite de tentativas.
const int kLockoutDurationSeconds = 30;


// Enums ------------------------------------------------------------------- //


enum AdminAuthStatus { success, invalidKey, lockedOut }


// Classes ----------------------------------------------------------------- //


/// Resultado detalhado de uma tentativa de autenticação no painel.
class AdminAuthResult {
  const AdminAuthResult._({
    required this.status,
    this.remainingLockoutSeconds = 0,
    this.attemptsRemaining = kMaxFailedAttempts,
  });

  factory AdminAuthResult.success() => const AdminAuthResult._(
    status: AdminAuthStatus.success,
  );

  factory AdminAuthResult.invalidKey(int attemptsRemaining) =>
      AdminAuthResult._(
        status: AdminAuthStatus.invalidKey,
        attemptsRemaining: attemptsRemaining,
      );

  factory AdminAuthResult.lockedOut(int remainingSeconds) => AdminAuthResult._(
    status: AdminAuthStatus.lockedOut,
    remainingLockoutSeconds: remainingSeconds,
    attemptsRemaining: 0,
  );

  final AdminAuthStatus status;
  final int remainingLockoutSeconds;
  final int attemptsRemaining;

  bool get isSuccess => status == AdminAuthStatus.success;
  bool get isLockedOut => status == AdminAuthStatus.lockedOut;
}

/// Serviço responsável por controlar a autorização do administrador e validar
/// a chave de acesso com hash SHA-256 e proteção contra força bruta (rate limiting).
class AdminAuthService {
  AdminAuthService({
    LocalStore? localStore,
    String? configuredKey,
    DateTime Function()? clock,
  }) : _store = localStore ?? SharedPreferencesLocalStore(),
       _configuredKey =
           configuredKey ??
           const String.fromEnvironment(
             "ADMIN_ACCESS_KEY",
             defaultValue: kDefaultAdminKey,
           ),
       _clock = clock ?? DateTime.now;

  final LocalStore _store;
  final String _configuredKey;
  final DateTime Function() _clock;


  // Methods --------------------------------------------------------------- //


  /// Indica se o dispositivo já foi autorizado anteriormente.
  Future<bool> isAuthorized() async {
    final String? token = await _store.getString(_kAuthorizedTokenKey);
    if (token == null || token.isEmpty) {
      return false;
    }

    final String expectedHash = _hashKey(_configuredKey);
    return token == expectedHash;
  }

  /// Retorna quantos segundos de bloqueio ainda restam, ou 0 se não bloqueado.
  Future<int> remainingLockoutSeconds() async {
    final int? lockoutUntilMs = await _store.getInt(_kLockoutUntilKey);
    if (lockoutUntilMs == null) {
      return 0;
    }

    final int nowMs = _clock().millisecondsSinceEpoch;
    final int diffMs = lockoutUntilMs - nowMs;
    if (diffMs <= 0) {
      // Bloqueio expirou: limpa os registros
      await _store.remove(_kLockoutUntilKey);
      await _store.remove(_kFailedAttemptsKey);
      return 0;
    }

    return (diffMs / 1000).ceil();
  }

  /// Tenta validar a [enteredKey] digitada pelo administrador.
  Future<AdminAuthResult> authenticate(String enteredKey) async {
    final int lockoutSeconds = await remainingLockoutSeconds();
    if (lockoutSeconds > 0) {
      return AdminAuthResult.lockedOut(lockoutSeconds);
    }

    final String enteredHash = _hashKey(enteredKey);
    final String expectedHash = _hashKey(_configuredKey);

    if (enteredHash == expectedHash) {
      // Sucesso: reseta contadores e persiste o token de autorização
      await _store.remove(_kFailedAttemptsKey);
      await _store.remove(_kLockoutUntilKey);
      await _store.setString(_kAuthorizedTokenKey, expectedHash);

      return AdminAuthResult.success();
    }

    // Chave incorreta: incrementa tentativas
    final int currentAttempts = (await _store.getInt(_kFailedAttemptsKey) ?? 0) + 1;
    await _store.setInt(_kFailedAttemptsKey, currentAttempts);

    if (currentAttempts >= kMaxFailedAttempts) {
      final int lockoutUntilMs =
          _clock().millisecondsSinceEpoch + (kLockoutDurationSeconds * 1000);
      await _store.setInt(_kLockoutUntilKey, lockoutUntilMs);

      return AdminAuthResult.lockedOut(kLockoutDurationSeconds);
    }

    final int attemptsRemaining = kMaxFailedAttempts - currentAttempts;
    return AdminAuthResult.invalidKey(attemptsRemaining);
  }

  /// Revoga a autorização do dispositivo, exigindo a chave no próximo acesso.
  Future<void> revokeAuthorization() async {
    await _store.remove(_kAuthorizedTokenKey);
  }


  // Helpers ----------------------------------------------------------------- //


  String _hashKey(String rawKey) {
    final List<int> bytes = utf8.encode("$_kSalt:$rawKey");
    return sha256.convert(bytes).toString();
  }
}
