import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/favorites_repository.dart";
import "package:eco_monitor/data/local_store.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group("FavoritesRepository — Testes Unitários de Persistência e Toggle (T9.1)", () {
    test("inicia vazio quando não há dados persistidos", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);

      final Set<String> favorites = await repo.getFavoriteIds();
      expect(favorites, isEmpty);
      expect(await repo.isFavorite("p1"), isFalse);
    });

    test("adiciona e remove ecopontos com sucesso", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);

      await repo.addFavorite("ponto_farolandia");
      expect(await repo.isFavorite("ponto_farolandia"), isTrue);
      expect(await repo.getFavoriteIds(), contains("ponto_farolandia"));

      await repo.removeFavorite("ponto_farolandia");
      expect(await repo.isFavorite("ponto_farolandia"), isFalse);
      expect(await repo.getFavoriteIds(), isEmpty);
    });

    test("toggleFavorite alterna o estado e retorna o novo valor booleano", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);

      final bool firstToggle = await repo.toggleFavorite("ponto_siqueira");
      expect(firstToggle, isTrue);
      expect(await repo.isFavorite("ponto_siqueira"), isTrue);

      final bool secondToggle = await repo.toggleFavorite("ponto_siqueira");
      expect(secondToggle, isFalse);
      expect(await repo.isFavorite("ponto_siqueira"), isFalse);
    });

    test("persiste entre diferentes instâncias sobre o mesmo LocalStore", () async {
      final InMemoryLocalStore sharedStore = InMemoryLocalStore();
      final FavoritesRepository repo1 = FavoritesRepository(localStore: sharedStore);

      await repo1.addFavorite("ponto_centro");
      await repo1.addFavorite("ponto_jardins");

      final FavoritesRepository repo2 = FavoritesRepository(localStore: sharedStore);
      final Set<String> loaded = await repo2.getFavoriteIds();

      expect(loaded, containsAll(<String>["ponto_centro", "ponto_jardins"]));
      expect(await repo2.isFavorite("ponto_centro"), isTrue);
      expect(await repo2.isFavorite("ponto_jardins"), isTrue);
      expect(await repo2.isFavorite("outro_ponto"), isFalse);
    });

    test("watchFavoriteIds emite eventos reativos a cada alteração", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final FavoritesRepository repo = FavoritesRepository(localStore: store);

      final List<Set<String>> emissions = <Set<String>>[];
      final subscription = repo.watchFavoriteIds().listen(emissions.add);

      await repo.addFavorite("p1");
      await repo.addFavorite("p2");
      await repo.removeFavorite("p1");

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(emissions, hasLength(3));
      expect(emissions[0], equals(<String>{"p1"}));
      expect(emissions[1], equals(<String>{"p1", "p2"}));
      expect(emissions[2], equals(<String>{"p2"}));

      await subscription.cancel();
      repo.dispose();
    });

    test("recupera conjunto vazio em caso de JSON corrompido no armazenamento", () async {
      final InMemoryLocalStore store = InMemoryLocalStore(<String, Object>{
        "favorite_collect_points_ids_v1": "{corrupted json invalid",
      });
      final FavoritesRepository repo = FavoritesRepository(localStore: store);

      final Set<String> favs = await repo.getFavoriteIds();
      expect(favs, isEmpty);
    });
  });
}
