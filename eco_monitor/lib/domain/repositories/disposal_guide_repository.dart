import "../entities/disposal_guide.dart";
import "../entities/residue.dart";

/// Access contract for the disposal guide content.
///
/// The presentation layer depends only on this interface. Today the
/// implementation is local (in memory); in the future it can be swapped for
/// SQLite / Firestore without changing the screens.
abstract interface class DisposalGuideRepository {
  List<Residue> listResidues();

  /// Step by step of the residue, or `null` if the guide does not exist yet.
  DisposalGuide? stepsGuideFor(ResidueType type);
}
