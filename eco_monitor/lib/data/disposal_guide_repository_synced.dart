import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../domain/entities/disposal_guide.dart";
import "../domain/entities/residue.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "collect_points_repository.dart";
import "disposal_guide_repository_local.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";
import "local_store.dart";


// Constants ---------------------------------------------------------------- //


/// Nome da coleção no Firestore para guias de descarte (`CRUD - Guia`).
const String kDisposalGuidesCollection = "disposalGuides";

const String _cacheJsonKey = "disposal_guides_json";
const String _cacheLastUpdatedKey = "disposal_guides_last_updated";

/// Idade máxima antes que os guias de descarte em cache sejam considerados desatualizados.
const Duration kDisposalGuidesMaxAge = Duration(days: 30);


// Types -------------------------------------------------------------------- //


/// Snapshot remoto de guias de descarte e resumos de resíduos obtidos do
/// Firestore.
class DisposalGuidesRemoteSnapshot {
  const DisposalGuidesRemoteSnapshot({
    required this.residues,
    required this.guides,
    required this.updatedAt,
  });

  final List<Residue> residues;
  final Map<WasteType, DisposalGuide> guides;
  final DateTime updatedAt;
}

/// Função usada por [DisposalGuideRepositorySynced.refresh] para buscar guias remotos.
typedef DisposalGuidesFetcher = Future<DisposalGuidesRemoteSnapshot> Function();


// Methods ------------------------------------------------------------------ //


/// Cria um [DisposalGuidesFetcher] baseado na coleção `disposalGuides`
/// do Firestore.
///
/// O ID de cada documento (ou campo `type`) corresponde ao nome de um [WasteType]
/// (`medicines`, `batteries`, `sharps`) e pode conter campos de resumo (`title`,
/// `description`, `minutes`, `totalSteps`) além de campos do passo a passo
/// (`subtitle`, `warning`, `steps`).
DisposalGuidesFetcher createFirestoreGuidesFetcher({
  FirebaseFirestore? firestore,
}) {
  return () async {
    if (firestore == null && !isFirebaseReady) {
      throw StateError("Firebase is not initialized.");
    }

    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final QuerySnapshot<Map<String, dynamic>> snapshot = await db
        .collection(kDisposalGuidesCollection)
        .get();

    if (snapshot.docs.isEmpty) {
      throw StateError("Remote disposalGuides collection is empty.");
    }

    DateTime? mostRecent = await readCollectionMetadataUpdatedAt(
      db,
      kDisposalGuidesCollection,
    );

    final List<Residue> residues = <Residue>[];
    final Map<WasteType, DisposalGuide> guides =
        <WasteType, DisposalGuide>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      final Map<String, dynamic> raw = doc.data();
      final DateTime? docUpdatedAt = extractFirestoreTimestamp(
        raw["updatedAt"],
      );
      if (docUpdatedAt != null &&
          (mostRecent == null || docUpdatedAt.isAfter(mostRecent))) {
        mostRecent = docUpdatedAt;
      }

      final Map<String, dynamic> normalized = normalizeFirestoreData(
        raw,
        documentId: doc.id,
      );
      normalized.putIfAbsent("type", () => doc.id);

      final Residue? residue = Residue.tryFromJson(normalized);
      if (residue == null) {
        continue;
      }

      final DisposalGuide parsedGuide = DisposalGuide.fromJson(normalized);
      final Residue resolvedResidue =
          residue.totalSteps == 0 && parsedGuide.steps.isNotEmpty
          ? Residue(
              type: residue.type,
              title: residue.title,
              description: residue.description,
              minutes: residue.minutes,
              totalSteps: parsedGuide.steps.length,
            )
          : residue;

      residues.add(resolvedResidue);
      if (parsedGuide.steps.isNotEmpty) {
        guides[residue.type] = parsedGuide;
      }
    }

    return DisposalGuidesRemoteSnapshot(
      residues: residues,
      guides: guides,
      updatedAt:
          mostRecent ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  };
}


// Classes ------------------------------------------------------------------ //


/// [DisposalGuideRepository] offline-first com sincronização opcional via Firestore.
///
/// Sempre inicializa com o conteúdo empacotado de [DisposalGuideRepositoryLocal]
/// em memória para que [listResidues] e [stepsGuideFor] funcionem sincronicamente
/// mesmo na primeira inicialização offline (RNF09). Atualizações remotas obtidas via
/// [refresh] são salvas em cache no [SharedPreferences] e mescladas com os padrões empacotados.
class DisposalGuideRepositorySynced implements DisposalGuideRepository {
  DisposalGuideRepositorySynced({
    this.fallback = const DisposalGuideRepositoryLocal(),
    this.fetcher,
    LocalStore? localStore,
    Future<SharedPreferences> Function()? preferencesFactory,
    DateTime Function()? clock,
  }) : _store = localStore ??
           SharedPreferencesLocalStore(
             preferencesFactory: preferencesFactory,
           ),
       _clock = clock ?? DateTime.now {
    _resetToFallback();
  }

  final DisposalGuideRepository fallback;
  final DisposalGuidesFetcher? fetcher;
  final LocalStore _store;
  final DateTime Function() _clock;

  late List<Residue> _residues;
  late Map<WasteType, DisposalGuide> _guides;

  DateTime? _lastUpdated;
  DataSourceOrigin _sourceOrigin = DataSourceOrigin.bundledAsset;

  /// Timestamp do conjunto de guias em cache/remoto, ou nulo ao usar os dados padrão empacotados.
  DateTime? get lastUpdated => _lastUpdated;

  /// Origem do conteúdo de guias atualmente servido.
  DataSourceOrigin get sourceOrigin => _sourceOrigin;

  bool get hasRemoteSource => fetcher != null;

  bool get isStale {
    final DateTime? lastUpdated = _lastUpdated;
    if (lastUpdated == null) {
      return false;
    }

    return _clock().difference(lastUpdated) > kDisposalGuidesMaxAge;
  }


// Methods ------------------------------------------------------------------ //


  @override
  List<Residue> listResidues() => List<Residue>.unmodifiable(_residues);

  @override
  DisposalGuide? stepsGuideFor(WasteType type) => _guides[type];

  /// Carrega os guias em cache do [LocalStore], mantendo intactos os
  /// padrões empacotados para qualquer resíduo não presente no cache.
  Future<void> loadOffline() async {
    final String? cachedJson = await _store.getString(_cacheJsonKey);
    final int? cachedTimestamp = await _store.getInt(_cacheLastUpdatedKey);

    if (cachedJson == null || cachedJson.isEmpty) {
      _resetToFallback();
      _sourceOrigin = DataSourceOrigin.bundledAsset;
      return;
    }

    try {
      final _ParsedGuides parsed = _parseGuidesJson(cachedJson);
      if (parsed.residues.isEmpty && parsed.guides.isEmpty) {
        _resetToFallback();
        _sourceOrigin = DataSourceOrigin.bundledAsset;
        return;
      }

      _applyOverlay(parsed.residues, parsed.guides);
      _lastUpdated = cachedTimestamp == null
          ? parsed.updatedAt
          : DateTime.fromMillisecondsSinceEpoch(cachedTimestamp, isUtc: true);
      _sourceOrigin = DataSourceOrigin.localCache;
    } catch (_) {
      _resetToFallback();
      _sourceOrigin = DataSourceOrigin.bundledAsset;
    }
  }

  /// Busca os guias mais recentes de [fetcher], atualiza o cache local e
  /// os mescla em memória. Recorre a [loadOffline] em caso de erro.
  Future<void> refresh() async {
    final DisposalGuidesFetcher? remoteFetcher = fetcher;
    if (remoteFetcher == null) {
      await loadOffline();
      return;
    }

    try {
      final DisposalGuidesRemoteSnapshot remote = await remoteFetcher();
      if (remote.residues.isEmpty && remote.guides.isEmpty) {
        await loadOffline();
        return;
      }

      final DateTime updatedAt = remote.updatedAt.toUtc();
      _applyOverlay(remote.residues, remote.guides);
      await _writeCache(remote.residues, remote.guides, updatedAt);
      _lastUpdated = updatedAt;
      _sourceOrigin = DataSourceOrigin.remoteServer;
    } catch (_) {
      await loadOffline();
    }
  }

  /// Limpa os guias em cache e restaura o conteúdo offline empacotado.
  Future<void> clearCache() async {
    await _store.remove(_cacheJsonKey);
    await _store.remove(_cacheLastUpdatedKey);
    _lastUpdated = null;
    _sourceOrigin = DataSourceOrigin.bundledAsset;
    _resetToFallback();
  }

  void _resetToFallback() {
    _residues = List<Residue>.of(fallback.listResidues());
    _guides = <WasteType, DisposalGuide>{};
    for (final WasteType type in WasteType.values) {
      final DisposalGuide? guide = fallback.stepsGuideFor(type);
      if (guide != null) {
        _guides[type] = guide;
      }
    }
  }

  void _applyOverlay(
    List<Residue> remoteResidues,
    Map<WasteType, DisposalGuide> remoteGuides,
  ) {
    _resetToFallback();

    final Map<WasteType, Residue> mergedResidues = <WasteType, Residue>{
      for (final Residue residue in _residues) residue.type: residue,
    };
    for (final Residue residue in remoteResidues) {
      mergedResidues[residue.type] = residue;
    }

    // Mantém a ordem de exibição do guia empacotado, já que a ordem declarada
    // em [WasteType] é otimizada para os filtros do mapa.
    _residues = <Residue>[
      for (final Residue bundled in fallback.listResidues())
        mergedResidues[bundled.type] ?? bundled,
    ];

    for (final MapEntry<WasteType, DisposalGuide> entry
        in remoteGuides.entries) {
      _guides[entry.key] = entry.value;
    }
  }

  Future<void> _writeCache(
    List<Residue> residues,
    Map<WasteType, DisposalGuide> guides,
    DateTime updatedAt,
  ) async {
    await _store.setString(
      _cacheJsonKey,
      jsonEncode(<String, dynamic>{
        "updatedAt": updatedAt.toIso8601String(),
        "residues": residues.map((Residue item) => item.toJson()).toList(),
        "guides": guides.map(
          (WasteType key, DisposalGuide value) =>
              MapEntry<String, dynamic>(key.name, value.toJson()),
        ),
      }),
    );
    await _store.setInt(
      _cacheLastUpdatedKey,
      updatedAt.millisecondsSinceEpoch,
    );
  }
}


// Classes ------------------------------------------------------------------ //


class _ParsedGuides {
  const _ParsedGuides({
    required this.residues,
    required this.guides,
    required this.updatedAt,
  });

  final List<Residue> residues;
  final Map<WasteType, DisposalGuide> guides;
  final DateTime? updatedAt;
}


// Methods ------------------------------------------------------------------ //


_ParsedGuides _parseGuidesJson(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    return const _ParsedGuides(
      residues: <Residue>[],
      guides: <WasteType, DisposalGuide>{},
      updatedAt: null,
    );
  }

  final List<dynamic> rawResidues = decoded["residues"] is List<dynamic>
      ? decoded["residues"] as List<dynamic>
      : const <dynamic>[];
  final List<Residue> residues = rawResidues
      .whereType<Map<dynamic, dynamic>>()
      .map(
        (Map<dynamic, dynamic> json) =>
            Residue.tryFromJson(json.cast<String, dynamic>()),
      )
      .whereType<Residue>()
      .toList();

  final Map<WasteType, DisposalGuide> guides = <WasteType, DisposalGuide>{};
  final Object? rawGuides = decoded["guides"];
  if (rawGuides is Map<dynamic, dynamic>) {
    for (final MapEntry<dynamic, dynamic> entry in rawGuides.entries) {
      final WasteType? type = wasteTypeByName(entry.key.toString());
      if (type != null && entry.value is Map<dynamic, dynamic>) {
        final DisposalGuide guide = DisposalGuide.fromJson(
          (entry.value as Map<dynamic, dynamic>).cast<String, dynamic>(),
        );
        if (guide.steps.isNotEmpty) {
          guides[type] = guide;
        }
      }
    }
  }

  final String? rawUpdatedAt = decoded["updatedAt"] is String
      ? decoded["updatedAt"] as String
      : null;

  return _ParsedGuides(
    residues: residues,
    guides: guides,
    updatedAt: rawUpdatedAt == null ? null : DateTime.tryParse(rawUpdatedAt),
  );
}
