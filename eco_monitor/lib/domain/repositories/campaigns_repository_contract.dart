import "../entities/campaign.dart";


// Contracts --------------------------------------------------------------- //


/// Contrato do repositório de campanhas de coleta (Camada de Domínio).
abstract interface class ICampaignsRepository {
  /// Carrega as campanhas salvas localmente.
  Future<List<Campaign>> loadOffline();

  /// Atualiza as campanhas a partir da fonte remota.
  Future<List<Campaign>> refresh();

  /// Timestamp da última atualização das campanhas.
  DateTime? get lastUpdated;

  /// Indica se os dados de campanhas estão obsoletos.
  bool get isStale;

  /// Indica se há fonte remota configurada.
  bool get hasRemoteSource;
}
