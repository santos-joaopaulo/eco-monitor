import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/models/collection_point.dart";
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
}
