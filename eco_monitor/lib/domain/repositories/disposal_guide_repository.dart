import "../entities/disposal_guide.dart";
import "../entities/residue.dart";

/// Contrato de acesso para o conteúdo do guia de descarte.
///
/// A camada de apresentação depende apenas desta interface. A implementação
/// pode ser local (em memória) ou sincronizada com Firestore sem alterar as telas.
abstract interface class DisposalGuideRepository {
  List<Residue> listResidues();

  /// Passo a passo do resíduo, ou `null` se o guia ainda não existir.
  DisposalGuide? stepsGuideFor(ResidueType type);
}
