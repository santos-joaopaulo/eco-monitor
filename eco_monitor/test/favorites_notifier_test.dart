import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/favorites_repository.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/presentation/state/favorites_notifier.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("FavoritesNotifier — Testes de Estado Reativo (T9.1)", () {
    test("carrega dados iniciais do repositório", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);
      await repo.addFavorite("ponto_inicial");

      final FavoritesNotifier notifier = FavoritesNotifier(repo);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(notifier.isFavorite("ponto_inicial"), isTrue);
      expect(notifier.favoriteIds, contains("ponto_inicial"));
      expect(notifier.isLoading, isFalse);
    });

    test("toggleFavorite atualiza o estado local e dispara notifyListeners", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);
      final FavoritesNotifier notifier = FavoritesNotifier(repo);

      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      final bool activated = await notifier.toggleFavorite("ponto_novo");
      expect(activated, isTrue);
      expect(notifier.isFavorite("ponto_novo"), isTrue);
      expect(notifyCount, greaterThan(0));

      final bool deactivated = await notifier.toggleFavorite("ponto_novo");
      expect(deactivated, isFalse);
      expect(notifier.isFavorite("ponto_novo"), isFalse);
      expect(await repo.isFavorite("ponto_novo"), isFalse);
    });

    test("reload sincroniza com alterações feitas diretamente no repositório", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);
      final FavoritesNotifier notifier = FavoritesNotifier(repo);

      await repo.addFavorite("ponto_externo");
      expect(notifier.isFavorite("ponto_externo"), isFalse);

      await notifier.reload();
      expect(notifier.isFavorite("ponto_externo"), isTrue);
    });
  });
}
