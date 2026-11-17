import "../domain/entities/guia_passos.dart";
import "../domain/entities/residuo.dart";
import "../domain/repositories/guia_repository.dart";


/// Implementação local (em memória) do [GuiaRepository].
class GuiaRepositoryLocal implements GuiaRepository {
  const GuiaRepositoryLocal();

  static const List<Residuo> _residuos = [
    Residuo(
      tipo: TipoResiduo.medicamento,
      titulo: "Remédios vencidos",
      descricao:
          "Comprimidos, xaropes e pomadas. Nunca jogue no lixo comum ou no vaso.",
      minutos: 2,
      totalPassos: 4,
    ),
    Residuo(
      tipo: TipoResiduo.pilha,
      titulo: "Pilhas e baterias",
      descricao: "Contêm metais pesados que contaminam solo e água.",
      minutos: 2,
      totalPassos: 4,
      passosConcluidos: 2,
    ),
    Residuo(
      tipo: TipoResiduo.perfurocortante,
      titulo: "Seringas e agulhas",
      descricao: "Guarde em recipiente rígido e fechado, como garrafa PET.",
      minutos: 3,
      totalPassos: 5,
    ),
  ];

  static const GuiaPassos _guiaMedicamentos = GuiaPassos(
    titulo: "Remédios vencidos",
    subtitulo: "Siga os passos antes de ir até o ponto.",
    alerta: "Não jogue no lixo comum, pia ou vaso sanitário.",
    passos: [
      PassoDescarte(
        titulo: "Separe os medicamentos",
        descricao: "Junte os vencidos ou que não usa mais.",
      ),
      PassoDescarte(
        titulo: "Mantenha na embalagem",
        descricao: "Deixe na cartela ou frasco original, se possível.",
      ),
      PassoDescarte(
        titulo: "Caixa e bula no reciclável",
        descricao: "O papel pode ir para a coleta seletiva.",
      ),
      PassoDescarte(
        titulo: "Leve a uma farmácia",
        descricao: 'Procure um ponto com o filtro "Remédios".',
      ),
    ],
  );

  @override
  List<Residuo> listarResiduos() => _residuos;

  @override
  GuiaPassos? guiaPassosDe(TipoResiduo tipo) {
    return switch (tipo) {
      TipoResiduo.medicamento => _guiaMedicamentos,
      _ => null,
    };
  }
}
