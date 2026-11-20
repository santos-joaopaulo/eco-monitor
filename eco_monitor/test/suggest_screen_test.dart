import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/models/collection_point.dart";
import "package:eco_monitor/models/point_suggestion.dart";
import "package:eco_monitor/screens/suggest_screen.dart";
import "package:eco_monitor/services/location_service.dart";


// Helpers ------------------------------------------------------------------ //


void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _MockLocationService extends LocationService {
  const _MockLocationService({this.position});

  final UserLocation? position;

  @override
  Future<UserLocation?> currentPosition() async => position;
}

class _FakeSuggestionsRepository extends PointSuggestionsRepository {
  _FakeSuggestionsRepository({this.result = SuggestionSubmitResult.sent});

  final SuggestionSubmitResult result;
  final List<PointSuggestion> submitted = <PointSuggestion>[];

  @override
  Future<SuggestionSubmitResult> submit(PointSuggestion suggestion) async {
    submitted.add(suggestion);
    return result;
  }
}


// Tests -------------------------------------------------------------------- //


void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets("renders anonymous notice and all form fields", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SuggestScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Envio estritamente anônimo"), findsOneWidget);
    expect(
      find.text(
        "Não coletamos nem enviamos nenhum dado pessoal, de conta ou identificador do dispositivo.",
      ),
      findsOneWidget,
    );
    expect(find.text("Nome do local *"), findsOneWidget);
    expect(find.text("Endereço completo *"), findsOneWidget);
    expect(find.text("RESÍDUOS ACEITOS *"), findsOneWidget);
    expect(find.text("Remédios"), findsOneWidget);
    expect(find.text("Pilhas e baterias"), findsOneWidget);
    expect(find.text("Seringas e agulhas"), findsOneWidget);
    expect(find.text("Lixo eletrônico"), findsOneWidget);
    expect(find.text("Horário de funcionamento (opcional)"), findsOneWidget);
    expect(find.text("Enviar sugestão"), findsOneWidget);
  });

  testWidgets("validates required fields on submit without input", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SuggestScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Enviar sugestão"));
    await tester.pumpAndSettle();

    expect(find.text("Informe o nome do local."), findsOneWidget);
    expect(find.text("Informe o endereço do local."), findsOneWidget);
    expect(
      find.text("Selecione ao menos um tipo de resíduo aceito."),
      findsOneWidget,
    );
  });

  testWidgets("captures GPS coordinates when location button is tapped", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    const UserLocation fakeLoc = UserLocation(
      latitude: -10.9472,
      longitude: -37.0731,
    );
    const LocationService service = _MockLocationService(position: fakeLoc);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SuggestScreen(locationService: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Preencher com localização atual (GPS)"));
    await tester.pumpAndSettle();

    expect(find.text("Coordenadas GPS capturadas com sucesso!"), findsOneWidget);
    expect(find.textContaining("-10.94720"), findsOneWidget);
    expect(find.textContaining("-37.07310"), findsOneWidget);
  });

  testWidgets("submits valid suggestion successfully and resets form", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    final _FakeSuggestionsRepository repository =
        _FakeSuggestionsRepository(result: SuggestionSubmitResult.sent);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, "Nome do local *"),
      "EcoPonto Jardins",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "Endereço completo *"),
      "Av. Ministro Geraldo Barreto Sobral, 100",
    );

    await tester.tap(find.text("Pilhas e baterias"));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        "Horário de funcionamento (opcional)",
      ),
      "Seg a Sex, 8h às 17h",
    );

    await tester.tap(find.text("Enviar sugestão"));
    await tester.pumpAndSettle();

    expect(repository.submitted.length, 1);
    final PointSuggestion suggestion = repository.submitted.first;
    expect(suggestion.name, "EcoPonto Jardins");
    expect(
      suggestion.address,
      "Av. Ministro Geraldo Barreto Sobral, 100",
    );
    expect(suggestion.acceptedWasteTypes, {WasteType.batteries});
    expect(suggestion.hours, "Seg a Sex, 8h às 17h");

    expect(
      find.text("Sugestão enviada com sucesso! Obrigado por colaborar."),
      findsOneWidget,
    );

    expect(find.text("EcoPonto Jardins"), findsNothing);
  });

  testWidgets("shows offline queue message when submitted offline", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    final _FakeSuggestionsRepository repository = _FakeSuggestionsRepository(
      result: SuggestionSubmitResult.queuedOffline,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, "Nome do local *"),
      "Farmácia Pague Menos",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, "Endereço completo *"),
      "Rua Laranjeiras, 450 - Centro",
    );

    await tester.tap(find.text("Remédios"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Enviar sugestão"));
    await tester.pumpAndSettle();

    expect(repository.submitted.length, 1);
    expect(
      find.text(
        "Sugestão salva na fila offline. Será enviada assim que houver conexão.",
      ),
      findsOneWidget,
    );
  });
}
