import "package:material_ui/material_ui.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/point_suggestions_repository.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/point_suggestion.dart";
import "package:eco_monitor/screens/suggest_screen.dart";
import "package:eco_monitor/services/location_service.dart";


// Auxiliares -------------------------------------------------------------- //


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


// Testes ------------------------------------------------------------------ //


void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets("renders the hero section and all form fields", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SuggestScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text("Ajude o mapa a crescer 🌱"), findsOneWidget);
    expect(
      find.text(
        "Conheça um local que recebe resíduos? Envie para nossa equipe validar.",
      ),
      findsOneWidget,
    );
    expect(find.text("Nome do estabelecimento"), findsOneWidget);
    expect(find.text("Endereço"), findsOneWidget);
    expect(find.text("Materiais aceitos"), findsOneWidget);
    expect(find.text("Remédios"), findsOneWidget);
    expect(find.text("Pilhas"), findsOneWidget);
    expect(find.text("Seringas"), findsOneWidget);
    expect(find.text("Eletrônicos"), findsOneWidget);
    expect(find.text("Horário de funcionamento"), findsOneWidget);
    expect(find.text("Seg"), findsOneWidget);
    expect(find.text("Sáb"), findsOneWidget);
    expect(find.text("Dom"), findsOneWidget);
    expect(find.text("Replicar horário para todos os dias"), findsOneWidget);
    expect(find.text("Enviar sugestão"), findsOneWidget);
    expect(
      find.text("Envio estritamente anônimo. Nenhum dado pessoal é coletado."),
      findsOneWidget,
    );
  });

  testWidgets("renders without overflow on a compact phone surface", (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SuggestScreen())),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();

    expect(find.text("Enviar sugestão"), findsOneWidget);
    expect(
      find.text("Envio estritamente anônimo. Nenhum dado pessoal é coletado."),
      findsOneWidget,
    );
  });

  testWidgets("validates required fields on submit without input", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SuggestScreen())),
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
        home: Scaffold(body: SuggestScreen(locationService: service)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip("Preencher com localização atual (GPS)"));
    await tester.pumpAndSettle();

    expect(
      find.text("Coordenadas GPS capturadas com sucesso!"),
      findsOneWidget,
    );
    expect(find.textContaining("-10.94720"), findsOneWidget);
    expect(find.textContaining("-37.07310"), findsOneWidget);
  });

  testWidgets("opens the time picker from a schedule pill", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SuggestScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("08:00").first);
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(find.text("Horário de abertura"), findsOneWidget);

    await tester.tap(find.text("Cancelar"));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsNothing);
  });

  testWidgets("submits valid suggestion successfully and resets form", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    final _FakeSuggestionsRepository repository = _FakeSuggestionsRepository(
      result: SuggestionSubmitResult.sent,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SuggestScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      "EcoPonto Jardins",
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      "Av. Ministro Geraldo Barreto Sobral, 100",
    );

    await tester.tap(find.text("Pilhas"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Enviar sugestão"));
    await tester.pumpAndSettle();

    expect(repository.submitted.length, 1);
    final PointSuggestion suggestion = repository.submitted.first;
    expect(suggestion.name, "EcoPonto Jardins");
    expect(suggestion.address, "Av. Ministro Geraldo Barreto Sobral, 100");
    expect(suggestion.acceptedWasteTypes, {WasteType.batteries});
    expect(suggestion.hours, "Seg a Sex: 08:00 às 18:00");

    expect(
      find.text("Sugestão enviada com sucesso! Obrigado por colaborar."),
      findsOneWidget,
    );

    expect(find.text("EcoPonto Jardins"), findsNothing);
  });

  testWidgets("omits closed days from the formatted hours", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    final _FakeSuggestionsRepository repository = _FakeSuggestionsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SuggestScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Fechado"), findsNWidgets(2));

    await tester.tap(find.text("Seg"));
    await tester.pumpAndSettle();

    expect(find.text("Fechado"), findsNWidgets(3));

    await tester.enterText(
      find.byType(TextFormField).at(0),
      "EcoPonto Jardins",
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      "Av. Ministro Geraldo Barreto Sobral, 100",
    );

    await tester.tap(find.text("Remédios"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Enviar sugestão"));
    await tester.pumpAndSettle();

    expect(repository.submitted.single.hours, "Ter a Sex: 08:00 às 18:00");
  });

  testWidgets("replicates the schedule to all days", (
    WidgetTester tester,
  ) async {
    useTallSurface(tester);

    final _FakeSuggestionsRepository repository = _FakeSuggestionsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SuggestScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Replicar horário para todos os dias"));
    await tester.pumpAndSettle();

    expect(find.text("Horário replicado para todos os dias."), findsOneWidget);
    expect(find.text("Fechado"), findsNothing);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      "EcoPonto Jardins",
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      "Av. Ministro Geraldo Barreto Sobral, 100",
    );

    await tester.tap(find.text("Remédios"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Enviar sugestão"));
    await tester.pumpAndSettle();

    expect(repository.submitted.single.hours, "Todos os dias: 08:00 às 18:00");
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
        home: Scaffold(body: SuggestScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      "Farmácia Pague Menos",
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
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
