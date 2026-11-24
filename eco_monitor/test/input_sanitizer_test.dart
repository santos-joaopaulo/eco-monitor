import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/point_reviews_repository.dart";
import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/domain/entities/point_review.dart";
import "package:eco_monitor/domain/entities/point_suggestion.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/utils/input_sanitizer.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("InputSanitizer — Esterilização e Proteção contra Injeção", () {
    test("remove tags HTML e scripts maliciosos", () {
      const String malicious = "Ecoponto <script>alert('xss')</script> Central";
      expect(InputSanitizer.sanitizeText(malicious), "Ecoponto Central");

      const String imgPayload = "Bairro <img src=x onerror=alert(1)> Sul";
      expect(InputSanitizer.sanitizeText(imgPayload), "Bairro Sul");

      const String iframePayload = "Rua A <iframe src='malicious.site'></iframe>";
      expect(InputSanitizer.sanitizeText(iframePayload), "Rua A");
    });

    test("remove caracteres ASCII de controle e Unicode invisíveis", () {
      const String invisible = "Ecoponto\u200B \uFEFF\x00\x1FInvisível";
      expect(InputSanitizer.sanitizeText(invisible), "Ecoponto Invisível");
    });

    test("trunca no tamanho máximo seguro respeitando maxLength", () {
      final String longText = "A" * 350;
      final String sanitized = InputSanitizer.sanitizeText(longText, maxLength: 100);
      expect(sanitized.length, 100);
    });

    test("lida com nulos e strings vazias sem falhas", () {
      expect(InputSanitizer.sanitizeText(null), "");
      expect(InputSanitizer.sanitizeText("   "), "");
    });
  });

  group("PointSuggestion & PointReview — Defesa Automática em Entidades", () {
    test("higieniza entradas perigosas na criação de PointSuggestion", () {
      final String longX = "X" * 150;
      final String longY = "Y" * 250;
      final String longZ = "Z" * 150;

      final PointSuggestion suggestion = PointSuggestion(
        id: "sug_1",
        name: "Ponto <script>malware()</script> $longX",
        address: "Av. Principal <iframe/> $longY",
        acceptedWasteTypes: const <WasteType>{WasteType.electronics},
        hours: "Seg a Sex \x00\x1B $longZ",
        latitude: -10.9,
        longitude: -37.0,
        status: SuggestionStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(suggestion.name.contains("<script>"), isFalse);
      expect(suggestion.name.length <= 100, isTrue);

      expect(suggestion.address.contains("<iframe/>"), isFalse);
      expect(suggestion.address.length <= 200, isTrue);

      expect(suggestion.hours.length <= 100, isTrue);
    });

    test("higieniza comentários perigosos na criação de PointReview", () {
      final String longW = "W" * 350;

      final PointReview review = PointReview(
        id: "rev_sec_1",
        pointId: "pt_1",
        rating: 5,
        tags: const <String>["Coletor acessível"],
        createdAt: DateTime.now(),
        comment: "Excelente ponto! <script>fetch('hack')</script> $longW",
      );

      expect(review.comment.contains("<script>"), isFalse);
      expect(review.comment.length <= 300, isTrue);
    });
  });

  group("Cotas Máximas e Rate Limiting Local", () {
    test("PointSuggestionsRepository limita a fila offline em no máximo kMaxQueuedSuggestions (50)", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final PointSuggestionsRepository repo = PointSuggestionsRepository(
        localStore: store,
        sender: null, // Força contingência offline
      );

      for (int i = 0; i < 55; i++) {
        await repo.submit(
          PointSuggestion(
            id: "sug_$i",
            name: "Sugestão $i",
            address: "Endereço $i",
            acceptedWasteTypes: const <WasteType>{WasteType.batteries},
            hours: "8h",
            latitude: null,
            longitude: null,
            status: SuggestionStatus.pending,
            createdAt: DateTime.now(),
          ),
        );
      }

      expect(await repo.pendingCount(), kMaxQueuedSuggestions);
    });

    test("PointReviewsRepository limita a fila offline em no máximo kMaxQueuedReviews (100)", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final PointReviewsRepository repo = PointReviewsRepository(
        localStore: store,
        sender: null,
      );

      for (int i = 0; i < 105; i++) {
        await repo.submitReview(
          PointReview(
            id: "rev_$i",
            pointId: "pt_test",
            rating: 5,
            tags: const <String>[],
            createdAt: DateTime.now(),
          ),
        );
      }

      expect(await repo.pendingCount(), kMaxQueuedReviews);
    });

    test("Rate limiting bloqueia rajada abaixo de minSubmissionInterval", () async {
      DateTime fakeTime = DateTime(2026, 11, 24, 12, 0, 0);
      final InMemoryLocalStore store = InMemoryLocalStore();
      final List<PointSuggestion> sentList = <PointSuggestion>[];

      final PointSuggestionsRepository repo = PointSuggestionsRepository(
        localStore: store,
        minSubmissionInterval: const Duration(seconds: 3),
        clock: () => fakeTime,
        sender: (PointSuggestion s) async => sentList.add(s),
      );

      final PointSuggestion item1 = PointSuggestion(
        id: "r1",
        name: "Primeiro",
        address: "Rua 1",
        acceptedWasteTypes: const <WasteType>{WasteType.glass},
        hours: "Comercial",
        latitude: null,
        longitude: null,
        status: SuggestionStatus.pending,
        createdAt: fakeTime,
      );

      final SuggestionSubmitResult res1 = await repo.submit(item1);
      expect(res1, SuggestionSubmitResult.sent);
      expect(sentList, hasLength(1));

      // Segundo envio imediato (mesmo segundo): bloqueado para evitar flood
      final SuggestionSubmitResult res2 = await repo.submit(item1);
      expect(res2, SuggestionSubmitResult.queuedOffline);
      expect(sentList, hasLength(1)); // Não enviou remotamente

      // Avança o relógio além do intervalo de 3s
      fakeTime = fakeTime.add(const Duration(seconds: 4));
      final SuggestionSubmitResult res3 = await repo.submit(item1);
      expect(res3, SuggestionSubmitResult.sent);
      expect(sentList, hasLength(2));
    });
  });
}
