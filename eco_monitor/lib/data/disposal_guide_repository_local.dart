import "../domain/entities/disposal_guide.dart";
import "../domain/entities/residue.dart";
import "../domain/entities/waste_type.dart";
import "../domain/repositories/disposal_guide_repository.dart";

/// Implementação local (em memória) de [DisposalGuideRepository].
class DisposalGuideRepositoryLocal implements DisposalGuideRepository {
  const DisposalGuideRepositoryLocal();

  static const List<Residue> _residues = [
    Residue(
      type: WasteType.medicines,
      title: "Remédios vencidos",
      description: "Comprimidos, xaropes e pomadas. Nunca jogue no lixo comum ou no vaso.",
      minutes: 2,
      totalSteps: 4,
    ),
    Residue(
      type: WasteType.batteries,
      title: "Pilhas e baterias",
      description: "Contêm metais pesados que contaminam solo e água.",
      minutes: 2,
      totalSteps: 4,
    ),
    Residue(
      type: WasteType.sharps,
      title: "Seringas e agulhas",
      description: "Guarde em recipiente rígido e fechado, como garrafa PET.",
      minutes: 3,
      totalSteps: 5,
    ),
    Residue(
      type: WasteType.electronics,
      title: "Lixo eletrônico",
      description: "Celulares, cabos, carregadores e pequenos aparelhos. Não jogue no lixo comum.",
      minutes: 2,
      totalSteps: 4,
    ),
    Residue(
      type: WasteType.glass,
      title: "Vidro e frascos",
      description: "Frascos de medicamentos, xaropes e ampolas. Higienize e proteja contra quebra.",
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

  static const DisposalGuide _glassGuide = DisposalGuide(
    title: "Frascos de vidro e ampolas",
    subtitle: "Higienize e proteja contra quebra antes de levar ao ponto.",
    warning: "Em caso de frasco quebrado, embale em jornal ou caixa rígida para proteger os coletores.",

    steps: [
      DisposalStep(
        title: "Esvazie e higienize o frasco",
        description: "Retire restos de medicamento líquido e enxágue levemente com água.",
      ),
      DisposalStep(
        title: "Separe tampas e bulas",
        description: "Tampas plásticas/metálicas e caixas de papel devem ir para a coleta seletiva correspondente.",
      ),
      DisposalStep(
        title: "Proteja contra quebra",
        description: "Embale frascos ou cacos em caixa rígida ou folhas de jornal e vede com fita adesiva.",
      ),
      DisposalStep(
        title: "Leve ao ecoponto ou farmácia",
        description: 'Entregue em um ponto de coleta com coletor para frascos ou filtro "Vidro".',
      ),
    ],
  );

  @override
  List<Residue> listResidues() => _residues;

  @override
  DisposalGuide? stepsGuideFor(WasteType type) {
    return switch (type) {
      WasteType.medicines => _medicineGuide,
      WasteType.batteries => _batteryGuide,
      WasteType.sharps => _sharpsGuide,
      WasteType.electronics => null, // Guia desabilitado.
      WasteType.glass => _glassGuide,
    };
  }
}
