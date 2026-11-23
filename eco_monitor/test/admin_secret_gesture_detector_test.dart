import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/widgets/admin_secret_gesture_detector.dart";


// Testes ------------------------------------------------------------------ //


void main() {
  testWidgets("single tap does not trigger admin callback", (
    WidgetTester tester,
  ) async {
    bool triggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSecretGestureDetector(
            holdDuration: const Duration(seconds: 3),
            onTrigger: () => triggered = true,
            child: const SizedBox(width: 60, height: 60, key: Key("logo")),
          ),
        ),
      ),
    );

    final Offset center = tester.getCenter(find.byKey(const Key("logo")));
    final TestGesture gesture = await tester.startGesture(center);
    await gesture.up();

    await tester.pump(const Duration(seconds: 4));
    expect(triggered, isFalse);
  });

  testWidgets("double tap released before 3 seconds does not trigger", (
    WidgetTester tester,
  ) async {
    bool triggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSecretGestureDetector(
            holdDuration: const Duration(seconds: 3),
            onTrigger: () => triggered = true,
            child: const SizedBox(width: 60, height: 60, key: Key("logo")),
          ),
        ),
      ),
    );

    final Offset center = tester.getCenter(find.byKey(const Key("logo")));

    // 1º toque
    final TestGesture gesture = await tester.startGesture(center);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));

    // 2º toque mantido por apenas 1.5s
    await gesture.down(center);
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.up();

    await tester.pump(const Duration(seconds: 2));
    expect(triggered, isFalse);
  });

  testWidgets("double tap held continuously for 3 seconds triggers callback", (
    WidgetTester tester,
  ) async {
    bool triggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSecretGestureDetector(
            holdDuration: const Duration(seconds: 3),
            onTrigger: () => triggered = true,
            child: const SizedBox(width: 60, height: 60, key: Key("logo")),
          ),
        ),
      ),
    );

    final Offset center = tester.getCenter(find.byKey(const Key("logo")));

    // 1º toque
    final TestGesture gesture = await tester.startGesture(center);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 150));

    // 2º toque
    await gesture.down(center);
    await tester.pump(const Duration(seconds: 2));
    expect(triggered, isFalse);

    // Completa os 3 segundos
    await tester.pump(const Duration(seconds: 1));
    expect(triggered, isTrue);

    await gesture.up();
  });

  testWidgets("double tap after timeout expiration treats as new first tap", (
    WidgetTester tester,
  ) async {
    bool triggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminSecretGestureDetector(
            holdDuration: const Duration(seconds: 3),
            doubleTapTimeout: const Duration(milliseconds: 400),
            onTrigger: () => triggered = true,
            child: const SizedBox(width: 60, height: 60, key: Key("logo")),
          ),
        ),
      ),
    );

    final Offset center = tester.getCenter(find.byKey(const Key("logo")));

    // 1º toque
    final TestGesture gesture = await tester.startGesture(center);
    await gesture.up();

    // Espera mais que o timeout de 400ms
    await tester.pump(const Duration(milliseconds: 500));

    // Novo toque (age como 1º toque de um novo ciclo)
    await gesture.down(center);
    await tester.pump(const Duration(seconds: 3));
    await gesture.up();

    expect(triggered, isFalse);
  });
}
