import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/widgets/home_map_top_bar.dart";
import "package:eco_monitor/widgets/offline_banner.dart";

void main() {
  testWidgets("renders nothing when online, fresh, and no pending queue", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OfflineBanner(isOffline: false, isStale: false)),
      ),
    );

    expect(find.byType(Material), findsOneWidget); // Apenas o Material do Scaffold.
    expect(find.textContaining("Sem conexão"), findsNothing);
    expect(find.textContaining("desatualizados"), findsNothing);
  });

  testWidgets("shows offline message with pending count when disconnected", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OfflineBanner(
            isOffline: true,
            isStale: true,
            pendingSuggestionsCount: 2,
          ),
        ),
      ),
    );

    expect(
      find.text("Sem conexão · Dados salvos (+2)"),
      findsOneWidget,
    );
  });

  testWidgets("shows stale warning with retry button when online and stale", (
    WidgetTester tester,
  ) async {
    bool retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineBanner(
            isOffline: false,
            isStale: true,
            lastUpdated: DateTime.utc(2026, 11, 1, 12),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(
      find.textContaining("Dados desatualizados"),
      findsOneWidget,
    );
    await tester.tap(find.text("Atualizar"));
    expect(retried, isTrue);
  });

  testWidgets("renders floating inside HomeMapTopBar without extra background", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: HomeMapTopBar(
            selectedWasteTypes: const {},
            onFilterChanged: (_) {},
            showMapboxTokenWarning: false,
            isLoadingPoints: false,
            isEmptyResult: false,
            emptyMessage: "",
            locationNotice: null,
            isListMode: false,
            offlineBanner: const OfflineBanner(
              isOffline: true,
              isStale: false,
              pendingSuggestionsCount: 3,
              padding: EdgeInsets.only(bottom: 6),
            ),
          ),
        ),
      ),
    );

    expect(find.text("Sem conexão · Dados salvos (+3)"), findsOneWidget);
  });
}
