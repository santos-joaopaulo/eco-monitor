import "../domain/entities/disposal_guide.dart";
import "../domain/entities/residue.dart";
import "../domain/repositories/disposal_guide_repository.dart";

/// Local (in memory) implementation of [DisposalGuideRepository].
class DisposalGuideRepositoryLocal implements DisposalGuideRepository {
  const DisposalGuideRepositoryLocal();

  static const List<Residue> _residues = [
    Residue(
      type: ResidueType.medicine,
      title: "Remédios vencidos",
      description: "Comprimidos, xaropes e pomadas. Nunca jogue no lixo comum ou no vaso.",
      minutes: 2,
      totalSteps: 4,
    ),
    Residue(
      type: ResidueType.battery,
      title: "Pilhas e baterias",
      description: "Contêm metais pesados que contaminam solo e água.",
      minutes: 2,
      totalSteps: 4,
    ),
    Residue(
      type: ResidueType.sharps,
      title: "Seringas e agulhas",
      description: "Guarde em recipiente rígido e fechado, como garrafa PET.",
      minutes: 3,
      totalSteps: 5,
    ),
  ];

  static const DisposalGuide _medicineGuide = DisposalGuide(
    title: "Remédios vencidos",
    subtitle: "Siga os passos antes de ir até o ponto.",
    warning: "Não jogue no lixo comum, pia ou vaso sanitário.",

    steps: [
      DisposalStep(
        title: "Separe os medicamentos",
        description: "Junte os vencidos ou que não usa mais.",
      ),
      DisposalStep(
        title: "Mantenha na embalagem",
        description: "Deixe na cartela ou frasco original, se possível.",
      ),
      DisposalStep(
        title: "Caixa e bula no reciclável",
        description: "O papel pode ir para a coleta seletiva.",
      ),
      DisposalStep(
        title: "Leve a uma farmácia",
        description: 'Procure um ponto com o filtro "Remédios".',
      ),
    ],
  );

  @override
  List<Residue> listResidues() => _residues;

  @override
  DisposalGuide? stepsGuideFor(ResidueType type) {
    return switch (type) {
      ResidueType.medicine => _medicineGuide,
      _ => null,
    };
  }
}
