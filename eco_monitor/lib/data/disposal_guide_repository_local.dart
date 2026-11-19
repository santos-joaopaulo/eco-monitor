import "../domain/entities/disposal_guide.dart";
import "../domain/entities/residue.dart";
import "../domain/repositories/disposal_guide_repository.dart";

/// Implementação local (em memória) de [DisposalGuideRepository].
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
    Residue(
      type: ResidueType.electronics,
      title: "Lixo eletrônico",
      description: "Celulares, cabos, carregadores e pequenos aparelhos. Não jogue no lixo comum.",
      minutes: 2,
      totalSteps: 4,
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

  static const DisposalGuide _batteryGuide = DisposalGuide(
    title: "Pilhas e baterias",
    subtitle: "Siga os passos antes de ir até o ponto.",
    warning: "Não perfure, amasse, queime ou jogue no lixo comum: há risco de vazamento tóxico.",

    steps: [
      DisposalStep(
        title: "Separe do lixo comum",
        description: "Guarde pilhas e baterias usadas em local seco, fresco e ventilado.",
      ),
      DisposalStep(
        title: "Isole os polos",
        description: "Cubra os terminais de baterias com fita adesiva para evitar curto-circuito.",
      ),
      DisposalStep(
        title: "Embale itens danificados",
        description: "Se houver ferrugem ou vazamento, coloque em um saco plástico bem fechado.",
      ),
      DisposalStep(
        title: "Leve a um ponto de coleta",
        description: 'Procure um local com o filtro "Pilhas e baterias".',
      ),
    ],
  );

  static const DisposalGuide _sharpsGuide = DisposalGuide(
    title: "Seringas e agulhas",
    subtitle: "Siga os passos com cuidado para evitar acidentes.",
    warning: "Risco biológico (ANVISA Grupo E): nunca reencape agulhas nem misture com remédios.",

    steps: [
      DisposalStep(
        title: "Não reencape nem quebre",
        description:
            "Evite recolocar a tampa ou entortar a agulha para não se ferir.",
      ),
      DisposalStep(
        title: "Separe de outros resíduos",
        description: "Nunca misture perfurocortantes com medicamentos, recicláveis ou lixo comum.",
      ),
      DisposalStep(
        title: "Use um recipiente rígido",
        description: "Prefira caixa coletora (Descarpack) ou garrafa PET resistente de boca estreita.",
      ),
      DisposalStep(
        title: "Feche e identifique",
        description: 'Preencha até dois terços, tampe bem e escreva "Perfurocortantes" no frasco.',
      ),
      DisposalStep(
        title: "Entregue em uma UBS",
        description: 'Leve o recipiente fechado a um ponto com o filtro "Seringas e agulhas".',
      ),
    ],
  );

  static const DisposalGuide _electronicsGuide = DisposalGuide(
    title: "Lixo eletrônico",
    subtitle: "Siga os passos antes de ir até o ponto.",
    warning: "Não desmonte aparelhos nem jogue no lixo comum: eles contêm substâncias tóxicas.",

    steps: [
      DisposalStep(
        title: "Apague seus dados",
        description: "Faça backup, remova chips e cartões de memória e restaure o aparelho de fábrica.",
      ),
      DisposalStep(
        title: "Retire pilhas e baterias",
        description: "Se forem removíveis, separe pilhas ou baterias para o coletor específico.",
      ),
      DisposalStep(
        title: "Reúna cabos e acessórios",
        description: "Junte carregadores, fones e pequenos aparelhos sem quebrar ou abrir as peças.",
      ),
      DisposalStep(
        title: "Leve a um ecoponto",
        description: 'Procure um ponto com o filtro "Lixo eletrônico".',
      ),
    ],
  );

  @override
  List<Residue> listResidues() => _residues;

  @override
  DisposalGuide? stepsGuideFor(ResidueType type) {
    return switch (type) {
      ResidueType.medicine => _medicineGuide,
      ResidueType.battery => _batteryGuide,
      ResidueType.sharps => _sharpsGuide,
      ResidueType.electronics => _electronicsGuide,
    };
  }
}
