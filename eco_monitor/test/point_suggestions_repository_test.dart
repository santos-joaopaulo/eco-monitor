import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/point_suggestion.dart";


// Helpers ------------------------------------------------------------------ //


PointSuggestion testSuggestion(String name) {
  return PointSuggestion(
    id: "",
    name: name,
    address: "Rua de Teste, 123 — Aracaju",
    acceptedWasteTypes: const {WasteType.medicines},
    hours: "Seg a sex, 8h às 18h",
    latitude: -10.95,
    longitude: -37.06,
    status: SuggestionStatus.pending,
    createdAt: DateTime.utc(2026, 11, 17, 10),
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test("submit delivers directly when remote sender succeeds", () async {
    final List<PointSuggestion> sent = <PointSuggestion>[];
    final PointSuggestionsRepository repository = PointSuggestionsRepository(
      sender: (PointSuggestion suggestion) async {
        sent.add(suggestion);
      },
    );

    final SuggestionSubmitResult result = await repository.submit(
      testSuggestion("Farmácia Central"),
    );

    expect(result, SuggestionSubmitResult.sent);
    expect(sent, hasLength(1));
    expect(await repository.pendingCount(), 0);
  });

  test(
    "submit queues offline when sender fails and flushes on retry",
    () async {
      bool shouldFail = true;
      final List<String> deliveredNames = <String>[];

      final PointSuggestionsRepository repository = PointSuggestionsRepository(
        sender: (PointSuggestion suggestion) async {
          if (shouldFail) {
            throw Exception("offline");
          }
          deliveredNames.add(suggestion.name);
        },
      );

      final SuggestionSubmitResult first = await repository.submit(
        testSuggestion("Ponto 1"),
      );
      final SuggestionSubmitResult second = await repository.submit(
        testSuggestion("Ponto 2"),
      );

      expect(first, SuggestionSubmitResult.queuedOffline);
      expect(second, SuggestionSubmitResult.queuedOffline);
      expect(await repository.pendingCount(), 2);

      shouldFail = false;
      final int flushed = await repository.flushPending();

      expect(flushed, 2);
      expect(deliveredNames, ["Ponto 1", "Ponto 2"]);
      expect(await repository.pendingCount(), 0);
    },
  );

  test("flushPending retains items that still fail", () async {
    final PointSuggestionsRepository offlineRepo = PointSuggestionsRepository();
    await offlineRepo.submit(testSuggestion("OK"));
    await offlineRepo.submit(testSuggestion("FAIL"));

    final PointSuggestionsRepository retryRepo = PointSuggestionsRepository(
      sender: (PointSuggestion suggestion) async {
        if (suggestion.name == "FAIL") {
          throw Exception("still failing");
        }
      },
    );

    final int flushed = await retryRepo.flushPending();
    final List<PointSuggestion> remaining = await retryRepo.loadPending();

    expect(flushed, 1);
    expect(remaining, hasLength(1));
    expect(remaining.single.name, "FAIL");
  });

  test("submit queues items in versioned envelope {version, items}", () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final PointSuggestionsRepository repository = PointSuggestionsRepository(
      localStore: store,
    );

    await repository.submit(testSuggestion("Farmácia A"));

    final String? raw = await store.getString("pending_point_suggestions_json");
    expect(raw, isNotNull);

    final Map<String, dynamic> decoded =
        jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded["version"], 1);
    expect(decoded["items"], isList);
    expect((decoded["items"] as List).length, 1);
  });

  test("reads legacy raw list format with backwards compatibility", () async {
    final InMemoryLocalStore store = InMemoryLocalStore(<String, Object>{
      "pending_point_suggestions_json": jsonEncode(<Map<String, dynamic>>[
        testSuggestion("Legado 1").toJson(),
        testSuggestion("Legado 2").toJson(),
      ]),
    });

    final PointSuggestionsRepository repository = PointSuggestionsRepository(
      localStore: store,
    );

    final List<PointSuggestion> pending = await repository.loadPending();
    expect(pending, hasLength(2));
    expect(pending.map((PointSuggestion item) => item.name).toList(), [
      "Legado 1",
      "Legado 2",
    ]);
  });

  test("handles corrupted JSON gracefully without crashing", () async {
    final InMemoryLocalStore store = InMemoryLocalStore(<String, Object>{
      "pending_point_suggestions_json": "{not_valid_json...",
    });

    final PointSuggestionsRepository repository = PointSuggestionsRepository(
      localStore: store,
    );

    final List<PointSuggestion> pending = await repository.loadPending();
    expect(pending, isEmpty);
    expect(await repository.pendingCount(), 0);
  });

  test("concurrent submit calls preserve all suggestions without lost updates", () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final PointSuggestionsRepository repository = PointSuggestionsRepository(
      localStore: store,
    );

    // Dispara múltiplos submits concorrentemente
    await Future.wait(<Future<SuggestionSubmitResult>>[
      repository.submit(testSuggestion("Concorrente 1")),
      repository.submit(testSuggestion("Concorrente 2")),
      repository.submit(testSuggestion("Concorrente 3")),
    ]);

    expect(await repository.pendingCount(), 3);
    final List<PointSuggestion> pending = await repository.loadPending();
    final List<String> names =
        pending.map((PointSuggestion item) => item.name).toList();
    expect(names, containsAll(<String>[
      "Concorrente 1",
      "Concorrente 2",
      "Concorrente 3",
    ]));
  });

  test("concurrent flushPending does not duplicate or drop deliveries", () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final List<String> delivered = <String>[];

    final PointSuggestionsRepository queueRepo = PointSuggestionsRepository(
      localStore: store,
    );
    await queueRepo.submit(testSuggestion("Item 1"));
    await queueRepo.submit(testSuggestion("Item 2"));
    await queueRepo.submit(testSuggestion("Item 3"));

    final PointSuggestionsRepository flushRepo = PointSuggestionsRepository(
      localStore: store,
      sender: (PointSuggestion suggestion) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        delivered.add(suggestion.name);
      },
    );

    // Dispara duas operações flush simultaneamente
    final List<int> results = await Future.wait(<Future<int>>[
      flushRepo.flushPending(),
      flushRepo.flushPending(),
    ]);

    final int totalDeliveredCount =
        results.fold(0, (int sum, int count) => sum + count);
    expect(totalDeliveredCount, 3);
    expect(delivered, hasLength(3));
    expect(await flushRepo.pendingCount(), 0);
  });

  test("clearPending empties the queue completely", () async {
    final InMemoryLocalStore store = InMemoryLocalStore();
    final PointSuggestionsRepository repository = PointSuggestionsRepository(
      localStore: store,
    );

    await repository.submit(testSuggestion("Para Limpar"));
    expect(await repository.pendingCount(), 1);

    await repository.clearPending();
    expect(await repository.pendingCount(), 0);
    expect(await repository.loadPending(), isEmpty);
  });
}
