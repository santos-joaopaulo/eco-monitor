# Funcionalidades e Requisitos — EcoMonitor

## 1.1 Funcionalidades

### 1. Mapa de pontos de coleta

- **Descrição:** Exibe, em um mapa interativo, os pontos de coleta (farmácia, UBS, ecoponto) a partir da localização do usuário.
- **Necessidade do usuário que atende:** Encontrar rapidamente os pontos possíveis para descarte de um resíduo específico (necessidade central da persona Marta).
- **Justificativa:** O problema central do EcoMonitor é o descarte incorreto de resíduos principalmente pela falta de conhecimento das pessoas sobre pontos de coleta e essa funcionalidade intervêm diretamente nesse problema.

### 2. Guia de classificação de resíduos

- **Descrição:** Exibe um guia simples e didático apontando os tipos específicos de resíduos e como deve ser feito o descarte.
- **Necessidade do usuário que atende:** O usuário pode ser rapidamente e devidamente informado a respeito do tratamento correto de resíduos.
- **Justificativa:** O próprio estudo de caso apontou que, quando esses resíduos vão para o lixo comum ou são deixados em lugares inadequados, eles podem poluir o solo, os rios e os lençóis freáticos. Portanto, faz-se necessária a devida classificação e descarte desses resíduos.

### 3. Alertas de campanha de coleta

- **Descrição:** O app deve notificar o usuário a respeito de campanhas de coleta nas redondezas.
- **Necessidade do usuário que atende:** Ser informado de pontos extras de descarte.
- **Justificativa:** Mantém o engajamento do usuário com o aplicativo.

### 4. Solicitação de novo ponto de coleta

- **Descrição:** O app deve prover a opção de preencher um formulário para solicitar um novo ponto de coleta.
- **Necessidade do usuário que atende:** O usuário pode sentir que não há ponto de coleta nas redondezas de acesso prático.
- **Justificativa:** Estabelece ao usuário uma ponte direta com os gestores municipais.

### 5. Filtro de busca por resíduo

- **Descrição:** Permite o filtro de pontos de coleta no mapa a partir da especificidade do resíduo.
- **Necessidade do usuário que atende:** Evitar o deslocamento do usuário para um ponto não compatível com o descarte.
- **Justificativa:** Com base na RDC 222/2018 da ANVISA, resíduos de risco físico/biológico e de risco químico seguem destinos e coletores diferentes. Sendo assim, torna-se necessária a filtragem dos pontos de coleta.

### 6. Acesso sem login

- **Descrição:** Permite o uso de todas as funcionalidades sem exigir um cadastro ou login.
- **Necessidade do usuário que atende:** Permite mais praticidade e rapidez ao usuário, tornando o app mais leve e entregando o que o usuário busca.
- **Justificativa:** Ter que criar login é uma grande barreira para aplicativos de uso apenas ocasional. Se o app não for pronto para uso ao abrir, é capaz que a pessoa desista de usar o app.

## 2.2 Requisitos funcionais

RF01 — Exibição do mapa: O sistema deve exibir os pontos de coleta de resíduos disponíveis por meio de um mapa.

RF02 — Identificação de proximidade: O sistema deve utilizar a localização atual do dispositivo do usuário para identificar e exibir os pontos de coleta mais próximos.

RF03 — Detalhamento do ponto de coleta: O sistema deve apresentar as informações de um ponto de coleta selecionado, detalhando especificamente quais tipos de resíduos são aceitos no local.

RF04 — Rota de deslocamento: O sistema deve traçar e abrir a rota de navegação a partir da localização do usuário até o ponto de coleta selecionado.

RF05 — Consulta offline: O sistema deve permitir consultar as informações e localizações dos pontos de coleta previamente disponibilizados para acesso offline.

RF06 — Catálogo de resíduos: O sistema deve listar as diferentes categorias de resíduos, diferenciando itens como medicamentos, pilhas, seringas e lixo eletrônico.

RF07 — Orientações de descarte: O sistema deve apresentar instruções específicas sobre como preparar e realizar o descarte adequado para cada tipo de resíduo selecionado no guia.

RF08 — Lista de campanhas: O sistema deve exibir as campanhas de coleta de resíduos que estejam ativas ou programadas.

RF09 — Detalhamento da campanha: O sistema deve apresentar as informações disponíveis sobre uma campanha de coleta selecionada, incluindo o tipo de resíduo coletado e o local da campanha.

RF10 — Formulário de sugestão: O sistema deve disponibilizar um formulário para que o usuário sugira a localização para a criação de um novo ponto de coleta.

RF11 — Envio anônimo: O sistema deve enviar a solicitação de sugestão de um novo ponto de coleta de forma anônima, sem registrar dados de identificação do usuário.

RF12 — Filtragem por tipo de resíduo: O sistema deve permitir que o usuário selecione categorias específicas de resíduos para realizar buscas direcionadas.

RF13 — Atualização de resultados por filtro: O sistema deve atualizar os resultados exibidos no mapa, restringindo-os aos pontos que aceitam o tipo de resíduo filtrado pelo usuário.

RF14 — Ponto de coleta mais próximo: O sistema deve permitir que o usuário solicite a identificação do ponto de coleta mais próximo com base em sua localização atual.

## 2.3 Requisitos não funcionais

**RNF01 — Usabilidade:** O usuário deve conseguir acessar as principais funcionalidades do aplicativo em, no máximo, três interações, priorizando ações rápidas e objetivas.

**RNF02 — Facilidade de aprendizado:** Um novo usuário deve conseguir compreender como realizar o descarte correto de um resíduo em até um minuto, sem necessidade de treinamento ou manual externo.

**RNF03 — Interface:** A interface deve utilizar textos curtos, ícones claros, botões de fácil identificação e linguagem simples, considerando principalmente usuários que acessam o aplicativo de forma ocasional.

**RNF04 — Acessibilidade:** O aplicativo deve apresentar contraste adequado entre texto e fundo, tamanho de fonte legível e elementos de interação suficientemente grandes para facilitar o uso por pessoas com diferentes níveis de capacidade visual e motora.

**RNF05 — Privacidade:** O aplicativo deve utilizar os dados de localização do dispositivo exclusivamente para apresentar pontos de coleta próximos ao usuário, não podendo utilizá-los para outras finalidades sem autorização.

**RNF06 — LGPD:** O aplicativo deve seguir os princípios da Lei Geral de Proteção de Dados (LGPD), coletando e armazenando apenas os dados estritamente necessários para seu funcionamento e informando ao usuário sobre sua utilização.

**RNF07 — Ausência de autenticação:** O acesso às funcionalidades destinadas ao cidadão deve ocorrer sem obrigatoriedade de cadastro, login ou criação de conta, reduzindo barreiras de acesso.

**RNF08 — Desempenho:** As telas principais do aplicativo devem ser carregadas em até 3 segundos, em condições normais de conectividade, para garantir uma experiência rápida durante o descarte.

**RNF09 — Conectividade:** O aplicativo deve continuar disponibilizando as informações essenciais do guia de classificação de resíduos mesmo quando estiver sem conexão com a internet.

**RNF10 — Uso offline:** Quando não houver conexão, o aplicativo deve informar claramente ao usuário quais informações estão disponíveis offline e quais dependem de conexão, evitando que dados desatualizados sejam apresentados como atuais.

**RNF11 — Atualização dos dados:** As informações sobre pontos de coleta e campanhas devem ser mantidas atualizadas e confiáveis, com mecanismos que permitam a atualização dos dados pelos responsáveis pela manutenção do sistema.

**RNF12 — Compatibilidade:** O aplicativo deve ser compatível com dispositivos móveis que utilizem versões de sistemas operacionais Android e iOS suportadas pelo projeto.

**RNF13 — Geolocalização:** Quando autorizada pelo usuário, a localização do dispositivo deve ser utilizada para identificar os pontos de coleta próximos, sem exigir que o usuário informe manualmente seu endereço.

**RNF14 — Segurança:** Os dados enviados pelo aplicativo, especialmente informações provenientes de formulários, devem ser protegidos contra acesso, alteração ou divulgação não autorizada.

**RNF15 — Armazenamento de dados:** Os dados necessários ao funcionamento do aplicativo devem ser armazenados de forma segura, evitando o armazenamento de informações pessoais que não sejam necessárias para a utilização do serviço.

**RNF16 — Confiabilidade:** O aplicativo deve apresentar informações de pontos de coleta de maneira consistente, evitando indicar ao usuário locais que não sejam compatíveis com o tipo de resíduo selecionado.

**RNF17 — Clareza das informações:** O aplicativo deve diferenciar claramente informações confirmadas, desatualizadas ou indisponíveis, evitando que o usuário interprete uma informação incerta como uma orientação oficial.

**RNF18 — Responsividade:** A interface deve se adaptar a diferentes tamanhos e resoluções de telas de dispositivos móveis, mantendo a legibilidade e o acesso às funcionalidades principais.

## 2.4 CRUD

**Pontos de Coleta:**
- **C — Criadas:** O sistema deve permitir a criação de novos pontos de coleta por administradores.
- **R — Consultadas:** O sistema deve permitir a consulta dos pontos de coleta pelos usuários no mapa.
- **U — Atualizadas:** O sistema deve permitir a atualização das informações de um ponto de coleta (horário, status, tipo de resíduo aceito).
- **D — Excluídas:** O sistema deve permitir a exclusão de pontos de coleta desativados ou inexistentes.

**Guia de Classificação de Resíduos:**
- **C — Criadas:** O sistema deve permitir a inclusão de novas orientações de descarte.
- **R — Consultadas:** O sistema deve permitir a consulta das orientações pelos usuários.
- **U — Atualizadas:** O sistema deve permitir a atualização das orientações de descarte existentes.
- **D — Excluídas:** O sistema deve permitir a remoção de orientações obsoletas.

**Alertas de Campanha de Coleta:**
- **C — Criadas:** O sistema deve permitir a criação de alertas de campanha por administradores.
- **R — Consultadas:** O sistema deve permitir a consulta dos alertas pelos usuários.
- **U — Atualizadas:** O sistema deve permitir a atualização de datas, locais e detalhes das campanhas.
- **D — Excluídas:** O sistema deve permitir a exclusão de campanhas finalizadas ou canceladas.

**Formulário de Sugestão de Ponto de Coleta:**
- **C — Criadas:** O sistema deve permitir a criação de novas solicitações de ponto de coleta pelos usuários.
- **R — Consultadas:** O sistema deve permitir a consulta das solicitações enviadas pelos administradores.
- **U — Atualizadas:** O sistema deve permitir a atualização do status da solicitação (Ex: "Em análise", "Aprovado", "Concluído").
- **D — Excluídas:** O sistema deve permitir a exclusão de solicitações inválidas ou duplicadas.

## 2.5 Priorização

### **Essenciais**

*   **Mapa de pontos de coleta:** É a funcionalidade central. Sem a geolocalização dos pontos (farmácias, UBS, ecopontos), o usuário não tem como executar a ação física do descarte correto.
*   **Guia de classificação de resíduos:** Fundamental para a missão educativa. O usuário precisa identificar a natureza do resíduo (ex: diferenciar pilha de remédio) antes de buscar o local, sob risco de contaminação cruzada ou recusa no ponto de coleta.
*   **Acesso sem login:** Requisito mandatório definido no estudo de caso para garantir a usabilidade ("aprender em 1 minuto") e remover barreiras de entrada para usuários ocasionais.

### **Importantes**

*   **Filtro de busca por resíduo:** Evita o deslocamento inútil do usuário. Embora o mapa mostre os pontos, o filtro garante que a rota traçada seja para um local que *efetivamente* aceite aquele tipo específico de resíduo (ex: não adianta ir à farmácia mais próxima se ela não aceita lixo eletrônico).
*   **Solicitação de novo ponto de coleta:** Permite que a comunidade atue na expansão da rede de logística reversa, ajudando a resolver o problema de "vazios sanitários" em bairros carentes.

### **Secundárias**

*   **Alertas de campanha de coleta:** Funcionalidade de engajamento e retenção. Embora útil para mutirões, o descarte de resíduos domésticos (como uma caixa de remédios vencidos) é uma necessidade imediata e individual que não depende de campanhas temporárias para ser atendida.
