import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:eco_monitor/data/collect_points_repository.dart";
import "package:eco_monitor/data/local_store.dart";
import "package:eco_monitor/domain/entities/waste_type.dart";
import "package:eco_monitor/models/collection_point.dart";
import "../tool/seed_aracaju_points.dart";


// Tests -------------------------------------------------------------------- //


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Validação de integridade e schema RNF17", () {
    test("valida corretamente todos os 8 pontos de Aracaju do payload", () {
      expect(kAracajuCollectPointsPayload.length, 8);

      for (final MapEntry<String, Map<String, dynamic>> entry
          in kAracajuCollectPointsPayload.entries) {
        final Map<String, dynamic> normalized = validateAndNormalizePoint(
          entry.key,
          entry.value,
        );

        expect(normalized["id"], entry.key);
        expect(normalized["name"], isNotEmpty);
        expect(
          kAllowedPointTypes.contains(normalized["type"]),
          isTrue,
          reason: "Tipo ${normalized['type']} deve ser válido.",
        );
        expect(normalized["latitude"], isA<double>());
        expect(normalized["longitude"], isA<double>());
        expect(normalized["address"], contains("Aracaju - SE"));

        final List<String> wasteTypes =
            normalized["acceptedWasteTypes"] as List<String>;
        expect(wasteTypes, isNotEmpty);
        for (final String type in wasteTypes) {
          expect(kAllowedWasteTypes.contains(type), isTrue);
        }

        expect(normalized["status"], "active");

        // Valida que o modelo de domínio CollectionPoint instancia perfeitamente
        final CollectionPoint entity = CollectionPoint.fromJson(normalized);
        expect(entity.id, entry.key);
        expect(entity.isActive, isTrue);
      }
    });

    test("fallback de status desconhecido para inactive conforme RNF17", () {
      final Map<String, dynamic> invalidStatus = <String, dynamic>{
        "name": "Ponto com status inválido",
        "type": "pharmacy",
        "latitude": -10.91,
        "longitude": -37.05,
        "address": "Rua Teste, 1 — Centro, Aracaju - SE",
        "acceptedWasteTypes": <String>["medicines"],
        "hours": "Seg a sex, 8h às 18h",
        "status": "pending_approval",
      };

      final Map<String, dynamic> normalized = validateAndNormalizePoint(
        "invalid_status_point",
        invalidStatus,
      );

      expect(normalized["status"], "inactive");
      final CollectionPoint point = CollectionPoint.fromJson(normalized);
      expect(point.status, PointStatus.inactive);
      expect(point.isActive, isFalse);
    });

    test("rejeita tipos de estabelecimento não permitidos", () {
      final Map<String, dynamic> invalidType = <String, dynamic>{
        "name": "Supermercado",
        "type": "supermarket",
        "latitude": -10.91,
        "longitude": -37.05,
        "address": "Rua Teste, 1 — Centro, Aracaju - SE",
        "acceptedWasteTypes": <String>["batteries"],
        "hours": "Seg a dom, 8h às 22h",
        "status": "active",
      };

      expect(
        () => validateAndNormalizePoint("invalid_type", invalidType),
        throwsFormatException,
      );
    });

    test("rejeita tipos de resíduo não permitidos", () {
      final Map<String, dynamic> invalidWaste = <String, dynamic>{
        "name": "Ponto de Óleo",
        "type": "ecoPoint",
        "latitude": -10.91,
        "longitude": -37.05,
        "address": "Rua Teste, 1 — Centro, Aracaju - SE",
        "acceptedWasteTypes": <String>["cooking_oil"],
        "hours": "Seg a sex, 8h às 18h",
        "status": "active",
      };

      expect(
        () => validateAndNormalizePoint("invalid_waste", invalidWaste),
        throwsFormatException,
      );
    });
  });

  group("Repositório e Persistência Local Offline-First", () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test("upsertLocalPoints é idempotente e insere os 8 pontos sem duplicação", () async {
      final InMemoryLocalStore store = InMemoryLocalStore();
      final CollectPointsRepository repo = CollectPointsRepository(
        localStore: store,
      );

      final List<CollectionPoint> aracajuPoints = kAracajuCollectPointsPayload.entries
          .map((MapEntry<String, Map<String, dynamic>> e) {
            final Map<String, dynamic> norm = validateAndNormalizePoint(
              e.key,
              e.value,
            );
            return CollectionPoint.fromJson(norm);
          })
          .toList();

      // Primeira execução de upsert
      final List<CollectionPoint> firstPass = await repo.upsertLocalPoints(
        aracajuPoints,
      );
      final int countAfterFirstPass = firstPass.length;

      // Todos os 8 pontos estão presentes
      for (final String key in kAracajuCollectPointsPayload.keys) {
        expect(
          firstPass.any((CollectionPoint p) => p.id == key),
          isTrue,
          reason: "Ponto $key deve estar presente após a 1ª inserção.",
        );
      }

      // Segunda execução de upsert com os mesmos pontos (idempotência)
      final List<CollectionPoint> secondPass = await repo.upsertLocalPoints(
        aracajuPoints,
      );

      // Quantidade total deve permanecer exatamente a mesma
      expect(secondPass.length, countAfterFirstPass);

      // O cache persistido foi atualizado com sucesso
      final List<CollectionPoint> loadedFromCache = await repo.loadOffline();
      expect(loadedFromCache.length, countAfterFirstPass);
      expect(repo.sourceOrigin, DataSourceOrigin.localCache);
    });
  });
}
