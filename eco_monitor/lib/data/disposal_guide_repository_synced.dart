import "dart:convert";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../domain/entities/disposal_guide.dart";
import "../domain/entities/residue.dart";
import "../domain/repositories/disposal_guide_repository.dart";
import "collect_points_repository.dart";
import "disposal_guide_repository_local.dart";
import "firebase_service.dart";
import "firestore_helpers.dart";

// Constants ---------------------------------------------------------------- //

/// Firestore collection name for disposal guides (`CRUD - Guia`).
const String kDisposalGuidesCollection = "disposalGuides";

const String _cacheJsonKey = "disposal_guides_json";
const String _cacheLastUpdatedKey = "disposal_guides_last_updated";

/// Maximum age before cached disposal guides are considered out of date.
const Duration kDisposalGuidesMaxAge = Duration(days: 30);

// Types ------------------------------------------------------------------- //

/// Remote snapshot of disposal guides and residue summaries fetched from
/// Firestore.
class DisposalGuidesRemoteSnapshot {
  const DisposalGuidesRemoteSnapshot({
    required this.residues,
    required this.guides,
    required this.updatedAt,
  });

  final List<Residue> residues;
  final Map<ResidueType, DisposalGuide> guides;
  final DateTime updatedAt;
}

/// Hook used by [DisposalGuideRepositorySynced.refresh] to fetch remote guides.
typedef DisposalGuidesFetcher = Future<DisposalGuidesRemoteSnapshot> Function();

// Methods ----------------------------------------------------------------- //

/// Creates a [DisposalGuidesFetcher] backed by the Firestore `disposalGuides`
/// collection.
///
/// Each document ID (or `type` field) corresponds to a [ResidueType] name
/// (`medicine`, `battery`, `sharps`) and may contain summary fields (`title`,
/// `description`, `minutes`, `totalSteps`) plus step-by-step fields
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
    final Map<ResidueType, DisposalGuide> guides =
        <ResidueType, DisposalGuide>{};

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

// Classes ----------------------------------------------------------------- //

/// Offline-first [DisposalGuideRepository] with optional Firestore sync.
///
/// Always initializes with the bundled [DisposalGuideRepositoryLocal] content
/// in memory so [listResidues] and [stepsGuideFor] work synchronously even on
/// the first offline launch (RNF09). Remote updates fetched via [refresh] are
/// cached in [SharedPreferences] and merged over the bundled defaults.
class DisposalGuideRepositorySynced implements DisposalGuideRepository {
  DisposalGuideRepositorySynced({
    this.fallback = const DisposalGuideRepositoryLocal(),
    this.fetcher,
    Future<SharedPreferences> Function()? preferencesFactory,
    DateTime Function()? clock,
  }) : _preferencesFactory =
           preferencesFactory ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now {
    _resetToFallback();
  }

  final DisposalGuideRepository fallback;
  final DisposalGuidesFetcher? fetcher;
  final Future<SharedPreferences> Function() _preferencesFactory;
  final DateTime Function() _clock;

  late List<Residue> _residues;
  late Map<ResidueType, DisposalGuide> _guides;

  DateTime? _lastUpdated;
  DataSourceOrigin _sourceOrigin = DataSourceOrigin.bundledAsset;

  /// Timestamp of the cached/remote guide dataset, or null when using defaults.
  DateTime? get lastUpdated => _lastUpdated;

  /// Origin of the guide content currently served.
  DataSourceOrigin get sourceOrigin => _sourceOrigin;

  bool get hasRemoteSource => fetcher != null;

  bool get isStale {
    final DateTime? lastUpdated = _lastUpdated;
    if (lastUpdated == null) {
      return false;
    }

    return _clock().difference(lastUpdated) > kDisposalGuidesMaxAge;
  }

  // Methods --------------------------------------------------------------- //

  @override
  List<Residue> listResidues() => List<Residue>.unmodifiable(_residues);

  @override
  DisposalGuide? stepsGuideFor(ResidueType type) => _guides[type];

  /// Loads cached guides from [SharedPreferences], keeping bundled defaults
  /// intact for any residue not present in the cache.
  Future<void> loadOffline() async {
    final SharedPreferences preferences = await _preferencesFactory();
    final String? cachedJson = preferences.getString(_cacheJsonKey);
    final int? cachedTimestamp = preferences.getInt(_cacheLastUpdatedKey);

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

  /// Fetches the latest guides from [fetcher], updates the local cache, and
  /// merges them into memory. Falls back to [loadOffline] on error.
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

  /// Clears cached guides and restores the bundled offline content.
  Future<void> clearCache() async {
    final SharedPreferences preferences = await _preferencesFactory();
    await preferences.remove(_cacheJsonKey);
    await preferences.remove(_cacheLastUpdatedKey);
    _lastUpdated = null;
    _sourceOrigin = DataSourceOrigin.bundledAsset;
    _resetToFallback();
  }

  void _resetToFallback() {
    _residues = List<Residue>.of(fallback.listResidues());
    _guides = <ResidueType, DisposalGuide>{};
    for (final ResidueType type in ResidueType.values) {
      final DisposalGuide? guide = fallback.stepsGuideFor(type);
      if (guide != null) {
        _guides[type] = guide;
      }
    }
  }

  void _applyOverlay(
    List<Residue> remoteResidues,
    Map<ResidueType, DisposalGuide> remoteGuides,
  ) {
    _resetToFallback();

    final Map<ResidueType, Residue> mergedResidues = <ResidueType, Residue>{
      for (final Residue residue in _residues) residue.type: residue,
    };
    for (final Residue residue in remoteResidues) {
      mergedResidues[residue.type] = residue;
    }

    _residues = ResidueType.values
        .map((ResidueType type) => mergedResidues[type])
        .whereType<Residue>()
        .toList();

    for (final MapEntry<ResidueType, DisposalGuide> entry
        in remoteGuides.entries) {
      _guides[entry.key] = entry.value;
    }
  }

  Future<void> _writeCache(
    List<Residue> residues,
    Map<ResidueType, DisposalGuide> guides,
    DateTime updatedAt,
  ) async {
    final SharedPreferences preferences = await _preferencesFactory();

    await preferences.setString(
      _cacheJsonKey,
      jsonEncode(<String, dynamic>{
        "updatedAt": updatedAt.toIso8601String(),
        "residues": residues.map((Residue item) => item.toJson()).toList(),
        "guides": guides.map(
          (ResidueType key, DisposalGuide value) =>
              MapEntry<String, dynamic>(key.name, value.toJson()),
        ),
      }),
    );
    await preferences.setInt(
      _cacheLastUpdatedKey,
      updatedAt.millisecondsSinceEpoch,
    );
  }
}

// Classes ----------------------------------------------------------------- //

class _ParsedGuides {
  const _ParsedGuides({
    required this.residues,
    required this.guides,
    required this.updatedAt,
  });

  final List<Residue> residues;
  final Map<ResidueType, DisposalGuide> guides;
  final DateTime? updatedAt;
}

// Methods ----------------------------------------------------------------- //

_ParsedGuides _parseGuidesJson(String source) {
  final Object? decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    return const _ParsedGuides(
      residues: <Residue>[],
      guides: <ResidueType, DisposalGuide>{},
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

  final Map<ResidueType, DisposalGuide> guides = <ResidueType, DisposalGuide>{};
  final Object? rawGuides = decoded["guides"];
  if (rawGuides is Map<dynamic, dynamic>) {
    for (final MapEntry<dynamic, dynamic> entry in rawGuides.entries) {
      final ResidueType? type = residueTypeByName(entry.key.toString());
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
