import "../domain/entities/waste_type.dart";
import "../domain/repositories/waste_search_analytics_repository_contract.dart";
import "local_store.dart";


// Repositories ------------------------------------------------------------ //


/// Implementação offline-first para persistência e agregação local de pesquisas de resíduos.
class WasteSearchAnalyticsRepository
    implements IWasteSearchAnalyticsRepository {
  WasteSearchAnalyticsRepository({LocalStore? localStore})
    : _store = localStore ?? SharedPreferencesLocalStore();

  final LocalStore _store;

  static const String _keyPrefix = "waste_search_count_";

  /// Pesos base para fornecer um ranking realista out-of-the-box no primeiro uso do aplicativo.
  static const Map<WasteType, int> _baselineCounts = <WasteType, int>{
    WasteType.medicines: 45,
    WasteType.batteries: 25,
    WasteType.sharps: 18,
    WasteType.electronics: 8,
    WasteType.glass: 4,
  };


  // Methods --------------------------------------------------------------- //


  @override
  Future<void> recordSearch(WasteType type) async {
    final String key = "$_keyPrefix${type.name}";
    final int current = await _store.getInt(key) ?? 0;
    await _store.setInt(key, current + 1);
  }

  @override
  Future<int> getSearchCount(WasteType type) async {
    final String key = "$_keyPrefix${type.name}";
    final int recorded = await _store.getInt(key) ?? 0;
    final int baseline = _baselineCounts[type] ?? 0;
    return recorded + baseline;
  }

  @override
  Future<List<WasteSearchStat>> getRankedStats() async {
    final Map<WasteType, int> counts = <WasteType, int>{};
    int total = 0;

    for (final WasteType type in WasteType.values) {
      final int count = await getSearchCount(type);
      counts[type] = count;
      total += count;
    }

    final List<WasteSearchStat> stats = <WasteSearchStat>[];
    for (final WasteType type in WasteType.values) {
      final int count = counts[type] ?? 0;
      final double percentage = total > 0 ? (count / total) * 100.0 : 0.0;
      stats.add(
        WasteSearchStat(
          type: type,
          count: count,
          percentage: percentage,
        ),
      );
    }

    stats.sort((WasteSearchStat a, WasteSearchStat b) {
      final int cmp = b.count.compareTo(a.count);
      if (cmp != 0) {
        return cmp;
      }
      return a.type.index.compareTo(b.type.index);
    });

    return stats;
  }

  @override
  Future<void> clear() async {
    for (final WasteType type in WasteType.values) {
      await _store.remove("$_keyPrefix${type.name}");
    }
  }
}
