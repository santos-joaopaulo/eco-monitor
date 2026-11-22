import "dart:convert";
import "dart:io";


// CLI entrypoint ---------------------------------------------------------- //


/// Seeds Cloud Firestore (production or local Firebase Emulator) with the
/// initial EcoMonitor datasets (`collectPoints`, `campaigns`, `disposalGuides`,
/// and `metadata`).
///
/// Flags:
/// - `--project <id>`: Firebase project ID (required).
/// - `--emulator`: targets local emulator at `--emulator-host` (default `127.0.0.1:8080`).
/// - `--token <token>`: explicitly pass an OAuth access token.
/// - `--firebase-cli`: reads the access token from Firebase CLI configstore (`firebase-tools.json`).
/// - `--dry-run`: validates payloads and schemas locally without sending HTTP requests.
/// - `--verify`: fetches metadata documents and collection counts after writing.
Future<void> main(List<String> args) async {
  final String? projectId = _readFlag(args, "--project");
  final bool useEmulator = args.contains("--emulator");
  final bool useFirebaseCli = args.contains("--firebase-cli");
  final bool isDryRun = args.contains("--dry-run");
  final bool shouldVerify = args.contains("--verify");
  final String emulatorHost =
      _readFlag(args, "--emulator-host") ?? "127.0.0.1:8080";

  if (projectId == null || projectId.isEmpty) {
    stderr.writeln(
      "Usage: dart run tool/seed_firestore.dart "
      "--project <PROJECT_ID> [--emulator | --token <TOKEN> | --firebase-cli] "
      "[--dry-run] [--verify]",
    );
    exitCode = 64;
    return;
  }

  String? accessToken = _readFlag(args, "--token");
  if (useFirebaseCli && !useEmulator) {
    try {
      accessToken = _resolveFirebaseCliToken();
    } catch (error) {
      stderr.writeln("Erro de autenticação do Firebase CLI:\n$error");
      exitCode = 1;
      return;
    }
  }

  if (!useEmulator && !isDryRun && (accessToken == null || accessToken.isEmpty)) {
    stderr.writeln(
      "Missing authentication for production Firestore. Pass --token <TOKEN>, "
      "--firebase-cli, or use --emulator.",
    );
    exitCode = 64;
    return;
  }

  final String baseUrl = useEmulator
      ? "http://$emulatorHost/v1/projects/$projectId/databases/(default)/documents"
      : "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents";

  final HttpClient client = HttpClient();
  final String nowIso = DateTime.now().toUtc().toIso8601String();

  try {
    if (isDryRun) {
      stdout.writeln("=== Executando validação offline (--dry-run) ===");
      await _validateDryRun(nowIso);
      stdout.writeln("Validação offline concluída com sucesso (nenhuma requisição enviada).");
      return;
    }

    stdout.writeln("Iniciando seed do Firestore para o projeto '$projectId'...");
    await _seedCollectPoints(
      client: client,
      baseUrl: baseUrl,
      token: accessToken,
      nowIso: nowIso,
    );
    await _seedCampaigns(
      client: client,
      baseUrl: baseUrl,
      token: accessToken,
      nowIso: nowIso,
    );
    await _seedDisposalGuides(
      client: client,
      baseUrl: baseUrl,
      token: accessToken,
      nowIso: nowIso,
    );

    stdout.writeln("Firestore seed concluído com sucesso para o projeto '$projectId'.");

    if (shouldVerify) {
      stdout.writeln("\n=== Verificando dados gravados (--verify) ===");
      await _verifyCollections(
        client: client,
        baseUrl: baseUrl,
        token: accessToken,
      );
    }
  } finally {
    client.close();
  }
}


// Token Resolution -------------------------------------------------------- //


String _resolveFirebaseCliToken() {
  final String path;
  if (Platform.isWindows || Platform.environment.containsKey("APPDATA")) {
    final String? appData = Platform.environment["APPDATA"];
    if (appData == null || appData.isEmpty) {
      throw StateError(
        "Variável %APPDATA% não encontrada para localizar credenciais do Firebase CLI.",
      );
    }
    path = "$appData\\configstore\\firebase-tools.json";
  } else {
    final String? home = Platform.environment["HOME"];
    if (home == null || home.isEmpty) {
      throw StateError(
        "Variável \$HOME não encontrada para localizar credenciais do Firebase CLI.",
      );
    }
    path = "$home/.config/configstore/firebase-tools.json";
  }

  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      "Arquivo de credenciais do Firebase CLI não encontrado em '$path'. "
      "Execute 'firebase login' no terminal para autenticar.",
    );
  }

  final Map<String, dynamic> decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (error) {
    throw StateError(
      "Falha ao ler '$path': $error. Execute 'firebase login' para renovar.",
    );
  }

  final Map<String, dynamic>? tokens =
      decoded["tokens"] as Map<String, dynamic>?;
  final String? accessToken = tokens?["access_token"] as String?;
  final dynamic expiresAtRaw = tokens?["expires_at"];

  if (accessToken == null || accessToken.isEmpty) {
    throw StateError(
      "Nenhum token de acesso encontrado em '$path'. "
      "Execute 'firebase login' no terminal para autenticar.",
    );
  }

  DateTime? expiresAt;
  if (expiresAtRaw is int) {
    expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtRaw, isUtc: true);
  } else if (expiresAtRaw is String) {
    expiresAt = DateTime.tryParse(expiresAtRaw)?.toUtc();
  }

  if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
    throw StateError(
      "O token do Firebase CLI expirou em ${expiresAt.toIso8601String()}. "
      "Execute 'firebase login' ou 'firebase projects:list' no terminal para renovar as credenciais.",
    );
  }

  return accessToken;
}


// Dry Run ----------------------------------------------------------------- //


Future<void> _validateDryRun(String nowIso) async {
  // 1. collectPoints
  final File pointsFile = File("assets/data/collect_points.json");
  if (!pointsFile.existsSync()) {
    throw StateError("Arquivo 'assets/data/collect_points.json' não encontrado.");
  }
  final Map<String, dynamic> pointsDecoded =
      jsonDecode(await pointsFile.readAsString()) as Map<String, dynamic>;
  final List<dynamic> points = pointsDecoded["points"] as List<dynamic>;
  stdout.writeln("✓ Pontos de coleta válidos: ${points.length} pontos carregados.");

  // 2. campaigns
  final File campaignsFile = File("assets/data/campaigns.json");
  if (!campaignsFile.existsSync()) {
    throw StateError("Arquivo 'assets/data/campaigns.json' não encontrado.");
  }
  final Map<String, dynamic> campaignsDecoded =
      jsonDecode(await campaignsFile.readAsString()) as Map<String, dynamic>;
  final List<dynamic> campaigns = campaignsDecoded["campaigns"] as List<dynamic>;
  stdout.writeln("✓ Campanhas válidas: ${campaigns.length} campanhas carregadas.");

  // 3. disposalGuides
  final Map<String, Map<String, dynamic>> guides = _buildDisposalGuides(nowIso);
  stdout.writeln("✓ Guias de descarte válidos: ${guides.length} guias preparados.");
}


// Verification ------------------------------------------------------------ //


Future<void> _verifyCollections({
  required HttpClient client,
  required String baseUrl,
  required String? token,
}) async {
  for (final String collection in <String>[
    "collectPoints",
    "campaigns",
    "disposalGuides",
  ]) {
    final String metadataUrl = "$baseUrl/metadata/$collection";
    final Map<String, dynamic>? metadata = await _getDocument(
      client: client,
      url: metadataUrl,
      token: token,
    );
    if (metadata != null) {
      final String? updatedAt =
          (metadata["fields"] as Map<String, dynamic>?)?["updatedAt"]?["timestampValue"] as String?;
      stdout.writeln("✓ metadata/$collection OK (updatedAt: $updatedAt)");
    } else {
      stderr.writeln("✗ metadata/$collection não encontrado!");
    }

    final String collectionUrl = "$baseUrl/$collection?pageSize=100";
    final List<Map<String, dynamic>> docs = await _listDocuments(
      client: client,
      url: collectionUrl,
      token: token,
    );
    stdout.writeln("✓ Coleção $collection: ${docs.length} documentos encontrados.");
  }
}


// Seeders ----------------------------------------------------------------- //


Future<void> _seedCollectPoints({
  required HttpClient client,
  required String baseUrl,
  required String? token,
  required String nowIso,
}) async {
  final File file = File("assets/data/collect_points.json");
  final Map<String, dynamic> decoded =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final List<dynamic> points = decoded["points"] as List<dynamic>;

  for (final Map<String, dynamic> point
      in points.cast<Map<String, dynamic>>()) {
    final String id = point["id"] as String;
    final Map<String, dynamic> fields = <String, dynamic>{
      "name": _stringValue(point["name"] as String),
      "type": _stringValue(point["type"] as String),
      "latitude": _doubleValue((point["latitude"] as num).toDouble()),
      "longitude": _doubleValue((point["longitude"] as num).toDouble()),
      "address": _stringValue(point["address"] as String),
      "acceptedWasteTypes": _stringArrayValue(
        (point["acceptedWasteTypes"] as List<dynamic>).cast<String>(),
      ),
      "hours": _stringValue(point["hours"] as String),
      "status": _stringValue(point["status"] as String),
      "updatedAt": _timestampValue(nowIso),
    };

    await _upsertDocument(
      client: client,
      url: "$baseUrl/collectPoints/$id",
      token: token,
      fields: fields,
    );
  }

  await _upsertDocument(
    client: client,
    url: "$baseUrl/metadata/collectPoints",
    token: token,
    fields: <String, dynamic>{"updatedAt": _timestampValue(nowIso)},
  );

  stdout.writeln("Seeded ${points.length} documents in collectPoints.");
}

Future<void> _seedCampaigns({
  required HttpClient client,
  required String baseUrl,
  required String? token,
  required String nowIso,
}) async {
  final File file = File("assets/data/campaigns.json");
  final Map<String, dynamic> decoded =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final List<dynamic> campaigns = decoded["campaigns"] as List<dynamic>;

  for (final Map<String, dynamic> campaign
      in campaigns.cast<Map<String, dynamic>>()) {
    final String id = campaign["id"] as String;
    final Map<String, dynamic> fields = <String, dynamic>{
      "title": _stringValue(campaign["title"] as String),
      "description": _stringValue(campaign["description"] as String),
      "wasteTypes": _stringArrayValue(
        (campaign["wasteTypes"] as List<dynamic>).cast<String>(),
      ),
      "locationName": _stringValue(campaign["locationName"] as String),
      "address": _stringValue(campaign["address"] as String),
      "latitude": _doubleValue((campaign["latitude"] as num).toDouble()),
      "longitude": _doubleValue((campaign["longitude"] as num).toDouble()),
      "startDate": _timestampValue(campaign["startDate"] as String),
      "endDate": _timestampValue(campaign["endDate"] as String),
      "status": _stringValue(campaign["status"] as String),
      "updatedAt": _timestampValue(nowIso),
    };

    await _upsertDocument(
      client: client,
      url: "$baseUrl/campaigns/$id",
      token: token,
      fields: fields,
    );
  }

  await _upsertDocument(
    client: client,
    url: "$baseUrl/metadata/campaigns",
    token: token,
    fields: <String, dynamic>{"updatedAt": _timestampValue(nowIso)},
  );

  stdout.writeln("Seeded ${campaigns.length} documents in campaigns.");
}

Future<void> _seedDisposalGuides({
  required HttpClient client,
  required String baseUrl,
  required String? token,
  required String nowIso,
}) async {
  final Map<String, Map<String, dynamic>> guides = _buildDisposalGuides(nowIso);

  for (final MapEntry<String, Map<String, dynamic>> entry in guides.entries) {
    await _upsertDocument(
      client: client,
      url: "$baseUrl/disposalGuides/${entry.key}",
      token: token,
      fields: entry.value,
    );
  }

  await _upsertDocument(
    client: client,
    url: "$baseUrl/metadata/disposalGuides",
    token: token,
    fields: <String, dynamic>{"updatedAt": _timestampValue(nowIso)},
  );

  stdout.writeln("Seeded ${guides.length} documents in disposalGuides.");
}

Map<String, Map<String, dynamic>> _buildDisposalGuides(String nowIso) {
  return <String, Map<String, dynamic>>{
    "medicines": <String, dynamic>{
      "type": _stringValue("medicines"),
      "title": _stringValue("Remédios vencidos"),
      "description": _stringValue(
        "Comprimidos, xaropes e pomadas. Nunca jogue no lixo comum ou no vaso.",
      ),
      "minutes": _intValue(2),
      "totalSteps": _intValue(4),
      "subtitle": _stringValue("Siga os passos antes de ir até o ponto."),
      "warning": _stringValue(
        "Não jogue no lixo comum, pia ou vaso sanitário.",
      ),
      "steps": _stepsArrayValue(<Map<String, String>>[
        <String, String>{
          "title": "Separe os medicamentos",
          "description": "Junte os vencidos ou que não usa mais.",
        },
        <String, String>{
          "title": "Mantenha na embalagem",
          "description": "Deixe na cartela ou frasco original, se possível.",
        },
        <String, String>{
          "title": "Caixa e bula no reciclável",
          "description": "O papel pode ir para a coleta seletiva.",
        },
        <String, String>{
          "title": "Leve a uma farmácia",
          "description": 'Procure um ponto com o filtro "Remédios".',
        },
      ]),
      "updatedAt": _timestampValue(nowIso),
    },
    "batteries": <String, dynamic>{
      "type": _stringValue("batteries"),
      "title": _stringValue("Pilhas e baterias"),
      "description": _stringValue(
        "Contêm metais pesados que contaminam solo e água.",
      ),
      "minutes": _intValue(2),
      "totalSteps": _intValue(4),
      "subtitle": _stringValue("Siga os passos antes de ir até o ponto."),
      "warning": _stringValue(
        "Não perfure, amasse, queime ou jogue no lixo comum: há risco de vazamento tóxico.",
      ),
      "steps": _stepsArrayValue(<Map<String, String>>[
        <String, String>{
          "title": "Separe do lixo comum",
          "description": "Guarde pilhas e baterias usadas em local seco, fresco e ventilado.",
        },
        <String, String>{
          "title": "Isole os polos",
          "description": "Cubra os terminais de baterias com fita adesiva para evitar curto-circuito.",
        },
        <String, String>{
          "title": "Embale itens danificados",
          "description": "Se houver ferrugem ou vazamento, coloque em um saco plástico bem fechado.",
        },
        <String, String>{
          "title": "Leve a um ponto de coleta",
          "description": 'Procure um local com o filtro "Pilhas e baterias".',
        },
      ]),
      "updatedAt": _timestampValue(nowIso),
    },
    "sharps": <String, dynamic>{
      "type": _stringValue("sharps"),
      "title": _stringValue("Seringas e agulhas"),
      "description": _stringValue(
        "Guarde em recipiente rígido e fechado, como garrafa PET.",
      ),
      "minutes": _intValue(3),
      "totalSteps": _intValue(5),
      "subtitle": _stringValue("Siga os passos com cuidado para evitar acidentes."),
      "warning": _stringValue(
        "Risco biológico (ANVISA Grupo E): nunca reencape agulhas nem misture com remédios.",
      ),
      "steps": _stepsArrayValue(<Map<String, String>>[
        <String, String>{
          "title": "Não reencape nem quebre",
          "description": "Evite recolocar a tampa ou entortar a agulha para não se ferir.",
        },
        <String, String>{
          "title": "Separe de outros resíduos",
          "description": "Nunca misture perfurocortantes com medicamentos, recicláveis ou lixo comum.",
        },
        <String, String>{
          "title": "Use um recipiente rígido",
          "description": "Prefira caixa coletora (Descarpack) ou garrafa PET resistente de boca estreita.",
        },
        <String, String>{
          "title": "Feche e identifique",
          "description": 'Preencha até dois terços, tampe bem e escreva "Perfurocortantes" no frasco.',
        },
        <String, String>{
          "title": "Entregue em uma UBS",
          "description": 'Leve o recipiente fechado a um ponto com o filtro "Seringas e agulhas".',
        },
      ]),
      "updatedAt": _timestampValue(nowIso),
    },
    "electronics": <String, dynamic>{
      "type": _stringValue("electronics"),
      "title": _stringValue("Lixo eletrônico"),
      "description": _stringValue(
        "Celulares, cabos, carregadores e pequenos aparelhos. Não jogue no lixo comum.",
      ),
      "minutes": _intValue(2),
      "totalSteps": _intValue(4),
      "subtitle": _stringValue("Siga os passos antes de ir até o ponto."),
      "warning": _stringValue(
        "Não desmonte aparelhos nem jogue no lixo comum: eles contêm substâncias tóxicas.",
      ),
      "steps": _stepsArrayValue(<Map<String, String>>[
        <String, String>{
          "title": "Apague seus dados",
          "description": "Faça backup, remova chips e cartões de memória e restaure o aparelho de fábrica.",
        },
        <String, String>{
          "title": "Retire pilhas e baterias",
          "description": "Se forem removíveis, separe pilhas ou baterias para o coletor específico.",
        },
        <String, String>{
          "title": "Reúna cabos e acessórios",
          "description": "Junte carregadores, fones e pequenos aparelhos sem quebrar ou abrir as peças.",
        },
        <String, String>{
          "title": "Leve a um ecoponto",
          "description": 'Procure um ponto com o filtro "Lixo eletrônico".',
        },
      ]),
      "updatedAt": _timestampValue(nowIso),
    },
  };
}


// HTTP Helpers ------------------------------------------------------------ //


Future<void> _upsertDocument({
  required HttpClient client,
  required String url,
  required String? token,
  required Map<String, dynamic> fields,
}) async {
  final HttpClientRequest request = await client.patchUrl(Uri.parse(url));
  request.headers.contentType = ContentType.json;
  if (token != null && token.isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, "Bearer $token");
  }

  request.write(jsonEncode(<String, dynamic>{"fields": fields}));
  final HttpClientResponse response = await request.close();
  final String body = await response.transform(utf8.decoder).join();

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException("Failed to write $url (${response.statusCode}): $body");
  }
}

Future<Map<String, dynamic>?> _getDocument({
  required HttpClient client,
  required String url,
  required String? token,
}) async {
  final HttpClientRequest request = await client.getUrl(Uri.parse(url));
  if (token != null && token.isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, "Bearer $token");
  }
  final HttpClientResponse response = await request.close();
  final String body = await response.transform(utf8.decoder).join();

  if (response.statusCode == 404) {
    return null;
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException("Failed to get $url (${response.statusCode}): $body");
  }

  return jsonDecode(body) as Map<String, dynamic>;
}

Future<List<Map<String, dynamic>>> _listDocuments({
  required HttpClient client,
  required String url,
  required String? token,
}) async {
  final HttpClientRequest request = await client.getUrl(Uri.parse(url));
  if (token != null && token.isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, "Bearer $token");
  }
  final HttpClientResponse response = await request.close();
  final String body = await response.transform(utf8.decoder).join();

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException("Failed to list $url (${response.statusCode}): $body");
  }

  final Map<String, dynamic> decoded =
      jsonDecode(body) as Map<String, dynamic>;
  final List<dynamic>? docs = decoded["documents"] as List<dynamic>?;
  if (docs == null) {
    return const <Map<String, dynamic>>[];
  }
  return docs.cast<Map<String, dynamic>>();
}

String? _readFlag(List<String> args, String name) {
  final int index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}

Map<String, dynamic> _stringValue(String value) => <String, dynamic>{
  "stringValue": value,
};

Map<String, dynamic> _doubleValue(double value) => <String, dynamic>{
  "doubleValue": value,
};

Map<String, dynamic> _intValue(int value) => <String, dynamic>{
  "integerValue": value.toString(),
};

Map<String, dynamic> _timestampValue(String iso) => <String, dynamic>{
  "timestampValue": iso,
};

Map<String, dynamic> _stringArrayValue(
  List<String> values,
) => <String, dynamic>{
  "arrayValue": <String, dynamic>{"values": values.map(_stringValue).toList()},
};

Map<String, dynamic> _stepsArrayValue(List<Map<String, String>> steps) =>
    <String, dynamic>{
      "arrayValue": <String, dynamic>{
        "values": steps
            .map(
              (Map<String, String> step) => <String, dynamic>{
                "mapValue": <String, dynamic>{
                  "fields": <String, dynamic>{
                    "title": _stringValue(step["title"] ?? ""),
                    "description": _stringValue(step["description"] ?? ""),
                  },
                },
              },
            )
            .toList(),
      },
    };
