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
  ///
  /// Quando [stateCode] é informado (ex.: "SE"), a consulta é contabilizada
  /// tanto no ranking nacional quanto no ranking específico daquela UF.
  Future<void> recordSearch(WasteType type, {String? stateCode});

  /// Retorna o contador total de consultas para a categoria [type].
  ///
  /// Quando [stateCode] é `null`, considera o agregado global de todos os dispositivos.
  Future<int> getSearchCount(WasteType type, {String? stateCode});

  /// Retorna a lista de estatísticas ordenadas por relevância decrescente.
  ///
  /// Quando [stateCode] é `null`, retorna o ranking padrão de todos os dispositivos.
  Future<List<WasteSearchStat>> getRankedStats({String? stateCode});

  /// Envia incrementos pendentes acumulados offline para a nuvem, se houver.
  Future<void> flushPending();

  /// Retorna a quantidade de pesquisas pendentes na fila offline aguardando sincronização.
  Future<int> pendingCount();

  /// Limpa as estatísticas persistidas localmente (útil em testes).
  Future<void> clear();
}
