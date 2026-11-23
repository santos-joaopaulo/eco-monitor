import "package:flutter_test/flutter_test.dart";

import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/services/residue_search_service.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  const ResidueSearchService service = ResidueSearchService();

  group("ResidueSearchService - Busca textual e resolução de sinônimos", () {
    test("mapeia termos populares de medicamentos para WasteType.medicines", () {
      expect(service.matchSingleWasteType("paracetamol"), WasteType.medicines);
      expect(service.matchSingleWasteType("amoxicilina"), WasteType.medicines);
      expect(service.matchSingleWasteType("dipirona"), WasteType.medicines);
      expect(service.matchSingleWasteType("comprimido"), WasteType.medicines);
      expect(service.matchSingleWasteType("xarope"), WasteType.medicines);
      expect(service.matchSingleWasteType("pomada"), WasteType.medicines);
    });

    test("mapeia termos populares de pilhas para WasteType.batteries", () {
      expect(service.matchSingleWasteType("pilha alcalina"), WasteType.batteries);
      expect(service.matchSingleWasteType("bateria"), WasteType.batteries);
      expect(service.matchSingleWasteType("pilha aa"), WasteType.batteries);
      expect(service.matchSingleWasteType("bateria de celular"), WasteType.batteries);
    });

    test("mapeia termos populares de perfurocortantes para WasteType.sharps", () {
      expect(service.matchSingleWasteType("seringa de insulina"), WasteType.sharps);
      expect(service.matchSingleWasteType("agulha"), WasteType.sharps);
      expect(service.matchSingleWasteType("lanceta"), WasteType.sharps);
      expect(service.matchSingleWasteType("bisturi"), WasteType.sharps);
    });

    test("mapeia termos populares de eletrônicos para WasteType.electronics", () {
      expect(service.matchSingleWasteType("monitor"), WasteType.electronics);
      expect(service.matchSingleWasteType("cabo usb"), WasteType.electronics);
      expect(service.matchSingleWasteType("celular"), WasteType.electronics);
      expect(service.matchSingleWasteType("carregador"), WasteType.electronics);
      expect(service.matchSingleWasteType("teclado"), WasteType.electronics);
    });

    test("mapeia termos populares de vidro para WasteType.glass", () {
      expect(service.matchSingleWasteType("frasco de xarope"), WasteType.glass);
      expect(service.matchSingleWasteType("ampola de vidro"), WasteType.glass);
      expect(service.matchSingleWasteType("vidro"), WasteType.glass);
      expect(service.matchSingleWasteType("frasco de vidro"), WasteType.glass);
      expect(service.matchSingleWasteType("cacos de vidro"), WasteType.glass);
    });

    test("é insensível a maiúsculas e espaços extras", () {
      expect(service.matchSingleWasteType("  PARACETAMOL  "), WasteType.medicines);
      expect(service.matchSingleWasteType("PILHA ALCALINA"), WasteType.batteries);
      expect(service.matchSingleWasteType("CABO USB"), WasteType.electronics);
      expect(service.matchSingleWasteType("AMPOLA DE VIDRO"), WasteType.glass);
    });

    test("é insensível a acentuação e diacríticos", () {
      expect(service.matchSingleWasteType("remédio"), WasteType.medicines);
      expect(service.matchSingleWasteType("antibiótico"), WasteType.medicines);
      expect(service.matchSingleWasteType("anti-inflamatório"), WasteType.medicines);
      expect(service.matchSingleWasteType("eletrônico"), WasteType.electronics);
      expect(service.matchSingleWasteType("glicosímetro"), WasteType.sharps);
      expect(service.matchSingleWasteType("lâmina"), WasteType.sharps);
    });

    test("retorna pontuação e termos correspondentes na busca detalhada", () {
      final List<WasteTypeSearchResult> results = service.search("paracetamol");

      expect(results, isNotEmpty);
      expect(results.first.type, WasteType.medicines);
      expect(results.first.matchedTerm, "paracetamol");
      expect(results.first.score, 100);
    });

    test("retorna sugestões parciais para autocompletar", () {
      final List<String> suggestions = service.getSuggestions("pilha");

      expect(suggestions, isNotEmpty);
      expect(suggestions.contains("pilha"), isTrue);
      expect(suggestions.contains("pilha alcalina"), isTrue);
    });

    test("retorna vazio ou null para termos desconhecidos ou vazios", () {
      expect(service.matchSingleWasteType(""), isNull);
      expect(service.matchSingleWasteType("   "), isNull);
      expect(service.matchSingleWasteType("termo_inexistente_xyz"), isNull);
      expect(service.search(""), isEmpty);
      expect(service.getSuggestions(""), isEmpty);
    });
  });
}
