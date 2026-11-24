# Fluxo de Navegação

Este documento mostra como as telas do EcoMonitor se conectam na prática, de acordo com o código atual (`lib/main.dart`, `lib/screens` e `lib/widgets`).

## Estrutura geral

O app tem uma **casca única** (`MyHomePage`) com uma barra de navegação inferior (`CustomBottomNavBar`) e quatro abas mantidas em um `IndexedStack`. Trocar de aba não destrói a tela anterior, então o mapa, os filtros e o formulário mantêm o estado.

| Índice | Aba (rótulo) | Tela | Título da barra superior |
|---|---|---|---|
| 0 | home | `HomeScreen` | ECOMONITOR |
| 1 | guia | `GuideNavigator` → `DisposalGuideScreen` | Própria de cada tela do guia |
| 2 | eventos | `EventsScreen` | CAMPANHAS ATIVAS |
| 3 | sugerir | `SuggestScreen` | SUGERIR NOVO PONTO |

A aba **guia** tem um `Navigator` próprio (aninhado). Por isso, abrir o passo a passo não esconde a barra inferior, e o botão voltar do Android primeiro fecha o passo a passo e depois leva para a aba home, sem fechar o app.

O **painel administrativo** fica fora das abas: é aberto por um gesto secreto na barra superior e empilhado sobre o app com `Navigator.push`.

## Diagramas de navegação

Para ficar legível, a navegação foi dividida em um diagrama geral e um diagrama para cada aba e para o painel administrativo.

### Visão geral

```mermaid
flowchart TD
    start(["Abertura do app"]) --> shell["MyHomePage<br/>barra inferior + IndexedStack"]

    shell --> home["Aba home<br/>HomeScreen"]
    shell --> guia["Aba guia<br/>GuideNavigator"]
    shell --> eventos["Aba eventos<br/>EventsScreen"]
    shell --> sugerir["Aba sugerir<br/>SuggestScreen"]
    shell -->|"gesto secreto na<br/>barra superior"| admin["Painel administrativo"]

    guia -->|"Ver pontos no mapa"| home
    eventos -->|"Ver no mapa"| home
```

### Aba home: mapa, busca e filtros

```mermaid
flowchart TD
    home["HomeScreen<br/>mapa Mapbox + barra superior"]
    lista["CollectPointsListView<br/>coração de favorito e nota média"]
    busca[/"Busca de resíduo<br/>ex.: pilha, xarope"/]
    filtro[/"FilterBar<br/>tipos de resíduo + Favoritos"/]
    sheet["CollectPointSheet"]
    rota["RouteSummaryCard"]

    home <-->|"botão mapa/lista<br/>(lista automática sem token)"| lista
    home -->|digita na busca| busca
    busca -->|"escolhe o resíduo: aplica o filtro<br/>e seleciona o ponto mais próximo"| sheet
    home -->|toca em um filtro| filtro
    filtro -->|mapa atualizado| home
    home -->|"atalho Ponto mais próximo<br/>(1 toque)"| rota
    home -->|toca em um pino| sheet
    lista -->|toca em um ponto| sheet
```

### Aba home: detalhes do ponto e rota

```mermaid
flowchart TD
    sheet["CollectPointSheet<br/>materiais aceitos e horário"]
    fav[/"Favoritar ou desfavoritar"/]
    avaliar["Avaliação do ecoponto<br/>nota de 1 a 5 + tags"]
    enviada[/"Avaliação enviada"/]
    filaAv[/"Avaliação na fila local<br/>enviada ao reconectar"/]
    rota["RouteSummaryCard<br/>a pé, bicicleta ou carro"]
    externo[["App de mapas do aparelho"]]
    home(["Mapa"])

    sheet -->|toca no coração| fav
    sheet -->|envia avaliação| avaliar
    avaliar -->|online| enviada
    avaliar -->|offline| filaAv
    sheet -->|Iniciar rota| rota
    sheet -->|Cancelar| home
    rota -->|App externo| externo
    rota -->|encerra a rota| home
```

### Aba guia

```mermaid
flowchart TD
    guia["DisposalGuideScreen<br/>busca + ranking dos mais buscados<br/>+ lista de resíduos"]
    passos["DisposalStepByStepScreen<br/>passo a passo + aviso"]
    aviso[/"Aviso: guia indisponível"/]
    homeFiltro["Aba home<br/>mapa filtrado pelo resíduo"]

    guia -->|"busca por texto e<br/>escolhe o resíduo"| passos
    guia -->|toca em um resíduo| passos
    guia -.->|sem conteúdo| aviso
    passos -->|voltar| guia
    passos -->|Ver pontos no mapa| homeFiltro
```

### Aba eventos

```mermaid
flowchart TD
    eventos["EventsScreen<br/>filtros: Todas, Ativas, Programadas"]
    detalhes["CampaignDetailsSheet"]
    lembrete[/"Lembrete ativado:<br/>notificação 24 h antes e às 08:00 do dia"/]
    homeCampanha["Aba home<br/>mapa focado na campanha"]

    eventos -->|toca em uma campanha| detalhes
    eventos -->|Ver local no card| homeCampanha
    eventos -->|lembrete no card| lembrete
    detalhes -->|Definir lembrete| lembrete
    detalhes -->|Ver no mapa| homeCampanha
    detalhes -->|Fechar| eventos
```

### Aba sugerir

```mermaid
flowchart TD
    sugerir["SuggestScreen<br/>nome, endereço, resíduos e horários"]
    gps[/"Captura de coordenadas pelo GPS"/]
    ok[/"Sugestão enviada ao Firestore"/]
    fila[/"Sugestão na fila local<br/>enviada ao reconectar"/]

    sugerir -.->|opcional| gps
    sugerir -->|"Enviar sugestão (online)"| ok
    sugerir -->|"Enviar sugestão (offline)"| fila
```

### Painel administrativo

```mermaid
flowchart TD
    gesto(["Toque + toque mantido 3 s<br/>na barra superior"]) --> check{"Aparelho já<br/>autorizado?"}
    check -->|não| chave["AdminKeyScreen"]
    check -->|sim| dash["AdminDashboardScreen"]
    chave -->|chave correta| dash
    chave -.->|5 erros| bloqueio[/"Bloqueio de 30 s"/]

    dash --> pontos["AdminPointsScreen"]
    dash --> sugestoes["AdminSuggestionsScreen"]
    dash --> campanhas["AdminCampaignsScreen"]
    dash -->|Bloquear Painel| app(["Volta ao app"])

    pontos -->|novo ou editar| formPonto["AdminPointFormScreen"]
    sugestoes -->|Converter em ponto| formPonto
    campanhas -->|nova ou editar| formCamp["AdminCampaignFormScreen"]
```

## Fluxos principais

### 1. Encontrar um ponto e ir até ele (RF01–RF04, RF14)
`home` → mapa com os pontos → toque no pino → `CollectPointSheet` → **Iniciar rota** → `RouteSummaryCard` (escolha do modo e distância/tempo) → opcionalmente **App externo**.

Atalho: o botão de **ponto mais próximo** na barra superior faz tudo em um toque. Ele pede a localização (se ainda não tiver), seleciona o ponto ativo mais próximo compatível com o filtro e já inicia a rota.

### 1.1 Buscar um resíduo pelo nome
Na barra superior do mapa, o usuário digita um termo popular (ex.: “pilha”, “xarope”). Ao escolher o resíduo, o mapa é filtrado e, se a localização estiver disponível, o ponto compatível mais próximo é selecionado.

### 1.2 Favoritar e avaliar um ponto
No `CollectPointSheet` (ou no card da lista), o coração adiciona o ponto aos favoritos. O filtro **Favoritos** da `FilterBar` mostra só esses pontos. No mesmo card, a seção **Avaliação do ecoponto** permite dar nota de 1 a 5 e marcar tags como “Coletor cheio”. Sem internet, a avaliação fica na fila e é enviada depois.

### 2. Do guia ao ponto de coleta (RF06, RF07, RF12, RF13)
`guia` → `DisposalGuideScreen` (com busca por texto e ranking dos resíduos mais buscados) → escolhe o resíduo → `DisposalStepByStepScreen` → **Ver pontos no mapa** → o app fecha o passo a passo, troca para a aba `home` e aplica o filtro daquele resíduo no mapa. O filtro pode ser removido na própria `FilterBar`.

### 3. Da campanha ao mapa (RF08, RF09)
`eventos` → escolhe o filtro (Todas, Ativas ou Programadas) → toca na campanha → `CampaignDetailsSheet` → **Ver no mapa** → aba `home` centralizada no local da campanha. O botão **Ver local** do card faz o mesmo sem abrir os detalhes.

### 3.1 Lembrete de campanha
No card ou nos detalhes da campanha, **Definir lembrete** agenda duas notificações no aparelho: 24 horas antes do início e às 08:00 do dia de início. Tocar de novo cancela o lembrete.

### 4. Sugerir um novo ponto (RF10, RF11)
`sugerir` → preenche nome, endereço, tipos de resíduo e horários (opcionalmente captura as coordenadas pelo GPS) → **Enviar sugestão**. Com internet, a sugestão vai direto para o Firestore. Sem internet, fica na fila local; o banner superior mostra quantas estão pendentes e o envio acontece sozinho quando a conexão volta.

### 5. Administração (RNF11)
Gesto secreto na barra superior → `AdminKeyScreen` (ou direto no `AdminDashboardScreen` se o aparelho já foi autorizado) → gerenciar **pontos**, **campanhas** ou **sugestões**. Os formulários devolvem `true` ao salvar, e a lista anterior recarrega os dados. O botão **Bloquear Painel** revoga a autorização do aparelho e volta para o app. O painel também permite forçar a sincronização dos dados com o banco.

## Elementos presentes em todas as abas

- **`EcoAppBar`**: barra superior com o título da aba e a área do gesto secreto do painel.
- **`OfflineBanner`**: aviso em forma de pílula logo abaixo da barra superior. Aparece quando não há conexão, quando os dados estão desatualizados ou quando há sugestões na fila, e permite tentar sincronizar de novo.
- **`CustomBottomNavBar`**: barra inferior flutuante com as quatro abas.
