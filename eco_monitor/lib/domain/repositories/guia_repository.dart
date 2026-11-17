import "../entities/guia_passos.dart";
import "../entities/residuo.dart";


/// Contrato de acesso ao conteúdo do guia de descarte.
///
/// A camada de apresentação depende apenas desta interface. Hoje a
/// implementação é local (em memória); no futuro pode ser trocada por
/// SQLite / Firestore sem alterar as telas.
abstract interface class GuiaRepository {
  List<Residuo> listarResiduos();

  /// Passo a passo do resíduo, ou `null` se o guia ainda não existe.
  GuiaPassos? guiaPassosDe(TipoResiduo tipo);
}
