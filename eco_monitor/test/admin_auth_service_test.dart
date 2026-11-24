import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/services/admin_auth_service.dart";


// Testes ------------------------------------------------------------------ //


void main() {
  late InMemoryLocalStore store;
  late DateTime fakeNow;

  setUp(() {
    store = InMemoryLocalStore();
    fakeNow = DateTime(2026, 11, 22, 10, 0, 0);
  });

  AdminAuthService createService({String? configuredKey}) {
    return AdminAuthService(
      localStore: store,
      configuredKey: configuredKey ?? "secret123",
      clock: () => fakeNow,
    );
  }

  test("isAuthorized returns false initially on a clean device", () async {
    final AdminAuthService service = createService();
    expect(await service.isAuthorized(), isFalse);
    expect(await service.remainingLockoutSeconds(), 0);
  });

  test("authenticate with correct key succeeds and persists authorization", () async {
    final AdminAuthService service = createService();

    final AdminAuthResult result = await service.authenticate("secret123");
    expect(result.isSuccess, isTrue);
    expect(result.isLockedOut, isFalse);
    expect(await service.isAuthorized(), isTrue);
  });

  test("authenticate with incorrect key decrements attempts remaining", () async {
    final AdminAuthService service = createService();

    final AdminAuthResult result1 = await service.authenticate("wrong1");
    expect(result1.isSuccess, isFalse);
    expect(result1.attemptsRemaining, 4);
    expect(await service.isAuthorized(), isFalse);

    final AdminAuthResult result2 = await service.authenticate("wrong2");
    expect(result2.isSuccess, isFalse);
    expect(result2.attemptsRemaining, 3);
  });

  test("5 consecutive failed attempts trigger rate limiting lockout for 30s", () async {
    final AdminAuthService service = createService();

    for (int i = 0; i < 4; i++) {
      await service.authenticate("wrong");
    }

    // 5ª tentativa incorreta
    final AdminAuthResult fifthResult = await service.authenticate("wrong");
    expect(fifthResult.isLockedOut, isTrue);
    expect(fifthResult.remainingLockoutSeconds, 30);
    expect(await service.remainingLockoutSeconds(), 30);

    // Tentativa durante o bloqueio é imediatamente rejeitada
    final AdminAuthResult duringLockout = await service.authenticate("secret123");
    expect(duringLockout.isLockedOut, isTrue);
    expect(duringLockout.remainingLockoutSeconds, 30);

    // Avança o relógio em 31 segundos
    fakeNow = fakeNow.add(const Duration(seconds: 31));

    expect(await service.remainingLockoutSeconds(), 0);

    // Agora a chave correta é aceita
    final AdminAuthResult afterLockout = await service.authenticate("secret123");
    expect(afterLockout.isSuccess, isTrue);
    expect(await service.isAuthorized(), isTrue);
  });

  test("revokeAuthorization clears authorization status", () async {
    final AdminAuthService service = createService();

    await service.authenticate("secret123");
    expect(await service.isAuthorized(), isTrue);

    await service.revokeAuthorization();
    expect(await service.isAuthorized(), isFalse);
  });

  test("authorization expires automatically after TTL (2 hours) of inactivity", () async {
    final AdminAuthService service = createService();

    await service.authenticate("secret123");
    expect(await service.isAuthorized(), isTrue);

    // Avança 1 hora e 59 minutos: ainda autorizado
    fakeNow = fakeNow.add(const Duration(minutes: 119));
    expect(await service.isAuthorized(), isTrue);

    // Avança mais 2 minutos (ultrapassando 2 horas): expira
    fakeNow = fakeNow.add(const Duration(minutes: 2));
    expect(await service.isAuthorized(), isFalse);
  });

  test("touchSession renews session expiration window", () async {
    final AdminAuthService service = createService();

    await service.authenticate("secret123");
    expect(await service.isAuthorized(), isTrue);

    // Avança 1 hora e 30 minutos e renova a sessão
    fakeNow = fakeNow.add(const Duration(minutes: 90));
    await service.touchSession();

    // Avança mais 1 hora e 30 minutos (total 3h desde autenticação inicial, mas 1h30 desde touch): deve estar ativo
    fakeNow = fakeNow.add(const Duration(minutes: 90));
    expect(await service.isAuthorized(), isTrue);

    // Avança mais 40 minutos (total 2h10 desde o touch): expira
    fakeNow = fakeNow.add(const Duration(minutes: 40));
    expect(await service.isAuthorized(), isFalse);
  });
}
