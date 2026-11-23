
## [01-09-2026]

### Adicionado

- Análise inicial do estudo de caso.

## [08-09-2026]

### Adicionado

- Análise da pesquisa, benchmark e personas.

## [15-09-2026]

### Adicionado

- Análise das funcionalidades e requisitos.

## [22-09-2026]

### Adicionado

- Desenvolvimento do protótipo de baixa fidelidade.
- Início do desenvolvimento do protótipo de alta fidelidade.

## [29-09-2026]

### Adicionado

- Desenvolvimento da maioria das telas do protótipo de alta fidelidade.
- Início do desenvolvimento da apresentação final.

## [05-10-2026]

### Adicionado

- Finalização das telas do protótipo de alta fidelidade, com ajustes e atualizações.
- Conclusão das atividades propostas para as atividades 4 e 5.
- Entrega de todos os materiais previstos para as atividades.

## [06-10-2026]

### Alterado

- Atualização das responsabilidades da equipe no README.

## [03-11-2026]

### Adicionado

- Estrutura inicial do aplicativo Flutter.
- Esboço das telas principais (home, guia, eventos e sugerir) e barra de navegação inferior.
- Documento de uso de IA com os padrões de codificação do projeto.
- README com resumo do projeto e tutorial de execução, incluindo instruções de Git.

## [10-11-2026]

### Adicionado

- Integração do mapa Mapbox na tela inicial.
- Botão para obter a localização do usuário no mapa.

### Alterado

- Remoção da barra de escala do mapa, para manter a interface limpa.

## [17-11-2026]

### Adicionado

- Tela Guia de Descarte com a lista de resíduos e o tempo estimado de leitura.
- Passo a passo de descarte de remédios vencidos.
- Componentes reutilizáveis da interface (barra inferior, AppBar, cartões e timeline) e camada de dados do guia.
- Filtro por tipo de resíduo ao abrir o mapa a partir do guia.
- Testes do fluxo da aba Guia, do navegador aninhado e do repositório de dados.

### Alterado

- Código do guia padronizado em inglês, mantendo as strings da interface em português.
- Cor primária ajustada para uma variante acessível, com contraste AA.
- Formatação do código alinhada ao `dart format`.

### Corrigido

- Remoção do progresso fictício das pilhas, com aviso de guia indisponível para pilhas e seringas.
- Remoção de prints de debug e substituição do teste de template que falhava.

## [19-11-2026]

### Adicionado

- Marcadores dos pontos de coleta no mapa com pin próprio por tipo (farmácia, UBS, ecoponto) e ocultação dos POIs do estilo Mapbox.
- Filtros por resíduo na tela inicial como pills de seleção múltipla (Remédios, Seringas, Pilhas), com filtragem dos marcadores e estado vazio em português.
- Card de detalhamento do ponto selecionado com tipo, distância, endereço, status, materiais aceitados, horário e botões Cancelar / Iniciar rota.
- Rota aproximada até o ponto (polyline) com painel de Destino, Distância e Tempo estimado, e navegação externa via `url_launcher`.
- Geolocalização do usuário com indicador azul, estados de permissão tratados e avisos de localização com ação.
- Testes de filtragem de pontos, serviço de rota e aviso de localização.
- Formulário completo de sugestão de novo ponto (`SuggestScreen`) com validação de campos obrigatórios, seleção múltipla de resíduos aceitos, horário de funcionamento, captura opcional de GPS e aviso de envio anônimo (`RF10`, `RF11`, `RNF06`).
- Modo de visualização alternativo em lista para pontos de coleta (`CollectPointsListView`) na tela inicial como fallback offline e para cenários de indisponibilidade do mapa (`RF01`, `RF05`, `RNF09`).

### Alterado

- Paleta da tela inicial passou a usar os tokens de `AppColors`/`EcoColors`, sem cores hardcoded fora dos arquivos de tema.
- Largura de conteúdo padronizada pela barra de navegação (`kEcoMaxContentWidth`), aplicada a guia, eventos, passo a passo, filtros, chip de campanha, card do ponto e painel de rota.
- Rota exige conexão: o botão informa quando a rede está indisponível.
- Padronização de formatação de código e comentários estruturais em português em todo o código-fonte e suíte de testes conforme `AGENTS.md`.

### Corrigido

- Inclusão dos esquemas `geo:` e `https:` na tag `<queries>` do `AndroidManifest.xml`, garantindo a abertura de rotas em aplicativos de mapas no Android 11+ (API 30+) (`RF04`, `RNF12`).
- Correção do encerramento abrupto do app na tela raiz do Guia de Descarte, removendo chamada indevida a `SystemNavigator.pop()` ao pressionar voltar no sistema (`RNF01`, `RNF03`).

## [20-11-2026]

### Adicionado

- Reestruturação visual e interativa da tela de sugestão de ponto (`SuggestScreen`), introduzindo o seletor estruturado de horários (`OpeningHoursRow`) e cards de opções de resíduos (`WasteTypeOptionCard`).
- Guia detalhado de execução e build com instruções para configuração do token Mapbox no `README.md`.

### Alterado

- Alinhamento das diretrizes de desenvolvimento, convenções de idioma e normas de comentários de seção no padrão do projeto.
- Início da consolidação dos tokens de cores da interface em substituição a definições locais.

## [21-11-2026]

### Adicionado

- Abstração de persistência local `LocalStore` com implementações real (`SharedPreferences`) e em memória para testes, acompanhada de documento de decisão arquitetural (`docs/adr-persistencia-local.md`).
- Versionamento do envelope de cache offline com migração transparente de formatos legados e fallback gracioso contra corrupção de dados (`RNF09`, `RNF10`).
- Fila offline de sugestões de pontos protegida contra concorrência e perda de atualizações (*lost updates*) através de controle por mutex com cadeia de futuros (`RNF14`).

### Alterado

- Unificação dos enums de resíduos (`ResidueType` e `WasteType`) no enum canônico `WasteType` na camada de domínio, eliminando conversores intermediários redundantes e normalizando os parsers JSON.
- Centralização definitiva de cores na classe `AppColors`, removendo a classe espelho `EcoColors` de `eco_theme.dart` e limpando imports em toda a base de código.
- Modularização do widget `HomeScreen`, particionando responsabilidades em `HomeMapTopBar`, `HomeMapControls` e no mixin `HomeScreenActions`.
- Refatoração de imports de Material Design nos componentes e telas da aplicação.

### Corrigido

- Atualização do identificador do aplicativo Android (`applicationId`) para `br.edu.ufs.ecomonitor`, label do app para "EcoMonitor" e ajuste de configurações de build de release (`RNF12`, `RNF14`).

## [22-11-2026]

### Adicionado

- Navegação híbrida multi-modal (a pé, bicicleta e carro) in-app integrada à Mapbox Directions API (`RF04`), com recálculo em tempo real, stream contínua de GPS, e fallback autônomo offline baseado em rumo cardeal, velocidade média e detecção de chegada (`RNF09`, `RNF10`).
- Configuração e vinculação oficial do projeto Firebase (`eco-monitor-34290`) em produção com credenciais versionadas para Android e iOS, implantação de regras de segurança (`firestore.rules`) e índices no Firestore, e script de seed com verificação (`seed_firestore.dart`) (`RNF11`, `RNF14`, `RNF15`).
- Suíte completa de testes automatizados com cobertura de testes de widget para `HomeScreen` e `SuggestScreen`, além de testes rigorosos de acessibilidade e conformidade WCAG 2.1 AA (contraste matemático, rótulos de Semantics/Tooltips e suporte a escalonamento de texto 1.5x sem overflow) (`RNF04`, `RNF08`, `RNF18`).
- Refinamentos de UX, UI do mapa e controles em dispositivos móveis (Onda 5 do plano de ação):
  - Redesenho do aviso "Sem conexão" (`OfflineBanner`) em estilo pílula flutuante e linha única com contraste suave (`RNF03`, `RNF04`, `RNF10`, `RNF17`).
  - Aumento da escala e contraste gráfico dos marcadores de coleta (`PointPin`) e criação do token `AppColors.routeLine` para traçado de alta visibilidade sob iluminação solar externa (`RF01`, `RF04`, `RNF04`, `RNF18`).
  - Alinhamento de base dos sheets de detalhe do ponto e de rota ao botão principal de localização, com limitação dinâmica de altura (< 44% da tela) para preservar a visão do mapa (`RF03`, `RF04`, `RNF03`, `RNF04`).
  - Ciclo de vida passivo sob demanda do GPS, inicializando o mapa com enquadramento geral sem requisições ou streams prematuras, centralizando no usuário ao tocar no botão principal (`RF02`, `RF14`, `RNF06`, `RNF13`).
  - Padronização visual circular e alinhamento milimétrico do botão de alternância entre mapa e lista (`HomeViewToggleButton`) (`RNF03`, `RNF04`).
  - Transição fluida do modo lista para o mapa ao selecionar um ponto de coleta com animação de câmera e preservação da tela ao dispensar o card (`RF01`, `RF03`, `RNF01`, `RNF03`).
  - Projeção de sombra 3D uniforme em quatro direções na barra inferior flutuante (`CustomBottomNavBar`) (`RNF03`, `RNF04`).
- Carga de dados reais com 35 ecopontos e locais de descarte de Aracaju sincronizados no Firestore e integrados ao dataset local em `collect_points.json`.
- Implementação de painel administrativo simplificado protegido por chave de acesso com hash criptográfico SHA-256 e ativado por gesto secreto na logo (5 toques), permitindo gerenciar pontos de coleta, campanhas e moderar sugestões enviadas pela comunidade.

### Corrigido

- Ajustes de layout responsivo na `HomeScreen`, eliminando conflitos de sobreposição da barra de navegação inferior e fixando a barra de filtros no topo.
