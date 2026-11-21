// Layout constants -------------------------------------------------------- //



/// Largura máxima de uma superfície de conteúdo centralizada em telas largas (tablet / web).
///
/// Superfícies full-bleed, como o mapa e a barra superior, são isentas. Cards,
/// modais, filtros e outros componentes flutuantes usam esta mesma largura de superfície
/// para que o layout preserve uma largura de leitura confortável semelhante à de um smartphone.
const double kEcoMaxContentWidth = 500;

/// Margem horizontal entre a superfície de conteúdo centralizada e as bordas da tela.
const double kEcoContentHorizontalPadding = 16;
