import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/widgets/location_notice.dart";


// Helpers ------------------------------------------------------------------ //


Future<void> pumpNotice(WidgetTester tester, Widget notice) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: notice)),
    ),
  );
}


// Tests -------------------------------------------------------------------- //


void main() {
  testWidgets("notification shows the message and the action", (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await pumpNotice(
      tester,
      LocationNotice(
        message: "Permita o acesso à localização para ver sua posição.",
        actionLabel: "Permitir",
        onAction: () => tapped = true,
      ),
    );

    expect(
      find.text("Permita o acesso à localização para ver sua posição."),
      findsOneWidget,
    );
    expect(find.text("Permitir"), findsOneWidget);

    await tester.tap(find.text("Permitir"));

    expect(tapped, isTrue);
  });

  testWidgets("notification shows a spinner while locating", (
    WidgetTester tester,
  ) async {
    await pumpNotice(
      tester,
      const LocationNotice(
        message: "Obtendo sua localização...",
        isLoading: true,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text("Obtendo sua localização..."), findsOneWidget);
  });
}
