import "../domain/entities/waste_type.dart";


// Tipos ------------------------------------------------------------------- //


/// Resultado da busca textual de tipos de resíduos com o termo correspondente e pontuação.
class WasteTypeSearchResult {
  const WasteTypeSearchResult({
    required this.type,
    required this.matchedTerm,
    required this.score,
  });

  /// Tipo de resíduo identificado pela busca.
  final WasteType type;

  /// Termo ou sinônimo popular correspondente.
  final String matchedTerm;

  /// Pontuação de relevância da correspondência (0 a 100).
  final int score;
}


// Classes ----------------------------------------------------------------- //


/// Serviço de consulta rápida por tipo de resíduo usando busca textual e sinônimos populares.
class ResidueSearchService {
  const ResidueSearchService();

  static const Map<WasteType, List<String>> _synonyms =
      <WasteType, List<String>>{
        WasteType.medicines: <String>[
          "remedio",
          "remedios",
          "medicamento",
          "medicamentos",
          "comprimido",
          "comprimidos",
          "xarope",
          "xaropes",
          "pomada",
          "pomadas",
          "paracetamol",
          "dipirona",
          "amoxicilina",
          "antibiotico",
          "antibioticos",
          "anti-inflamatorio",
          "anti-inflamatorios",
          "capsula",
          "capsulas",
          "colirio",
          "colirios",
          "blister",
          "cartela de remedio",
          "cartela",
          "pastilha",
          "pastilhas",
          "analgesico",
          "analgesicos",
          "spray nasal",
          "termometro de mercurio",
          "remedio vencido",
          "medicamento vencido",
          "anticoncepcional",
          "ibuprofeno",
          "dorflex",
          "losartana",
        ],
        WasteType.sharps: <String>[
          "seringa",
          "seringas",
          "agulha",
          "agulhas",
          "perfurocortante",
          "perfurocortantes",
          "seringa de insulina",
          "caneta de insulina",
          "lanceta",
          "lancetas",
          "bisturi",
          "escalpe",
          "glicosimetro",
          "lamina",
          "laminas",
          "fita reagente",
          "cateter",
          "ampola quebrada",
        ],
        WasteType.batteries: <String>[
          "pilha",
          "pilhas",
          "bateria",
          "baterias",
          "pilha alcalina",
          "pilhas alcalinas",
          "pilha aa",
          "pilha aaa",
          "pilha botao",
          "bateria de celular",
          "bateria de notebook",
          "bateria 9v",
          "pilha recarregavel",
          "pilhas recarregaveis",
          "bateria de litio",
          "acumulador",
        ],
        WasteType.electronics: <String>[
          "eletronico",
          "eletronicos",
          "lixo eletronico",
          "celular",
          "celulares",
          "smartphone",
          "smartphones",
          "computador",
          "computadores",
          "notebook",
          "notebooks",
          "laptop",
          "monitor",
          "monitores",
          "teclado",
          "mouse",
          "cabo",
          "cabos",
          "cabo usb",
          "usb",
          "carregador",
          "carregadores",
          "fone",
          "fones",
          "fone de ouvido",
          "tablet",
          "tablets",
          "televisao",
          "tv",
          "aparelho",
          "placa",
          "placa mae",
          "roteador",
          "impressora",
        ],
        WasteType.glass: <String>[
          "vidro",
          "vidros",
          "frasco de vidro",
          "frascos de vidro",
          "frasco de remedio",
          "frasco de xarope",
          "ampola",
          "ampolas",
          "ampola de vidro",
          "garrafa de vidro",
          "pote de vidro",
          "cacos de vidro",
          "vidro quebrado",
          "recipiente de vidro",
          "vidro de remedio",
        ],
      };


  // Methods --------------------------------------------------------------- //


  /// Remove acentos e converte para minúsculas para busca insensível a maiúsculas e diacríticos.
  static String normalize(String text) {
    const String withAccents =
        "áàãâäéèêëíìîïóòõôöúùûüçñÁÀÃÂÄÉÈÊËÍÌÎÏÓÒÕÔÖÚÙÛÜÇÑ";
    const String withoutAccents =
        "aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN";

    String normalized = text.trim().toLowerCase();
    for (int i = 0; i < withAccents.length; i++) {
      normalized = normalized.replaceAll(withAccents[i], withoutAccents[i]);
    }
    return normalized;
  }

  /// Executa busca textual contra o dicionário de sinônimos e retorna os resultados ranqueados.
  List<WasteTypeSearchResult> search(String rawQuery) {
    final String query = normalize(rawQuery);
    if (query.isEmpty) {
      return const <WasteTypeSearchResult>[];
    }

    final Map<WasteType, WasteTypeSearchResult> bestMatches =
        <WasteType, WasteTypeSearchResult>{};

    for (final MapEntry<WasteType, List<String>> entry in _synonyms.entries) {
      final WasteType type = entry.key;

      for (final String term in entry.value) {
        final String normalizedTerm = normalize(term);
        int score = 0;

        if (normalizedTerm == query) {
          score = 100;
        } else if (normalizedTerm.startsWith(query)) {
          score = 75;
        } else if (query.startsWith(normalizedTerm)) {
          score = 65;
        } else if (normalizedTerm.contains(query)) {
          score = 50;
        } else if (query.contains(normalizedTerm)) {
          score = 40;
        }

        if (score > 0) {
          final WasteTypeSearchResult? current = bestMatches[type];
          if (current == null || score > current.score) {
            bestMatches[type] = WasteTypeSearchResult(
              type: type,
              matchedTerm: term,
              score: score,
            );
          }
        }
      }
    }

    final List<WasteTypeSearchResult> results = bestMatches.values.toList()
      ..sort((WasteTypeSearchResult a, WasteTypeSearchResult b) {
        final int cmp = b.score.compareTo(a.score);
        if (cmp != 0) {
          return cmp;
        }
        return a.type.index.compareTo(b.type.index);
      });

    return results;
  }

  /// Retorna o [WasteType] com a melhor correspondência textual para [query], ou `null` se nada bater.
  WasteType? matchSingleWasteType(String query) {
    final List<WasteTypeSearchResult> results = search(query);
    return results.isNotEmpty ? results.first.type : null;
  }

  /// Retorna uma lista de termos autocompletados sugeridos para o prefixo digitado.
  List<String> getSuggestions(String rawQuery, {int limit = 5}) {
    final String query = normalize(rawQuery);
    if (query.isEmpty) {
      return const <String>[];
    }

    final List<String> suggestions = <String>[];
    for (final List<String> terms in _synonyms.values) {
      for (final String term in terms) {
        final String normalized = normalize(term);
        if (normalized.startsWith(query) || normalized.contains(query)) {
          if (!suggestions.contains(term)) {
            suggestions.add(term);
            if (suggestions.length >= limit) {
              return suggestions;
            }
          }
        }
      }
    }

    return suggestions;
  }
}
