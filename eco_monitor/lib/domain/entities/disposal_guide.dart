/// A single step of the disposal guide.
class DisposalStep {
  const DisposalStep({required this.title, required this.description});

  final String title;
  final String description;
}

/// Full content of the step-by-step screen of a residue.
class DisposalGuide {
  const DisposalGuide({
    required this.title,
    required this.subtitle,
    required this.warning,
    required this.steps,
  });

  final String title;
  final String subtitle;

  /// Biosafety notice shown at the top of the step list.
  final String warning;
  final List<DisposalStep> steps;
}
