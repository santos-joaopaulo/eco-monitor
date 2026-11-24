# Registro de Uso de IA — EcoMonitor

Este documento registra como o grupo usou assistentes de IA generativa (LLMs) no desenvolvimento do EcoMonitor: os prompts que deram melhor resultado, os erros que a IA gerou e como cada um foi resolvido, e a justificativa das bibliotecas escolhidas.

A IA foi usada como **apoio**, e não como autora final. Todo código gerado passou por revisão do grupo, execução em dispositivo e pela suíte de testes automatizados (40 arquivos em `eco_monitor/test`).

## 1. Onde a IA foi usada

| Área | Uso |
|---|---|
| Arquitetura | Separação em camadas (`domain`, `data`, `presentation`, `screens`, `widgets`, `services`), contratos de repositório (`I*Repository`), casos de uso e estratégia offline-first. |
| Gerência de estado | Migração para Provider com notifiers por funcionalidade (pontos, campanhas, favoritos, lembretes, localização e sincronização). |
| Novas funcionalidades | Favoritos, avaliação de pontos, lembretes de campanha com notificação local, busca de resíduos por sinônimos e ranking de buscas. |
| Telas e componentes | Primeiras versões de telas e widgets a partir dos protótipos de alta fidelidade, depois ajustadas pelo grupo. |
| Integração Firebase | Leitura/escrita no Firestore, normalização de tipos (`Timestamp`, `GeoPoint`), regras e índices, script de seed. |
| Mapa e rotas | Integração com `mapbox_maps_flutter`, cálculo de rota pela Directions API e fallback offline. |
| Testes | Geração de testes de unidade, de widget e de acessibilidade (WCAG 2.1 AA). |
| Documentação | Revisão de texto do CHANGELOG, README e documentos de requisitos. |

## 2. Prompts mais eficientes

Os melhores resultados vieram de prompts que davam **contexto do projeto**, **requisito de referência**, **restrições** e **critério de aceite**. Prompts genéricos (“crie uma tela de mapa”) geravam código fora do padrão e que ignorava o funcionamento offline.

### 2.1 Padrões de codificação enviados no contexto

Estes padrões devem ser fornecidos ao LLM ao solicitar geração ou modificação de código Dart/Flutter.


#### Idioma

- Todo o código (identificadores, nomes de variáveis, classes, métodos) deve ser escrito em **inglês**.
- Comentários devem ser escritos em **português**.
- Exceção: strings exibidas ao usuário (labels, tooltips, textos de UI) devem ser em **português**.


#### Strings

- Preferir aspas duplas (`"`) sobre aspas simples (`'`).
- Exceção: strings que contêm aspas duplas internas podem usar aspas simples.


#### Comentários

- **Não** incluir comentários padrão do framework (explicações educacionais de `setState`, `build`, widgets de layout, "TRY THIS", etc.).
- Adicionar comentários **apenas** para lógica importante ou decisões não óbvias — evitar comentários excessivos ou descritivos.
- Comentários devem ser escritos em **português**.
- **Manter** comentários de estrutura que organizam o arquivo, com **duas linhas em branco acima e abaixo** e 80 caractéres no total, somente esse tipo de comentário deve ser escrito em **inglês**, seguindo o formato:

```dart


// Section name ------------------------------------------------------------ //


```

- Exemplos:

```dart


// Init -------------------------------------------------------------------- //


// Classes ----------------------------------------------------------------- //


// Methods ----------------------------------------------------------------- //


```

- Se durante o trabalho em um arquivo forem observadas violações desses padrões, **corrigi-las** — mantendo o foco na tarefa atual.


#### Quebras de Linha

- Propriedades escalares simples (valores únicos, sem widget filho) ficam **agrupadas** sem quebra de linha:

```dart
backgroundColor: Colors.white,
centerTitle: true,
```

- Antes de um **widget filho complexo** (múltiplas linhas, aninhado), inserir uma **linha em branco**:

```dart
centerTitle: true,

leading: const Padding(
  padding: EdgeInsets.only(left: 24),
  child: SizedBox(
    width: 24,
    height: 24,
    child: Image(image: AssetImage('assets/logo.png')),
  ),
),

title: Text(
  widget.title,
  style: const TextStyle(color: Colors.white),
),
```

- Entre **propriedades principais** de um widget pai (`appBar`, `body`, `floatingActionButton`), inserir uma **linha em branco**:

```dart
appBar: AppBar(
  // ...
),

body: Center(
  // ...
),

floatingActionButton: FloatingActionButton(
  // ...
),
```


### 2.2 Estrutura de prompt que funcionou melhor

```text
Contexto: app Flutter EcoMonitor (descarte de resíduos), offline-first, sem login.
Arquivos relevantes: <cole os arquivos ou trechos>.
Requisito: <RFxx / RNFxx e descrição>.
Tarefa: <o que deve ser feito, em um único objetivo>.
Restrições: siga os padrões de codificação acima; não altere a API pública de <classe>;
não adicione dependências sem justificar.
Critério de aceite: <comportamento esperado> + testes em test/<arquivo>_test.dart.
```

### 2.3 Exemplos de prompts usados

**Repositório offline-first**

```text
Crie o CampaignsRepository seguindo o mesmo padrão do CollectPointsRepository:
1) tenta o Firestore (coleção "campaigns"); 2) grava cache JSON versionado no
SharedPreferences; 3) sem rede e sem cache, carrega assets/data/campaigns.json.
Exponha isStale considerando validade de 1 dia (RNF10, RNF17).
Os modelos não podem importar cloud_firestore: use normalizeFirestoreData.
Inclua testes com um fetcher falso e InMemoryLocalStore.
```

**Fila offline de sugestões**

```text
O PointSuggestionsRepository perde sugestões quando submit() e flushPending()
rodam ao mesmo tempo. Implemente exclusão mútua sem pacotes externos
(cadeia de Futures) e escreva um teste que dispare 10 envios concorrentes
e verifique que nenhum se perde (RNF14).
```

**Parsing tolerante**

```text
Escreva CollectionPoint.fromJson tolerando campos ausentes. Regra de negócio:
um status desconhecido nunca pode aparecer como ativo (use inactive), tipo de
ponto desconhecido vira ecoPoint e tipos de resíduo desconhecidos são ignorados.
Aceite também os nomes antigos no singular (medicine, battery, electronic).
```

**Painel administrativo**

```text
Crie o AdminAuthService: compara a chave digitada com a configurada via
--dart-define=ADMIN_ACCESS_KEY usando SHA-256 com salt (pacote crypto).
Após 5 erros, bloqueie por 30 segundos. Persista apenas o hash no LocalStore.
Escreva testes com relógio injetável (clock) para simular o bloqueio.
```

**Navegação do guia**

```text
A aba Guia usa um Navigator aninhado. No Android, o botão voltar na raiz do guia
deve levar para a aba home, nunca fechar o app. Ajuste o GuideNavigator com
PopScope, sem SystemNavigator.pop(), e escreva um teste de widget para isso.
```

**Acessibilidade**

```text
Gere testes de acessibilidade para HomeScreen e SuggestScreen: contraste mínimo
4.5:1 calculado a partir de AppColors, Semantics/tooltip em todos os botões de
ícone e ausência de overflow com textScaler 1.5 (RNF04, RNF18).
```

**Refatoração para camadas com Provider**

```text
Refatore a camada de dados para Clean Architecture sem quebrar as telas:
crie contratos em lib/domain/repositories (ICollectPointsRepository,
ICampaignsRepository, IPointSuggestionsRepository) e faça os repositórios
atuais implementá-los. Mova as regras de filtro e de ponto mais próximo para
casos de uso em lib/domain/usecases. Injete tudo com MultiProvider em
lib/presentation/state/app_providers.dart. Os testes existentes devem passar.
```

**Lembrete de campanha**

```text
Implemente CampaignReminderService com flutter_local_notifications e timezone.
Ao ativar o lembrete de uma campanha, agende duas notificações: 24 h antes do
início e às 08:00 do dia de início, ignorando horários que já passaram.
Use uma interface INotificationScheduler para permitir testes sem o plugin.
Persista os IDs das campanhas com lembrete no SharedPreferences.
```

**Busca por sinônimos**

```text
Crie ResidueSearchService: dado um texto digitado (sem acento, minúsculo),
retorne os WasteType compatíveis com pontuação de 0 a 100, usando sinônimos
populares (ex.: dipirona, xarope → medicines; agulha → sharps; pilha → batteries).
Sem dependências externas. Escreva testes para termos com e sem acento.
```

### 2.4 O que não funcionou

- Pedir várias funcionalidades no mesmo prompt: a IA misturava responsabilidades e quebrava o que já funcionava.
- Não enviar os arquivos existentes: a IA inventava nomes de classes e métodos que não existiam no projeto.
- Não citar o requisito: a IA ignorava o funcionamento offline e a privacidade (localização e anonimato).

## 3. Erros gerados pela IA e como o grupo resolveu

| # | Erro gerado | Impacto | Solução adotada |
|---|---|---|---|
| 1 | O botão voltar na raiz do Guia chamava `SystemNavigator.pop()`. | O app fechava de repente ao voltar no Android. | `GuideNavigator` com `Navigator` aninhado e `PopScope`: desempilha o passo a passo e, na raiz, volta para a aba home (RNF01). |
| 2 | Abertura de rota em app externo sem declarar as intents no Android. | No Android 11+ o `url_launcher` não encontrava o app de mapas. | Inclusão dos esquemas `geo:` e `https:` na tag `<queries>` do `AndroidManifest.xml` (RF04, RNF12). |
| 3 | Dois enums para o mesmo conceito (`ResidueType` e `WasteType`) com conversores entre eles. | Código duplicado e risco de filtros inconsistentes. | Unificação no enum `WasteType` da camada de domínio, com `wasteTypeByName` aceitando nomes antigos (RNF16). |
| 4 | Cores definidas em dois lugares (`EcoColors` e `AppColors`) e cores soltas nas telas. | Contraste e identidade visual inconsistentes. | Centralização em `AppColors` e remoção da classe espelho (RNF04). |
| 5 | Fila offline de sugestões sem controle de concorrência. | Envios simultâneos podiam sobrescrever a fila e perder sugestões (*lost update*). | Mutex por cadeia de `Future` em `PointSuggestionsRepository` e teste de concorrência (RNF14). |
| 6 | Parsers que confiavam no formato dos dados e tratavam status inválido como válido. | Ponto ou campanha poderia aparecer como ativo por engano; crash com dados incompletos. | `fromJson` tolerantes com padrões seguros (`inactive`, `finished`, `pending`) e cache versionado com fallback contra dados corrompidos (RNF09, RNF17). |
| 7 | Modelos de domínio importando `cloud_firestore` e usando `Timestamp` diretamente. | Impossível reutilizar os modelos no cache local e nos testes sem Firebase. | Função `normalizeFirestoreData` converte `Timestamp`/`GeoPoint` em JSON puro antes do `fromJson`. |
| 8 | Solicitação de GPS logo na abertura do app. | Pedido de permissão sem contexto, contrário à privacidade (RNF05, RNF06). | GPS sob demanda: a localização só é pedida ao tocar no botão de localização (RN13). |
| 9 | Token do Mapbox escrito direto no código. | Risco de publicar o token no GitHub. | Token público (`pk.`) lido de `--dart-define` ou de `assets/config/mapbox_token.txt`, que está no `.gitignore`. |
| 10 | `HomeScreen` concentrando mapa, filtros, lista, rota e controles em um único arquivo. | Difícil de manter e testar. | Modularização em `HomeMapTopBar`, `HomeMapControls` e no mixin `HomeScreenActions`. |
| 11 | Código com comentários educacionais do template e fora do padrão de idioma. | Código poluído e inconsistente entre integrantes. | Criação dos padrões da seção 2.1, enviados em todo prompt, e revisão dos arquivos existentes. |
| 12 | Datas de campanha gravadas em formatos diferentes (`timestamp` pelo seed e `string` ISO pelo painel). | Inconsistência no banco; consultas por data no Firestore ficam limitadas. | A leitura aceita os dois formatos via `normalizeFirestoreData`. Pendente: padronizar a escrita como `timestamp`. |

### Como o grupo valida o código gerado

1. Revisão linha a linha antes do commit, conferindo os padrões da seção 2.1.
2. `flutter analyze` sem avisos (regras do `flutter_lints`).
3. Execução dos testes (`flutter test`) e teste manual em dispositivo Android.
4. Conferência do requisito citado no prompt (RF/RNF) e registro no `CHANGELOG.md`.

## 4. Justificativa das bibliotecas escolhidas

| Biblioteca | Versão | Para que é usada | Por que foi escolhida |
|---|---|---|---|
| `mapbox_maps_flutter` | ^3.34.2 | Mapa interativo, pinos e traçado de rota (RF01, RF04) | SDK oficial do Mapbox, com estilos personalizáveis e camadas de alto desempenho para muitos pinos. A Directions API oferece rotas a pé, de bicicleta e de carro. |
| `firebase_core` | ^3.13.0 | Inicialização do Firebase | Obrigatória para qualquer serviço Firebase. Permite iniciar o app em modo offline quando não há credenciais. |
| `cloud_firestore` | ^5.6.8 | Banco de dados de pontos, campanhas, guias e sugestões (RNF11) | Banco NoSQL gerenciado, sem servidor próprio, com plano gratuito suficiente para o projeto e atualização dos dados sem publicar nova versão do app. |
| `shared_preferences` | ^2.5.6 | Cache offline, fila de sugestões e autorização do painel (RF05, RNF09) | Armazenamento chave-valor simples e multiplataforma; suficiente para guardar JSON. Fica isolado atrás da interface `LocalStore`. |
| `connectivity_plus` | ^6.1.4 | Detectar perda e retorno da conexão (RNF10) | Pacote mantido pela comunidade Flutter (plus plugins). Permite reenviar a fila e atualizar os dados ao reconectar. |
| `geolocator` | ^14.1.2 | Localização do usuário, permissões e GPS contínuo na rota (RF02, RF14, RNF13) | Trata permissões e serviço de localização em Android e iOS com uma única API, incluindo stream de posição. |
| `url_launcher` | ^6.3.2 | Abrir a rota no app de mapas do aparelho (RF04) | Pacote oficial do Flutter para abrir links e esquemas como `geo:`. |
| `http` | ^1.2.2 | Chamadas à Mapbox Directions API | Cliente HTTP oficial do Dart, leve e fácil de simular nos testes. |
| `crypto` | ^3.0.3 | Hash SHA-256 da chave do painel administrativo (RNF14) | Pacote oficial do Dart; evita guardar a chave em texto puro. |
| `provider` | ^6.1.5+1 | Injeção de dependências e gerência de estado das telas | Solução recomendada na documentação do Flutter, simples de aprender e suficiente para o tamanho do app. Permite trocar implementações reais por versões de teste. |
| `flutter_local_notifications` | ^18.0.1 | Notificações dos lembretes de campanha | Agenda notificações no próprio aparelho, sem servidor de push, funcionando offline e sem identificar o usuário (RNF06). |
| `timezone` | ^0.10.0 | Agendamento das notificações no fuso horário local | Exigido pelo `flutter_local_notifications` para agendar em data e hora exatas, respeitando o fuso do aparelho. |
| `material_ui` | ^1.11.1 | Importação centralizada dos componentes Material | Padroniza os imports de UI usados nas telas e widgets. |
| `cupertino_icons` | ^1.0.8 | Ícones no estilo iOS | Incluído por padrão em projetos Flutter. |
| `flutter_lints` (dev) | ^6.0.0 | Análise estática | Conjunto oficial de regras de qualidade do Flutter. |
| `flutter_test` (dev) | SDK | Testes de unidade, widget e acessibilidade | Ferramenta oficial de testes do Flutter. |

### Alternativas consideradas e descartadas

- **Google Maps (`google_maps_flutter`)**: exige conta de faturamento no Google Cloud; o Mapbox oferece cota gratuita e mais controle de estilo.
- **SQLite (`sqflite`) ou Hive** para o cache: os dados offline são listas pequenas lidas inteiras de uma vez, então um banco local adicionaria complexidade sem ganho.
- **Firebase Authentication**: o cidadão não deve fazer login (RNF07). Para o painel, uma chave de acesso com hash foi considerada suficiente no escopo da disciplina.
- **Riverpod ou Bloc**: resolvem o mesmo problema do Provider, mas exigem mais código e conceitos novos. Como o estado de cada tela é simples, o Provider com `ChangeNotifier` foi suficiente.
- **Firebase Cloud Messaging** para os lembretes: exigiria servidor e identificação do aparelho. A notificação local atende ao caso de uso sem coletar dados.
