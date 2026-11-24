// Enums -------------------------------------------------------------------- //


/// Resultado do envio ou enfileiramento de uma avaliação de ponto (RNF10).
enum PointReviewSubmitResult { sent, queuedOffline }


// Constants ---------------------------------------------------------------- //


/// Tags padronizadas de status rápido para avaliação da qualidade de um ecoponto.
abstract final class PointReviewTags {
  static const String accessibleCollector = "Coletor acessível";
  static const String fullCollector = "Coletor cheio";
  static const String divergentHours = "Horário divergente";
  static const String veryGood = "Muito bom";

  static const List<String> all = <String>[
    accessibleCollector,
    fullCollector,
    divergentHours,
    veryGood,
  ];
}


// Classes ------------------------------------------------------------------ //


/// Avaliação e reporte de qualidade de um ecoponto enviada pelo cidadão (Entidade de Domínio).
class PointReview {
  PointReview({
    required this.id,
    required this.pointId,
    required this.rating,
    required List<String> tags,
    required this.createdAt,
    this.comment = "",
  }) : tags = List<String>.unmodifiable(tags);

  final String id;
  final String pointId;
  final int rating;
  final List<String> tags;
  final DateTime createdAt;
  final String comment;


// Methods ------------------------------------------------------------------ //


  factory PointReview.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? rawTags = json["tags"] as List<dynamic>?;
    final List<String> tags = rawTags != null
        ? rawTags.whereType<String>().toList()
        : const <String>[];

    final Object? rawRating = json["rating"];
    final int rating = rawRating is num ? rawRating.toInt().clamp(1, 5) : 5;

    final Object? rawCreatedAt = json["createdAt"];
    final DateTime createdAt;
    if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return PointReview(
      id: (json["id"] as String?) ?? "",
      pointId: (json["pointId"] as String?) ?? "",
      rating: rating,
      tags: tags,
      createdAt: createdAt,
      comment: (json["comment"] as String?) ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "pointId": pointId,
      "rating": rating,
      "tags": tags,
      "createdAt": createdAt.toIso8601String(),
      if (comment.isNotEmpty) "comment": comment,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is PointReview && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => "PointReview($id, point: $pointId, rating: $rating)";
}

/// Estatísticas consolidadas de avaliações e reportes de um ecoponto.
class PointReviewStats {
  const PointReviewStats({
    required this.pointId,
    required this.averageRating,
    required this.totalReviews,
    this.tagCounts = const <String, int>{},
  });

  final String pointId;
  final double averageRating;
  final int totalReviews;
  final Map<String, int> tagCounts;

  bool get hasReviews => totalReviews > 0;

  /// Retorna as tags mais votadas em ordem decrescente de frequência.
  List<String> get topTags {
    final List<MapEntry<String, int>> entries = tagCounts.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value.compareTo(a.value));
    return entries.map((MapEntry<String, int> e) => e.key).toList();
  }
}
