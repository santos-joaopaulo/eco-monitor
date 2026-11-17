/// Tipos de resíduo atendidos pelo guia de descarte.
enum TipoResiduo { medicamento, pilha, perfurocortante }


/// Resumo de um resíduo exibido na lista do guia.
class Residuo {
  const Residuo({
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.minutos,
    required this.totalPassos,
    this.passosConcluidos = 0,
  });

  final TipoResiduo tipo;
  final String titulo;
  final String descricao;

  /// Tempo estimado para ler o guia completo.
  final int minutos;
  final int totalPassos;
  final int passosConcluidos;

  /// `true` quando o usuário já concluiu parte dos passos.
  bool get emAndamento =>
      passosConcluidos > 0 && passosConcluidos < totalPassos;
}
