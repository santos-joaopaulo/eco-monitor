// Classes ------------------------------------------------------------------ //


/// Um passo individual do guia de descarte.
class DisposalStep {
  const DisposalStep({required this.title, required this.description});

  final String title;
  final String description;


// Methods ------------------------------------------------------------------ //


  factory DisposalStep.fromJson(Map<String, dynamic> json) {
    return DisposalStep(
      title: json["title"] is String ? json["title"] as String : "",
      description: json["description"] is String
          ? json["description"] as String
          : "",
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    "title": title,
    "description": description,
  };
}

/// Conteúdo completo da tela de passo a passo de um resíduo.
class DisposalGuide {
  const DisposalGuide({
    required this.title,
    required this.subtitle,
    required this.warning,
    required this.steps,
  });

  final String title;
  final String subtitle;

  /// Aviso de biossegurança exibido no topo da lista de passos.
  final String warning;
  final List<DisposalStep> steps;


// Methods ------------------------------------------------------------------ //


  factory DisposalGuide.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSteps = switch (json["steps"]) {
      final List<dynamic> values => values,
      _ => const <dynamic>[],
    };

    final List<DisposalStep> steps = rawSteps
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> step) =>
              DisposalStep.fromJson(step.cast<String, dynamic>()),
        )
        .toList();

    return DisposalGuide(
      title: json["title"] is String ? json["title"] as String : "",
      subtitle: json["subtitle"] is String ? json["subtitle"] as String : "",
      warning: json["warning"] is String ? json["warning"] as String : "",
      steps: List<DisposalStep>.unmodifiable(steps),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    "title": title,
    "subtitle": subtitle,
    "warning": warning,
    "steps": steps.map((DisposalStep step) => step.toJson()).toList(),
  };
}
