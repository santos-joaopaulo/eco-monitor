# Eco Monitor ♻️
<img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Tela inicial do aplicativo">

# 🤝 Integrantes 
* Carlos Kayky de Oliveira Silva
* Enrico de Andrade Rodrigues Holanda
* Matheus Gabriel Freire dos Santos
* João Paulo Caetano dos Santos
* Victor Rafael Ferreira Feitosa

# 👨‍🏫 Turma
<center>Programação Para Dispositivos Móveis - GP0029VNO07A</center>

# 🛠️ Descrição do Projeto
O EcoMonitor é um aplicativo que ajuda na educação ambiental e no descarte correto de medicamentos vencidos, pilhas, seringas e lixo eletrônico. Ele facilita a localização de pontos de coleta, orienta os usuários de forma simples e rápida e divulga campanhas de recolhimento. Feito para cidadãos, farmacêuticos, agentes de vigilância sanitária e gestores municipais, o aplicativo conecta a população às práticas de logística reversa e ajuda a prevenir a contaminação ambiental, a experiência do EcoMonitor foca em ser didática, prática e acessível, permitindo encontrar o ponto mais próximo em poucas interações, mesmo em locais com conexão instável.

## Executar o aplicativo com o mapa Mapbox

É necessário ter o Flutter instalado, um dispositivo Android ou emulador configurado, acesso à internet e um token público Mapbox (`pk...`). Na pasta do projeto Flutter (`eco_monitor`), instale as dependências e execute:

```bash
flutter pub get
flutter run --dart-define=MAPBOX_ACCESS_TOKEN=pk.seu_token_publico
```

No VS Code, também é possível iniciar a configuração **EcoMonitor (Mapbox)** em **Run and Debug**. O arquivo `eco_monitor/.vscode/launch.json` solicita o token em um campo oculto e não armazena seu valor.

Não use um token secreto (`sk...`) no aplicativo nem publique o token em arquivos versionados.

# 📃 Responsabilidade de Cada Integrante

## Carlos Kayky de Oliveira Silva
* Responsabilidade: Estudo de caso, pesquisa, justificativas, requisitos funcionais e estruturação das apresentações do projeto.
* Atividades desenvolvidas: Criação de seis seções do estudo de caso, abordando o problema da invisibilidade dos ecopontos, o público-alvo, as necessidades e dificuldades dos usuários e dados relevantes de fontes como SINIR+ e SciELO; estruturação da pesquisa e das apresentações final e parcial; levantamento e documentação dos requisitos funcionais do sistema (RF01 a RF14); elaboração das justificativas técnicas e de design do projeto.
* Responsabilidade: Desenvolvimento do Guia de Descarte, Eventos, formulário de sugestão, fallback em lista e correções de plataforma.
* Atividades desenvolvidas: Implementação das telas e fluxo de tutoriais do Guia de Descarte passo a passo e da tela de Eventos e Campanhas; integração inicial de sincronização com Firebase; resolução de bugs críticos de plataforma com inclusão de queries de intents no `AndroidManifest.xml` (T1.1) e correção do fechamento indevido no fluxo de retorno do Guia (T1.2); desenvolvimento do formulário de sugestão de novo ponto (`SuggestScreen`) com validações, horários e fila offline (T2.1); implementação do modo alternativo em lista (`CollectPointsListView`) como fallback da Home (T2.2); padronização de comentários em português e refatoração de imports de Material Design (T3.4).

## Enrico de Andrade Rodrigues Holanda
* Responsabilidade: Construção das personas do projeto e levantamento de funcionalidades.
* Atividades desenvolvidas: Criação das personas Marta Almeida (cidadã comum, prioritária) e Rafael Souza (farmacêutico), com base no estudo de caso e nas descobertas da pesquisa do grupo; definição e justificativa da persona prioritária; redação e commit do arquivo `docs/personas.md`. Elaboração da lista de funcionalidades do sistema com base no estudo de caso e nas descobertas da pesquisa do grupo; redação e commit do arquivo `docs/funcionalidades.md`.

## Matheus Gabriel Freire dos Santos
* Responsabilidade: Pesquisa de levantamento de informações e elaboração dos requisitos não funcionais.
* Atividades desenvolvidas: Realização da pesquisa sobre descarte de medicamentos e resíduos, análise das necessidades dos usuários, levantamento de fontes confiáveis (ANVISA, SINIR, SciELO) e elaboração das 3 principais descobertas da pesquisa; definição detalhada dos requisitos não funcionais relacionados à usabilidade, acessibilidade, LGPD, funcionamento offline, compatibilidade e segurança em `docs/requisitos.md`.
* Responsabilidade: Integração inicial do mapa interativo Mapbox no Flutter.
* Atividades desenvolvidas: Configuração inicial da dependência `mapbox_maps_flutter` na tela inicial (`HomeScreen`), estabelecendo a renderização base do mapa e suporte ao token de acesso Mapbox.
* Responsabilidade: Aprimoramento do Painel Administrativo, gestão de avaliações e relatórios cívicos territoriais.
* Atividades desenvolvidas: Implementação do módulo de moderação de avaliações e reportes cidadãos (`AdminReviewsScreen`) com banner de ecopontos críticos e filtros por nota e tags; desenvolvimento da visão de demanda territorial agregada por bairros em `AdminSuggestionsScreen` com sumário cívico municipal e aprovação direta de sugestões; auditoria e governança no formulário de pontos de coleta (`AdminPointFormScreen`) com suporte completo ao resíduo Vidro e exibição de nota média e total de avaliações durante a edição; e ampliação da suíte de testes automatizados do painel administrativo.

## João Paulo Caetano dos Santos
* Responsabilidade: Documentação geral, análise de referências e desenvolvimento dos protótipos de baixa e alta fidelidade.
* Atividades desenvolvidas: Elaboração e atualização contínua da documentação do projeto, incluindo as seções "Visão geral", "Problema" e "Pontos de Atenção" no `estudo-de-caso.md`, manutenção do `CHANGELOG.md` e a seção "CRUD" em `docs/requisitos.md`; análise do aplicativo "RecyclingLocator" para o `benchmarks.md`; desenvolvimento do protótipo de baixa fidelidade; colaboração e refinamento de todas as telas do protótipo de alta fidelidade; colaboração na elaboração do documento de justificativas e apresentação final da Unidade 1.
* Responsabilidade: Arquitetura, componentes de UI, infraestrutura Firebase, testes automatizados e plano de ação (Ondas 1 a 5).
* Atividades desenvolvidas: Implementação da arquitetura base da aplicação Flutter, shell de navegação com `IndexedStack` e barra de navegação inferior flutuante (`CustomBottomNavBar`); integração do puck azul de geolocalização e permissões de GPS; desenvolvimento dos marcadores customizados (`PointPin`), barra de filtros (`FilterBar`), card de detalhes (`CollectPointSheet`) e traçado inicial de rota; ajuste do identificador do app (`br.edu.ufs.ecomonitor`) e build Android (T1.3); implementação da navegação híbrida in-app multi-modal (a pé, bicicleta, carro) com Mapbox Directions e fallback autônomo offline em tempo real com bússola (T2.3); refatoração arquitetural com unificação em `WasteType` (T3.1), centralização de cores em `AppColors` (T3.2) e modularização da `HomeScreen` (T3.3); persistência local avançada com `LocalStore`, cache versionado e mutex na fila offline (T4.2); vinculação e configuração oficial do Firebase em produção, regras de segurança do Firestore e script de seed com verificação (T4.1); criação da suíte completa de testes de widget e acessibilidade WCAG AA / Semantics (T5.1, T5.2, T5.3); refinamentos de UX/UI em dispositivos da Onda 5 (T6.1 a T6.7 - banner pílula, contraste de rota e pinos, alinhamento de sheets, GPS sob demanda, botão de alternância e sombra uniforme da barra inferior); coleta e sincronização de 35 ecopontos reais de Aracaju no Firestore; e desenvolvimento do painel administrativo simplificado protegido por chave com hash SHA-256 e ativado por gesto secreto na logo (5 toques).

## Victor Rafael Ferreira Feitosa
* Responsabilidade: Benchmark comparativo e documentação introdutória.
* Atividades desenvolvidas: Criação da estrutura introdutória do `README.md` descrevendo a visão geral do projeto; pesquisa e elaboração do documento de benchmark comparando plataformas e sites disponíveis no mercado (`docs/benchmark.md`), visando identificar boas práticas, funcionalidades de logística reversa e oportunidades de diferenciação para o EcoMonitor.
* Responsabilidade: Manutenção e sincronização da documentação do projeto e histórico de entregas.
* Atividades desenvolvidas: Consolidação e documentação das entregas do plano de ação e grupos de tarefas no `CHANGELOG.md`; mapeamento e atualização detalhada das responsabilidades e atividades dos integrantes no `README.md` com base no histórico de commits do repositório.
