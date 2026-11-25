import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/point_reviews_repository.dart";
import "package:eco_monitor/models/point_review.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PointReview createReview({
    String id = "rev_1",
    String pointId = "ponto_aracaju_1",
    int rating = 5,
    List<String> tags = const <String>[PointReviewTags.accessibleCollector],
  }) {
    return PointReview(
      id: id,
      pointId: pointId,
      rating: rating,
      tags: tags,
      createdAt: DateTime.utc(2026, 11, 23, 10),
      comment: "Ótimo ponto de descarte",
    );
  }

  group("PointReview — Modelo e Serialização JSON", () {
    test("serializa e desserializa preservando campos e integridade", () {
      final PointReview original = createReview();
      final Map<String, dynamic> json = original.toJson();
      final PointReview parsed = PointReview.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.pointId, original.pointId);
      expect(parsed.rating, original.rating);
      expect(parsed.tags, original.tags);
      expect(parsed.createdAt, original.createdAt);
      expect(parsed.comment, original.comment);
    });
  });

  group("PointReviewsRepository — Envio, Fila Offline e Estatísticas (T9.2)", () {
    test("envia diretamente ao servidor remoto quando online e sem erros", () async {
      final List<PointReview> remoteSent = <PointReview>[];
      final InMemoryLocalStore store = InMemoryLocalStore();

      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
        sender: (PointReview rev) async {
          remoteSent.add(rev);
        },
      );

      final PointReview rev = createReview();
      final PointReviewSubmitResult result = await repo.submitReview(rev);

      expect(result, PointReviewSubmitResult.sent);
      expect(remoteSent, hasLength(1));
      expect(await repo.pendingCount(), 0);

      // Também deve estar disponível na consulta local imediatamente
      final List<PointReview> localList = await repo.getReviewsForPoint(rev.pointId);
      expect(localList, hasLength(1));
      expect(localList.first.id, rev.id);
    });

    test("enfileira offline no LocalStore quando sem remetente remoto ou erro de conexão", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();

      // Sem sender configurado (offline)
      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
        sender: null,
      );

      final PointReview rev = createReview(id: "offline_1");
      final PointReviewSubmitResult result = await repo.submitReview(rev);

      expect(result, PointReviewSubmitResult.queuedOffline);
      expect(await repo.pendingCount(), 1);

      // Disponível localmente mesmo offline
      final PointReviewStats stats = await repo.getStatsForPoint(rev.pointId);
      expect(stats.totalReviews, 1);
      expect(stats.averageRating, 5.0);
    });

    test("calcula médias ponderadas e contagem de tags com precisão", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
      );

      const String pointId = "ponto_calc";
      await repo.submitReview(createReview(
        id: "r1",
        pointId: pointId,
        rating: 5,
        tags: const <String>[PointReviewTags.accessibleCollector, PointReviewTags.veryGood],
      ));
      await repo.submitReview(createReview(
        id: "r2",
        pointId: pointId,
        rating: 4,
        tags: const <String>[PointReviewTags.accessibleCollector],
      ));
      await repo.submitReview(createReview(
        id: "r3",
        pointId: pointId,
        rating: 3,
        tags: const <String>[PointReviewTags.fullCollector],
      ));

      final PointReviewStats stats = await repo.getStatsForPoint(pointId);
      expect(stats.totalReviews, 3);
      // (5 + 4 + 3) / 3 = 4.0
      expect(stats.averageRating, 4.0);
      expect(stats.tagCounts[PointReviewTags.accessibleCollector], 2);
      expect(stats.tagCounts[PointReviewTags.veryGood], 1);
      expect(stats.tagCounts[PointReviewTags.fullCollector], 1);
      expect(stats.topTags.first, PointReviewTags.accessibleCollector);
    });

    test("flushPending descarrega a fila offline assim que a conexão volta", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      bool isOnline = false;
      final List<PointReview> delivered = <PointReview>[];

      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
        sender: (PointReview rev) async {
          if (!isOnline) {
            throw Exception("Sem conexão com a internet");
          }
          delivered.add(rev);
        },
      );

      // Submissão offline
      await repo.submitReview(createReview(id: "off_1"));
      await repo.submitReview(createReview(id: "off_2"));
      expect(await repo.pendingCount(), 2);
      expect(delivered, isEmpty);

      // Simula restabelecimento de conectividade
      isOnline = true;
      final int sent = await repo.flushPending();

      expect(sent, 2);
      expect(delivered, hasLength(2));
      expect(await repo.pendingCount(), 0);
    });

    test("clearPending limpa todos os itens da fila offline", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
      );

      await repo.submitReview(createReview(id: "p1"));
      await repo.submitReview(createReview(id: "p2"));
      expect(await repo.pendingCount(), 2);

      await repo.clearPending();
      expect(await repo.pendingCount(), 0);
    });

    test("isOnlineChecker falso pula remoteSender e enfileira offline imediatamente", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      bool senderCalled = false;

      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
        isOnlineChecker: () async => false,
        sender: (PointReview rev) async {
          senderCalled = true;
        },
      );

      final PointReview rev = createReview(id: "fast_off_1");
      final PointReviewSubmitResult result = await repo.submitReview(rev);

      expect(result, PointReviewSubmitResult.queuedOffline);
      expect(senderCalled, isFalse);
      expect(await repo.pendingCount(), 1);

      // Avaliação já disponível localmente
      final PointReviewStats stats = await repo.getStatsForPoint(rev.pointId);
      expect(stats.totalReviews, 1);
    });

    test("refresh sincroniza avaliações remotas de outros dispositivos", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final PointReview remoteRev1 = createReview(
        id: "remote_1",
        pointId: "ponto_x",
        rating: 4,
      );
      final PointReview remoteRev2 = createReview(
        id: "remote_2",
        pointId: "ponto_x",
        rating: 2,
      );

      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
        fetcher: () async => <PointReview>[remoteRev1, remoteRev2],
      );

      expect(await repo.getReviewsForPoint("ponto_x"), isEmpty);

      await repo.refresh();

      final List<PointReview> synced = await repo.getReviewsForPoint("ponto_x");
      expect(synced.map((PointReview r) => r.id), <String>[
        "remote_1",
        "remote_2",
      ]);

      final PointReviewStats stats = await repo.getStatsForPoint("ponto_x");
      expect(stats.totalReviews, 2);
      expect(stats.averageRating, 3.0);
    });

    test("refresh preserva avaliações pendentes offline e remove excluídas remotamente", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final List<PointReview> remoteDb = <PointReview>[
        createReview(id: "remote_keep", pointId: "ponto_y", rating: 5),
        createReview(id: "remote_deleted", pointId: "ponto_y", rating: 1),
      ];

      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
        fetcher: () async => List<PointReview>.of(remoteDb),
      );

      await repo.refresh();
      expect((await repo.getReviewsForPoint("ponto_y")).length, 2);

      // Enfileira uma avaliação offline local (sender == null)
      await repo.submitReview(
        createReview(id: "local_pending", pointId: "ponto_y", rating: 3),
      );

      // Remove uma avaliação no banco remoto
      remoteDb.removeWhere((PointReview r) => r.id == "remote_deleted");
      await repo.refresh();

      final List<String> ids = (await repo.getReviewsForPoint("ponto_y"))
          .map((PointReview r) => r.id)
          .toList();
      expect(ids, containsAll(<String>["local_pending", "remote_keep"]));
      expect(ids, isNot(contains("remote_deleted")));
    });

    test("refresh mantém cache local quando o fetcher remoto falha", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
        fetcher: () async => throw Exception("Falha de rede"),
      );

      await repo.submitReview(createReview(id: "local_1", pointId: "ponto_z"));
      await repo.refresh();

      final List<PointReview> list = await repo.getReviewsForPoint("ponto_z");
      expect(list.map((PointReview r) => r.id), <String>["local_1"]);
    });
  });
}
