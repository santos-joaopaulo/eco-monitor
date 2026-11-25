// Classes ------------------------------------------------------------------ //


/// Representa uma Unidade Federativa do Brasil para filtragem regional e geolocalização.
class BrazilState {
  const BrazilState({
    required this.code,
    required this.name,
    required this.bbox,
  });

  /// Sigla da Unidade Federativa em maiúsculas (ex.: "SE", "SP").
  final String code;

  /// Nome por extenso do estado (ex.: "Sergipe", "São Paulo").
  final String name;

  /// Caixa delimitadora aproximada [minLat, minLon, maxLat, maxLon].
  final List<double> bbox;

  /// Verifica se a coordenada informada pertence aos limites aproximados deste estado.
  bool containsCoordinate(double latitude, double longitude) {
    if (bbox.length < 4) {
      return false;
    }
    return latitude >= bbox[0] &&
        latitude <= bbox[2] &&
        longitude >= bbox[1] &&
        longitude <= bbox[3];
  }
}


// Constants ---------------------------------------------------------------- //


/// Catálogo das 27 Unidades Federativas do Brasil ordenado por sigla.
const List<BrazilState> kBrazilStates = <BrazilState>[
  BrazilState(code: "AC", name: "Acre", bbox: <double>[-11.15, -73.99, -7.11, -66.62]),
  BrazilState(code: "AL", name: "Alagoas", bbox: <double>[-10.50, -38.24, -8.81, -35.15]),
  BrazilState(code: "AP", name: "Amapá", bbox: <double>[-1.24, -54.88, 4.44, -49.88]),
  BrazilState(code: "AM", name: "Amazonas", bbox: <double>[-9.82, -73.80, 2.25, -56.10]),
  BrazilState(code: "BA", name: "Bahia", bbox: <double>[-18.35, -46.62, -8.53, -37.34]),
  BrazilState(code: "CE", name: "Ceará", bbox: <double>[-7.86, -41.42, -2.78, -37.25]),
  BrazilState(code: "DF", name: "Distrito Federal", bbox: <double>[-16.05, -48.29, -15.50, -47.31]),
  BrazilState(code: "ES", name: "Espírito Santo", bbox: <double>[-21.30, -41.88, -17.89, -39.68]),
  BrazilState(code: "GO", name: "Goiás", bbox: <double>[-19.50, -53.25, -12.39, -45.91]),
  BrazilState(code: "MA", name: "Maranhão", bbox: <double>[-10.26, -48.75, -1.04, -41.79]),
  BrazilState(code: "MT", name: "Mato Grosso", bbox: <double>[-18.04, -61.63, -7.35, -50.22]),
  BrazilState(code: "MS", name: "Mato Grosso do Sul", bbox: <double>[-24.07, -58.17, -17.16, -50.92]),
  BrazilState(code: "MG", name: "Minas Gerais", bbox: <double>[-22.92, -51.05, -14.23, -39.86]),
  BrazilState(code: "PA", name: "Pará", bbox: <double>[-9.84, -58.90, 2.59, -46.06]),
  BrazilState(code: "PB", name: "Paraíba", bbox: <double>[-8.30, -38.77, -6.02, -34.79]),
  BrazilState(code: "PR", name: "Paraná", bbox: <double>[-26.72, -54.62, -22.52, -48.02]),
  BrazilState(code: "PE", name: "Pernambuco", bbox: <double>[-9.48, -41.36, -7.15, -34.81]),
  BrazilState(code: "PI", name: "Piauí", bbox: <double>[-10.93, -45.99, -2.74, -40.37]),
  BrazilState(code: "RJ", name: "Rio de Janeiro", bbox: <double>[-23.37, -44.89, -20.76, -40.96]),
  BrazilState(code: "RN", name: "Rio Grande do Norte", bbox: <double>[-6.98, -38.58, -4.83, -34.96]),
  BrazilState(code: "RS", name: "Rio Grande do Sul", bbox: <double>[-33.75, -57.64, -27.08, -49.69]),
  BrazilState(code: "RO", name: "Rondônia", bbox: <double>[-13.69, -66.81, -7.97, -59.77]),
  BrazilState(code: "RR", name: "Roraima", bbox: <double>[-1.58, -64.82, 5.27, -58.89]),
  BrazilState(code: "SC", name: "Santa Catarina", bbox: <double>[-29.35, -53.84, -25.96, -48.33]),
  BrazilState(code: "SP", name: "São Paulo", bbox: <double>[-25.31, -53.11, -19.78, -44.16]),
  BrazilState(code: "SE", name: "Sergipe", bbox: <double>[-11.57, -38.25, -9.51, -36.39]),
  BrazilState(code: "TO", name: "Tocantins", bbox: <double>[-13.47, -50.74, -5.17, -45.73]),
];


// Helpers ------------------------------------------------------------------ //


/// Utilitários para consulta e normalização de Unidades Federativas brasileiras.
abstract final class BrazilStates {
  /// Normaliza uma sigla de UF (retorna `null` se inválida ou vazia).
  static String? normalizeCode(String? stateCode) {
    if (stateCode == null) {
      return null;
    }
    final String normalized = stateCode.trim().toUpperCase();
    for (final BrazilState state in kBrazilStates) {
      if (state.code == normalized) {
        return state.code;
      }
    }
    return null;
  }

  /// Retorna o [BrazilState] correspondente à sigla [stateCode], ou `null`.
  static BrazilState? byCode(String? stateCode) {
    final String? normalized = normalizeCode(stateCode);
    if (normalized == null) {
      return null;
    }
    for (final BrazilState state in kBrazilStates) {
      if (state.code == normalized) {
        return state;
      }
    }
    return null;
  }

  /// Identifica a UF mais provável para uma coordenada geográfica, priorizando
  /// a menor caixa delimitadora em áreas de sobreposição.
  static String? findCodeByCoordinates(double latitude, double longitude) {
    BrazilState? bestMatch;
    double bestArea = double.infinity;

    for (final BrazilState state in kBrazilStates) {
      if (!state.containsCoordinate(latitude, longitude)) {
        continue;
      }
      final double area =
          (state.bbox[2] - state.bbox[0]) * (state.bbox[3] - state.bbox[1]);
      if (area < bestArea) {
        bestArea = area;
        bestMatch = state;
      }
    }

    return bestMatch?.code;
  }
}
