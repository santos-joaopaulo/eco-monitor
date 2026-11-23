import "../entities/collection_point.dart";


// Contracts --------------------------------------------------------------- //


/// Contrato do repositório de pontos de coleta (Camada de Domínio).
abstract interface class ICollectPointsRepository {
  /// Carrega os pontos de coleta armazenados no cache local.
  Future<List<CollectionPoint>> loadOffline();

  /// Atualiza o conjunto de pontos buscando dados da fonte remota.
  Future<List<CollectionPoint>> refresh();

  /// Timestamp da última atualização dos dados carregados.
  DateTime? get lastUpdated;

  /// Indica se os dados locais estão obsoletos.
  bool get isStale;

  /// Indica se o repositório possui uma fonte remota configurada.
  bool get hasRemoteSource;
}
