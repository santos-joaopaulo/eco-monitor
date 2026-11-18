import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/main.dart";

// Tests -------------------------------------------------------------------- //

void main() {
  testWidgets("renders the shell with app bar and four navigation tabs", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text("ECOMONITOR"), findsOneWidget);
    expect(find.text("home"), findsOneWidget);
    expect(find.text("guia"), findsOneWidget);
    expect(find.text("eventos"), findsOneWidget);
    expect(find.text("sugerir"), findsOneWidget);
  });
}
