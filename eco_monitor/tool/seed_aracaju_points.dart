import "dart:convert";
import "dart:io";


// Constants ---------------------------------------------------------------- //


const String kDefaultProjectId = "eco-monitor-34290";
const String kCollectPointsCollection = "collectPoints";
const String kLocalAssetPath = "assets/data/collect_points.json";

const Set<String> kAllowedPointTypes = <String>{
  "pharmacy",
  "healthCenter",
  "ecoPoint",
};

const Set<String> kAllowedWasteTypes = <String>{
  "medicines",
  "sharps",
  "batteries",
  "electronics",
};

/// Payload oficial fornecido para os pontos de coleta ecológicos reais de Aracaju-SE.
const Map<String, Map<String, dynamic>> kAracajuCollectPointsPayload =
    <String, Map<String, dynamic>>{
      "pague_menos_centro_aju": <String, dynamic>{
        "name": "Farmácia Pague Menos — Centro",
        "type": "pharmacy",
        "latitude": -10.9116,
        "longitude": -37.0528,
        "address": "Rua Laranjeiras, 238 — Centro, Aracaju - SE",
        "acceptedWasteTypes": <String>["medicines"],
        "hours": "Seg a sex, 6h20 às 19h30; sáb, 6h20 às 16h30",
        "status": "active",
      },
      "drogasil_luzia_aju": <String, dynamic>{
        "name": "Drogasil — Luzia",
        "type": "pharmacy",
        "latitude": -10.9291,
        "longitude": -37.0660,
        "address": "Av. Gonçalo Rolemberg Leite, 1813 — Luzia, Aracaju - SE",
        "acceptedWasteTypes": <String>["medicines"],
        "hours": "Seg a dom, 7h às 23h",
        "status": "active",
      },
      "drogasil_industrial_aju": <String, dynamic>{
        "name": "Drogasil — Industrial",
        "type": "pharmacy",
        "latitude": -10.9029,
        "longitude": -37.0565,
        "address": "Av. Simeão Sobral, 542 — Industrial, Aracaju - SE",
        "acceptedWasteTypes": <String>["medicines", "batteries"],
        "hours": "Seg a dom, 7h às 23h",
        "status": "active",
      },
      "ubs_augusto_franco_aju": <String, dynamic>{
        "name": "UBS Augusto Franco",
        "type": "healthCenter",
        "latitude": -10.9688,
        "longitude": -37.0710,
        "address":
            "Rua José Francisco Prejuízo, 151 — Farolândia, Aracaju - SE",
        "acceptedWasteTypes": <String>["sharps"],
        "hours": "Seg a sex, 7h às 18h30",
        "status": "active",
      },
      "ecoponto_industrial_aju": <String, dynamic>{
        "name": "Ecoponto Industrial — Emsurb",
        "type": "ecoPoint",
        "latitude": -10.8963,
        "longitude": -37.0544,
        "address": "Av. Confiança, 131 — Industrial, Aracaju - SE",
        "acceptedWasteTypes": <String>["electronics"],
        "hours": "Seg a sáb, 7h às 12h e 13h às 17h",
        "status": "active",
      },
      "pev_casas_bahia_joao_pessoa_aju": <String, dynamic>{
        "name": "Casas Bahia — Centro (PEV Green Eletron)",
        "type": "ecoPoint",
        "latitude": -10.9098,
        "longitude": -37.0491,
        "address": "Rua João Pessoa, 320 — Centro, Aracaju - SE",
        "acceptedWasteTypes": <String>["batteries", "electronics"],
        "hours": "Seg a sáb, 8h às 19h",
        "status": "active",
      },
      "pev_shopping_jardins_aju": <String, dynamic>{
        "name": "Shopping Jardins — PEV Green Eletron",
        "type": "ecoPoint",
        "latitude": -10.9423,
        "longitude": -37.0598,
        "address":
            "Av. Ministro Geraldo Barreto Sobral, 215 — Jardins, Aracaju - SE",
        "acceptedWasteTypes": <String>["batteries", "electronics"],
        "hours": "Seg a sáb, 10h às 22h; dom, 12h às 21h",
        "status": "active",
      },
      "pev_atacadao_tancredo_neves_aju": <String, dynamic>{
        "name": "Atacadão Tancredo Neves — PEV Green Eletron",
        "type": "ecoPoint",
        "latitude": -10.9381,
        "longitude": -37.0811,
        "address":
            "Av. Pres. Tancredo Neves, 3550 — Ponto Novo, Aracaju - SE",
        "acceptedWasteTypes": <String>["batteries"],
        "hours": "Seg a dom, 24h",
        "status": "active",
      },
    };


// Validation (RNF17) ------------------------------------------------------ //


/// Valida e normaliza um ponto de coleta de acordo com as regras de esquema do RNF17.
Map<String, dynamic> validateAndNormalizePoint(
  String pointId,
  Map<String, dynamic> raw,
) {
  final String name = raw["name"] as String? ?? "";
  if (name.isEmpty) {
    throw FormatException("Nome do ponto '$pointId' não pode ser vazio.");
  }

  final String rawType = raw["type"] as String? ?? "";
  if (!kAllowedPointTypes.contains(rawType)) {
    throw FormatException(
      "Tipo inválido '$rawType' para '$pointId'. Deve ser um de: $kAllowedPointTypes.",
    );
  }

  final num? latNum = raw["latitude"] as num?;
  final num? lngNum = raw["longitude"] as num?;
  if (latNum == null || lngNum == null) {
    throw FormatException("Coordenadas inválidas para '$pointId'.");
  }

  final String address = raw["address"] as String? ?? "";
  if (address.isEmpty) {
    throw FormatException("Endereço do ponto '$pointId' não pode ser vazio.");
  }

  final List<dynamic> rawWaste =
      raw["acceptedWasteTypes"] as List<dynamic>? ?? <dynamic>[];
  final List<String> wasteList = rawWaste.map((dynamic item) => item.toString()).toList();
  for (final String waste in wasteList) {
    if (!kAllowedWasteTypes.contains(waste)) {
      throw FormatException(
        "Tipo de resíduo inválido '$waste' em '$pointId'. Permitidos: $kAllowedWasteTypes.",
      );
    }
  }

  final String hours = raw["hours"] as String? ?? "";
  if (hours.isEmpty) {
    throw FormatException("Horário de funcionamento não informado para '$pointId'.");
  }

  // RNF17: Qualquer valor desconhecido de status deve cair em "inactive" por segurança.
  final String rawStatus = raw["status"] as String? ?? "";
  final String status = rawStatus == "active" ? "active" : "inactive";

  return <String, dynamic>{
    "id": pointId,
    "name": name,
    "type": rawType,
    "latitude": latNum.toDouble(),
    "longitude": lngNum.toDouble(),
    "address": address,
    "acceptedWasteTypes": wasteList,
    "hours": hours,
    "status": status,
  };
}


// Local Persistence (Offline-First) --------------------------------------- //


/// Executa o upsert idempotente no arquivo local empacotado `assets/data/collect_points.json`.
Future<int> seedLocalDatabase({
  required Map<String, Map<String, dynamic>> payload,
  String assetPath = kLocalAssetPath,
}) async {
  final File file = File(assetPath);
  if (!file.existsSync()) {
    throw StateError("Arquivo local de dados não encontrado em '$assetPath'.");
  }

  final String content = await file.readAsString();
  final Map<String, dynamic> decoded =
      jsonDecode(content) as Map<String, dynamic>;
  final List<dynamic> existingList =
      decoded["points"] as List<dynamic>? ?? <dynamic>[];

  // Indexa os pontos existentes por ID
  final Map<String, Map<String, dynamic>> pointsById =
      <String, Map<String, dynamic>>{};
  for (final dynamic item in existingList) {
    if (item is Map<String, dynamic> && item.containsKey("id")) {
      pointsById[item["id"] as String] = item;
    }
  }

  int upsertCount = 0;
  for (final MapEntry<String, Map<String, dynamic>> entry in payload.entries) {
    final String pointId = entry.key;
    final Map<String, dynamic> normalized = validateAndNormalizePoint(
      pointId,
      entry.value,
    );
    pointsById[pointId] = normalized;
    upsertCount++;
  }

  // Ordena alfabeticamente por nome para consistência
  final List<Map<String, dynamic>> sortedPoints = pointsById.values.toList()
    ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final String nameA = a["name"] as String? ?? "";
      final String nameB = b["name"] as String? ?? "";
      return nameA.toLowerCase().compareTo(nameB.toLowerCase());
    });

  final String nowIso = DateTime.now().toUtc().toIso8601String();
  final Map<String, dynamic> updatedDocument = <String, dynamic>{
    "updatedAt": nowIso,
    "points": sortedPoints,
  };

  const JsonEncoder encoder = JsonEncoder.withIndent("  ");
  await file.writeAsString("${encoder.convert(updatedDocument)}\n");

  return upsertCount;
}


// Firestore WriteBatch ---------------------------------------------------- //


/// Executa a gravação batch atômica no Cloud Firestore usando a operação :commit.
Future<int> seedCloudFirestore({
  required HttpClient client,
  required String projectId,
  required String? token,
  required Map<String, Map<String, dynamic>> payload,
}) async {
  final String commitUrl =
      "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:commit";

  final List<Map<String, dynamic>> writes = <Map<String, dynamic>>[];

  for (final MapEntry<String, Map<String, dynamic>> entry in payload.entries) {
    final String pointId = entry.key;
    final Map<String, dynamic> point = validateAndNormalizePoint(
      pointId,
      entry.value,
    );

    final String docName =
        "projects/$projectId/databases/(default)/documents/$kCollectPointsCollection/$pointId";

    // 1. Operação de atualização com updateMask (merge: true)
    writes.add(<String, dynamic>{
      "update": <String, dynamic>{
        "name": docName,
        "fields": <String, dynamic>{
          "name": <String, dynamic>{"stringValue": point["name"]},
          "type": <String, dynamic>{"stringValue": point["type"]},
          "latitude": <String, dynamic>{"doubleValue": point["latitude"]},
          "longitude": <String, dynamic>{"doubleValue": point["longitude"]},
          "address": <String, dynamic>{"stringValue": point["address"]},
          "acceptedWasteTypes": <String, dynamic>{
            "arrayValue": <String, dynamic>{
              "values": (point["acceptedWasteTypes"] as List<String>)
                  .map((String w) => <String, dynamic>{"stringValue": w})
                  .toList(),
            },
          },
          "hours": <String, dynamic>{"stringValue": point["hours"]},
          "status": <String, dynamic>{"stringValue": point["status"]},
        },
      },
      "updateMask": <String, dynamic>{
        "fieldPaths": <String>[
          "name",
          "type",
          "latitude",
          "longitude",
          "address",
          "acceptedWasteTypes",
          "hours",
          "status",
        ],
      },
    });

    // 2. Transform nativo para atribuir updatedAt = FieldValue.serverTimestamp()
    writes.add(<String, dynamic>{
      "transform": <String, dynamic>{
        "document": docName,
        "fieldTransforms": <dynamic>[
          <String, dynamic>{
            "fieldPath": "updatedAt",
            "setToServerValue": "REQUEST_TIME",
          },
        ],
      },
    });
  }

  // Atualiza metadados globais da coleção metadata/collectPoints
  final String metadataDocName =
      "projects/$projectId/databases/(default)/documents/metadata/$kCollectPointsCollection";

  writes.add(<String, dynamic>{
    "transform": <String, dynamic>{
      "document": metadataDocName,
      "fieldTransforms": <dynamic>[
        <String, dynamic>{
          "fieldPath": "updatedAt",
          "setToServerValue": "REQUEST_TIME",
        },
      ],
    },
  });

  final HttpClientRequest request =
      await client.postUrl(Uri.parse(commitUrl));
  request.headers.contentType = ContentType.json;
  if (token != null && token.isNotEmpty) {
    request.headers.set(HttpHeaders.authorizationHeader, "Bearer $token");
  }

  request.write(jsonEncode(<String, dynamic>{"writes": writes}));
  final HttpClientResponse response = await request.close();
  final String responseBody =
      await response.transform(utf8.decoder).join();

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      "Falha ao executar commit batch no Firestore (${response.statusCode}): $responseBody",
    );
  }

  return payload.length;
}


// Verification ------------------------------------------------------------ //


Future<void> verifyFirestoreDocuments({
  required HttpClient client,
  required String projectId,
  required String? token,
  required Iterable<String> pointIds,
}) async {
  for (final String pointId in pointIds) {
    final String url =
        "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$kCollectPointsCollection/$pointId";
    final HttpClientRequest request = await client.getUrl(Uri.parse(url));
    if (token != null && token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, "Bearer $token");
    }

    final HttpClientResponse response = await request.close();
    final String body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw HttpException(
        "Documento '$pointId' não encontrado no Firestore (${response.statusCode}): $body",
      );
    }

    final Map<String, dynamic> doc =
        jsonDecode(body) as Map<String, dynamic>;
    final Map<String, dynamic>? fields =
        doc["fields"] as Map<String, dynamic>?;
    final String? name = fields?["name"]?["stringValue"] as String?;
    final String? status = fields?["status"]?["stringValue"] as String?;
    final String? updatedAt =
        fields?["updatedAt"]?["timestampValue"] as String?;

    stdout.writeln(
      "  ✓ [$pointId] $name (status: $status, updatedAt: $updatedAt)",
    );
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

  final Map<String, dynamic> decoded =
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final Map<String, dynamic>? tokens =
      decoded["tokens"] as Map<String, dynamic>?;
  final String? accessToken = tokens?["access_token"] as String?;

  if (accessToken == null || accessToken.isEmpty) {
    throw StateError(
      "Nenhum token de acesso encontrado em '$path'. Execute 'firebase login'.",
    );
  }

  return accessToken;
}

String? _readFlag(List<String> args, String name) {
  final int index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}


// Main -------------------------------------------------------------------- //


Future<void> main(List<String> args) async {
  final String projectId =
      _readFlag(args, "--project") ?? kDefaultProjectId;
  final bool dryRun = args.contains("--dry-run");

  stdout.writeln("==================================================");
  stdout.writeln("Seed de Pontos de Coleta (Aracaju-SE)");
  stdout.writeln("Offline-First -> Cloud Firestore");
  stdout.writeln("Projeto: $projectId");
  stdout.writeln("==================================================\n");

  // 1. Validação RNF17 prévia de todos os registros
  stdout.writeln("Passo 1: Validando esquema e integridade (RNF17)...");
  for (final MapEntry<String, Map<String, dynamic>> entry
      in kAracajuCollectPointsPayload.entries) {
    validateAndNormalizePoint(entry.key, entry.value);
  }
  stdout.writeln("✓ Todos os 8 registros validados com sucesso conforme RNF17.\n");

  // 2. Gravação na Base Local (Offline-First)
  stdout.writeln("Passo 2: Populando base local offline ($kLocalAssetPath)...");
  final int localCount = await seedLocalDatabase(
    payload: kAracajuCollectPointsPayload,
  );
  stdout.writeln(
    "✓ Gravação local concluída: $localCount registros inseridos/atualizados com sucesso.\n",
  );

  if (dryRun) {
    stdout.writeln("Modo --dry-run: gravação remota ignorada.");
    return;
  }

  // 3. Gravação no Cloud Firestore
  stdout.writeln("Passo 3: Populando Cloud Firestore ($projectId)...");
  final String token = _readFlag(args, "--token") ?? _resolveFirebaseCliToken();
  final HttpClient client = HttpClient();

  try {
    final int remoteCount = await seedCloudFirestore(
      client: client,
      projectId: projectId,
      token: token,
      payload: kAracajuCollectPointsPayload,
    );
    stdout.writeln(
      "✓ WriteBatch concluído: $remoteCount documentos gravados com sucesso em 'collectPoints'.\n",
    );

    // 4. Verificação de integridade pós-gravação
    stdout.writeln("Passo 4: Verificando documentos gravados no Firestore...");
    await verifyFirestoreDocuments(
      client: client,
      projectId: projectId,
      token: token,
      pointIds: kAracajuCollectPointsPayload.keys,
    );
    stdout.writeln("\n✓ Verificação remota confirmada com sucesso.");

    // Resumo final
    stdout.writeln("\n==================================================");
    stdout.writeln("Resumo de Execução do Seed:");
    stdout.writeln("(a) Registros gravados na base local: $localCount");
    stdout.writeln("(b) Documentos gravados em collectPoints no Firestore: $remoteCount");
    stdout.writeln(
      "(c) Arquivos envolvidos: eco_monitor/assets/data/collect_points.json, "
      "eco_monitor/tool/seed_aracaju_points.dart",
    );
    stdout.writeln("==================================================");
  } finally {
    client.close();
  }
}
