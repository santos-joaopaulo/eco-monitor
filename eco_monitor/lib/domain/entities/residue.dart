/// Waste categories handled by the disposal guide.
enum ResidueType { medicine, battery, sharps, electronics }

/// Summary of a residue shown in the guide list.
class Residue {
  const Residue({
    required this.type,
    required this.title,
    required this.description,
    required this.minutes,
    required this.totalSteps,
  });

  final ResidueType type;
  final String title;
  final String description;

  /// Estimated time to read the full guide.
  final int minutes;
  final int totalSteps;
}
