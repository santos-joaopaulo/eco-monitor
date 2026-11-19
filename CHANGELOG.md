
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

### Alterado

- Paleta da tela inicial passou a usar os tokens de `AppColors`/`EcoColors`, sem cores hardcoded fora dos arquivos de tema.
- Largura de conteúdo padronizada pela barra de navegação (`kEcoMaxContentWidth`), aplicada a guia, eventos, passo a passo, filtros, chip de campanha, card do ponto e painel de rota.
- Rota exige conexão: o botão informa quando a rede está indisponível.
