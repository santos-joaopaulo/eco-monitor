/// Um passo do guia de descarte.
class PassoDescarte {
  const PassoDescarte({required this.titulo, required this.descricao});

  final String titulo;
  final String descricao;
}


/// Conteúdo completo da tela passo a passo de um resíduo.
class GuiaPassos {
  const GuiaPassos({
    required this.titulo,
    required this.subtitulo,
    required this.alerta,
    required this.passos,
  });

  final String titulo;
  final String subtitulo;

  /// Aviso de biossegurança exibido no topo da lista de passos.
  final String alerta;
  final List<PassoDescarte> passos;
}
