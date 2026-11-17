import "dart:convert";
import "dart:io";

// CLI entrypoint ---------------------------------------------------------- //

/// Seeds Cloud Firestore (production or local Firebase Emulator) with the
/// initial EcoMonitor datasets (`collectPoints`, `campaigns`, `disposalGuides`,
/// and `metadata`).
///
/// Examples:
/// ```bash
/// # Seed the local Firestore emulator (no auth token required):
/// dart run tool/seed_firestore.dart --project demo-ecomonitor --emulator
///
/// # Seed a real Firebase project using a gcloud/Firebase OAuth access token:
/// dart run tool/seed_firestore.dart --project my-firebase-project --token "$TOKEN"
/// ```
Future<void> main(List<String> args) async {
  final String? projectId = _readFlag(args, "--project");
  final String? accessToken = _readFlag(args, "--token");
  final bool useEmulator = args.contains("--emulator");
  final String emulatorHost =
      _readFlag(args, "--emulator-host") ?? "127.0.0.1:8080";

  if (projectId == null || projectId.isEmpty) {
    stderr.writeln(
      "Usage: dart run tool/seed_firestore.dart "
      "--project <PROJECT_ID> [--emulator | --token <OAUTH_TOKEN>]",
    );
    exitCode = 64;
    return;
  }

  if (!useEmulator && (accessToken == null || accessToken.isEmpty)) {
    stderr.writeln(
      "Missing --token for production Firestore. Pass --emulator to target "
      "the local Firestore emulator.",
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

    stdout.writeln("Firestore seed completed for project '$projectId'.");
  } finally {
    client.close();
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
  final Map<String, Map<String, dynamic>>
  guides = <String, Map<String, dynamic>>{
    "medicine": <String, dynamic>{
      "type": _stringValue("medicine"),
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
  };

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

// Helpers ----------------------------------------------------------------- //

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
