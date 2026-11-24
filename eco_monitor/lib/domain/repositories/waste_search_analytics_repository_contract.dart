import "../entities/waste_type.dart";


// Tipos -------------------------------------------------------------------- //


/// Modelo que representa a estatística agregada de pesquisas para um tipo de resíduo.
class WasteSearchStat {
  const WasteSearchStat({
    required this.type,
    required this.count,
    required this.percentage,
  });

  /// Categoria do resíduo analisado.
  final WasteType type;

  /// Quantidade total de consultas registradas.
  final int count;

  /// Percentual relativo em relação ao total de pesquisas (0 a 100).
  final double percentage;
}


// Interfaces --------------------------------------------------------------- //


/// Contrato para o repositório de registro e estatísticas de buscas de resíduos.
abstract interface class IWasteSearchAnalyticsRepository {
  /// Registra uma busca ou consulta para a categoria [type].
  Future<void> recordSearch(WasteType type);

  /// Retorna o contador total de consultas para a categoria [type].
  Future<int> getSearchCount(WasteType type);

  /// Retorna a lista de estatísticas ordenadas por relevância decrescente.
  Future<List<WasteSearchStat>> getRankedStats();

  /// Limpa as estatísticas persistidas localmente (útil em testes).
  Future<void> clear();
}
