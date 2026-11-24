import "../domain/entities/collection_point.dart";
import "../domain/entities/point_suggestion.dart";
import "../domain/entities/waste_type.dart";


// Enums ------------------------------------------------------------------- //


/// Nível de carência territorial calculado para um bairro ou localidade.
enum ShortageLevel { high, medium, low }


// Classes ----------------------------------------------------------------- //


/// Demanda quantitativa e percentual para uma categoria específica de resíduo.
class CivicWasteDemand {
  const CivicWasteDemand({
    required this.type,
    required this.count,
    required this.percentage,
  });

  final WasteType type;
  final int count;
  final double percentage;
}

/// Diagnóstico e demanda cívica agregada para um bairro territorial específico.
class NeighborhoodCivicDemand {
  const NeighborhoodCivicDemand({
    required this.neighborhood,
    required this.suggestions,
    required this.totalSuggestions,
    required this.pendingCount,
    required this.reviewingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.activePointsCount,
    required this.shortageScore,
    required this.rankedWastes,
  });

  final String neighborhood;
  final List<PointSuggestion> suggestions;
  final int totalSuggestions;
  final int pendingCount;
  final int reviewingCount;
  final int approvedCount;
  final int rejectedCount;
  final int activePointsCount;
  final double shortageScore;
  final List<CivicWasteDemand> rankedWastes;


  // Getters --------------------------------------------------------------- //


  ShortageLevel get shortageLevel {
    if (shortageScore >= 3.0 || (pendingCount >= 2 && activePointsCount == 0)) {
      return ShortageLevel.high;
    }
    if (shortageScore >= 1.5 || totalSuggestions >= 2) {
      return ShortageLevel.medium;
    }
    return ShortageLevel.low;
  }

  String get shortageLevelLabel => switch (shortageLevel) {
    ShortageLevel.high => "Alta Carência",
    ShortageLevel.medium => "Média Carência",
    ShortageLevel.low => "Baixa Carência",
  };

  WasteType? get topRequestedWaste {
    if (rankedWastes.isEmpty) {
      return null;
    }
    return rankedWastes.first.type;
  }


  // Methods --------------------------------------------------------------- //


  double wastePercentage(WasteType type) {
    for (final CivicWasteDemand item in rankedWastes) {
      if (item.type == type) {
        return item.percentage;
      }
    }
    return 0.0;
  }

  int statusCount(SuggestionStatus status) => switch (status) {
    SuggestionStatus.pending => pendingCount,
    SuggestionStatus.reviewing => reviewingCount,
    SuggestionStatus.approved => approvedCount,
    SuggestionStatus.rejected => rejectedCount,
  };
}

/// Sumário analítico consolidado de demandas cívicas e carência territorial.
class CivicDemandSummary {
  const CivicDemandSummary({
    required this.neighborhoodDemands,
    required this.totalSuggestions,
    required this.pendingCount,
    required this.reviewingCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.overallRankedWastes,
    required this.generatedAt,
  });

  final List<NeighborhoodCivicDemand> neighborhoodDemands;
  final int totalSuggestions;
  final int pendingCount;
  final int reviewingCount;
  final int approvedCount;
  final int rejectedCount;
  final List<CivicWasteDemand> overallRankedWastes;
  final DateTime generatedAt;


  // Factory --------------------------------------------------------------- //


  /// Processa e agrupa a lista de sugestões cívicas por bairro territorial,
  /// calculando carência e ranqueamento de resíduos.
  factory CivicDemandSummary.fromData({
    required List<PointSuggestion> suggestions,
    List<CollectionPoint> existingPoints = const <CollectionPoint>[],
    DateTime? now,
  }) {
    final DateTime timestamp = now ?? DateTime.now();

    final Map<String, List<PointSuggestion>> suggestionsByNeighborhood =
        <String, List<PointSuggestion>>{};

    int pending = 0;
    int reviewing = 0;
    int approved = 0;
    int rejected = 0;

    final Map<WasteType, int> globalWasteCounts = <WasteType, int>{};

    for (final PointSuggestion s in suggestions) {
      final String neighborhood = extractNeighborhood(s.address);
      (suggestionsByNeighborhood[neighborhood] ??= <PointSuggestion>[]).add(s);

      switch (s.status) {
        case SuggestionStatus.pending:
          pending++;
        case SuggestionStatus.reviewing:
          reviewing++;
        case SuggestionStatus.approved:
          approved++;
        case SuggestionStatus.rejected:
          rejected++;
      }

      for (final WasteType type in s.acceptedWasteTypes) {
        globalWasteCounts[type] = (globalWasteCounts[type] ?? 0) + 1;
      }
    }

    // Mapeamento de pontos de coleta ativos por bairro
    final Map<String, int> activePointsByNeighborhood = <String, int>{};
    for (final CollectionPoint p in existingPoints) {
      if (p.isActive) {
        final String n = extractNeighborhood(p.address).toLowerCase();
        activePointsByNeighborhood[n] =
            (activePointsByNeighborhood[n] ?? 0) + 1;
      }
    }

    final List<NeighborhoodCivicDemand> neighborhoodDemands =
        <NeighborhoodCivicDemand>[];

    for (final MapEntry<String, List<PointSuggestion>> entry
        in suggestionsByNeighborhood.entries) {
      final String neighborhoodName = entry.key;
      final List<PointSuggestion> items = entry.value;

      int nPending = 0;
      int nReviewing = 0;
      int nApproved = 0;
      int nRejected = 0;
      final Map<WasteType, int> nWasteCounts = <WasteType, int>{};

      for (final PointSuggestion s in items) {
        switch (s.status) {
          case SuggestionStatus.pending:
            nPending++;
          case SuggestionStatus.reviewing:
            nReviewing++;
          case SuggestionStatus.approved:
            nApproved++;
          case SuggestionStatus.rejected:
            nRejected++;
        }

        for (final WasteType type in s.acceptedWasteTypes) {
          nWasteCounts[type] = (nWasteCounts[type] ?? 0) + 1;
        }
      }

      final int activePoints =
          activePointsByNeighborhood[neighborhoodName.toLowerCase()] ?? 0;

      // Cálculo de Carência Territorial:
      // Pedidos pendentes geram maior pressão cívica (peso 2.0);
      // Pedidos em análise (peso 1.5) e total de pedidos (peso 0.5);
      // Pontos ativos existentes atenuam a carência proporcionalmente.
      final double demandWeight =
          (nPending * 2.0) +
          (nReviewing * 1.5) +
          (nApproved * 1.0) +
          (items.length * 0.5);
      final double mitigationFactor = 1.0 + (activePoints * 1.5);
      final double shortageScore = demandWeight / mitigationFactor;

      final int totalWastesInNeighborhood = nWasteCounts.values.fold(
        0,
        (int sum, int val) => sum + val,
      );

      final List<CivicWasteDemand> rankedWastes = WasteType.values
          .where((WasteType t) => nWasteCounts.containsKey(t))
          .map((WasteType t) {
            final int count = nWasteCounts[t] ?? 0;
            final double pct =
                totalWastesInNeighborhood > 0
                    ? (count / totalWastesInNeighborhood) * 100.0
                    : 0.0;
            return CivicWasteDemand(type: t, count: count, percentage: pct);
          })
          .toList()
        ..sort((CivicWasteDemand a, CivicWasteDemand b) {
          final int cmp = b.count.compareTo(a.count);
          if (cmp != 0) {
            return cmp;
          }
          return a.type.index.compareTo(b.type.index);
        });

      neighborhoodDemands.add(
        NeighborhoodCivicDemand(
          neighborhood: neighborhoodName,
          suggestions: items,
          totalSuggestions: items.length,
          pendingCount: nPending,
          reviewingCount: nReviewing,
          approvedCount: nApproved,
          rejectedCount: nRejected,
          activePointsCount: activePoints,
          shortageScore: shortageScore,
          rankedWastes: rankedWastes,
        ),
      );
    }

    // Ordenação de prioridade de carência territorial decrescente
    neighborhoodDemands.sort(
      (NeighborhoodCivicDemand a, NeighborhoodCivicDemand b) {
        final int scoreCmp = b.shortageScore.compareTo(a.shortageScore);
        if (scoreCmp != 0) {
          return scoreCmp;
        }
        final int pendingCmp = b.pendingCount.compareTo(a.pendingCount);
        if (pendingCmp != 0) {
          return pendingCmp;
        }
        final int totalCmp = b.totalSuggestions.compareTo(a.totalSuggestions);
        if (totalCmp != 0) {
          return totalCmp;
        }
        return a.neighborhood.toLowerCase().compareTo(
          b.neighborhood.toLowerCase(),
        );
      },
    );

    final int totalGlobalWastes = globalWasteCounts.values.fold(
      0,
      (int sum, int val) => sum + val,
    );

    final List<CivicWasteDemand> overallRankedWastes = WasteType.values
        .where((WasteType t) => globalWasteCounts.containsKey(t))
        .map((WasteType t) {
          final int count = globalWasteCounts[t] ?? 0;
          final double pct =
              totalGlobalWastes > 0
                  ? (count / totalGlobalWastes) * 100.0
                  : 0.0;
          return CivicWasteDemand(type: t, count: count, percentage: pct);
        })
        .toList()
      ..sort((CivicWasteDemand a, CivicWasteDemand b) {
        final int cmp = b.count.compareTo(a.count);
        if (cmp != 0) {
          return cmp;
        }
        return a.type.index.compareTo(b.type.index);
      });

    return CivicDemandSummary(
      neighborhoodDemands: neighborhoodDemands,
      totalSuggestions: suggestions.length,
      pendingCount: pending,
      reviewingCount: reviewing,
      approvedCount: approved,
      rejectedCount: rejected,
      overallRankedWastes: overallRankedWastes,
      generatedAt: timestamp,
    );
  }


  // Methods --------------------------------------------------------------- //


  NeighborhoodCivicDemand? demandFor(String neighborhood) {
    final String target = neighborhood.trim().toLowerCase();
    for (final NeighborhoodCivicDemand demand in neighborhoodDemands) {
      if (demand.neighborhood.trim().toLowerCase() == target) {
        return demand;
      }
    }
    return null;
  }

  /// Extrai o nome do bairro a partir de uma string de endereço comum em Aracaju.
  static String extractNeighborhood(String address) {
    final String trimmed = address.trim();
    if (trimmed.isEmpty) {
      return "Não informado";
    }

    // Padrão com hífen: "Rua X, 123 - Centro, Aracaju" ou "Rua X - Centro"
    if (trimmed.contains(" - ")) {
      final List<String> segments = trimmed.split(" - ");
      if (segments.length >= 2) {
        final String candidate = segments[1].split(",").first.trim();
        if (candidate.isNotEmpty) {
          return candidate;
        }
      }
    }

    // Padrão com vírgula: "Rua X, 123, Centro, Aracaju"
    final List<String> commaParts = trimmed.split(",");
    if (commaParts.length >= 3) {
      final String candidate = commaParts[commaParts.length - 2].trim();
      if (candidate.isNotEmpty && !RegExp(r"^\d+$").hasMatch(candidate)) {
        return candidate;
      }
    }

    return trimmed;
  }
}
