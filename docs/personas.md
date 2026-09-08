# Personas — EcoMonitor

Personas construídas a partir do **Estudo de Caso | EcoMonitor** e das descobertas da pesquisa (ver `docs/pesquisa.md`).

O próprio estudo de caso descreve três tipos de relação com o app na seção "Público e Usuários": (1) cidadãos comuns, buscando "informação rápida e utilitária"; (2) farmacêuticos e agentes de vigilância sanitária, em uma relação "de suporte aos usuários para orientar os pacientes ou mapear a coleta do município"; e (3) gestores municipais, em uma relação "estratégica", recebendo e analisando os formulários de solicitação de novos pontos. Como a atividade pede 2 personas principais, escolhemos representar os dois primeiros grupos — que são quem usa o app na ponta, no momento do descarte — deixando o gestor municipal como um perfil de apoio/administrativo, não coberto por uma persona própria nesta entrega.

---

## Persona 1 (prioritária) — Marta Almeida

**"Eu sei que não posso jogar remédio no lixo, mas nunca sei pra onde levar."**

- **Nome fictício:** Marta Almeida
- **Perfil/contexto:** 47 anos, dona de casa, mora em bairro de médio porte, cuida da própria família e às vezes dos pais idosos. Tem um armário de remédios em casa com sobras de tratamentos antigos e alguns frascos vencidos. Já se automedica ocasionalmente e acompanha temas de saúde e meio ambiente pelas redes sociais. Representa o perfil "cidadão comum" descrito no estudo de caso, cuja relação com o app é de "busca por informação rápida e utilitária".
- **Objetivos:** manter a casa organizada e "fazer a coisa certa" pelo meio ambiente sem grande esforço; descartar rapidamente o que acumula no armário quando faz a limpeza.
- **Necessidades:** saber, de forma imediata, qual é o ponto de coleta mais próximo de casa ou do caminho que já faz (farmácia, mercado, trabalho); entender rapidamente o que pode ou não descartar em cada categoria (remédio, pilha, seringa de uso doméstico).
- **Dores:** não sabe onde descartar corretamente (alinhado ao achado da pesquisa de que 92% da população desconhece os pontos corretos); já foi a uma farmácia que recusou receber o medicamento vencido; não tem paciência para apps que pedem cadastro, login ou muitos passos para uma tarefa simples.
- **Comportamentos:** usa o celular no dia a dia para resolver tarefas rápidas (apps de banco, mercado, mapas); pesquisa pouco antes de agir — se o app não resolver em poucos toques, ela desiste e volta a descartar no lixo comum; costuma agir "em rajadas" (uma limpeza geral no armário a cada poucos meses), não é uma usuária recorrente. Segue o contexto de uso previsto no estudo de caso: abre o app em ambiente doméstico ou durante um deslocamento urbano, no exato momento em que se depara com o resíduo (ex.: achou um remédio vencido na gaveta), usando conectividade e GPS do celular para achar farmácia/UBS mais próxima.
- **Relação com o aplicativo:** usuária **sazonal**. Abre o EcoMonitor pontualmente quando percebe que tem remédio ou pilha vencida em casa, ou quando recebe um alerta de campanha de coleta de eletrônico no bairro. Espera resolver tudo sem login, com ícones grandes e claros, no máximo em 3 interações (abrir → tocar em "ponto mais próximo" → ver a rota).

---

## Persona 2 — Rafael Souza

**"Se o app disser que o ponto aceita, ele precisa aceitar de verdade — senão eu perco a confiança do cliente."**

- **Nome fictício:** Rafael Souza
- **Perfil/contexto:** 33 anos, farmacêutico responsável técnico de uma drogaria de bairro. Atende clientes diariamente, muitas vezes recebendo perguntas sobre o que fazer com remédios vencidos, seringas de uso domiciliar (diabéticos, por exemplo) e pilhas. Representa o perfil "farmacêuticos e agentes de vigilância sanitária" do estudo de caso, cuja relação com o app é "de suporte aos usuários para orientar os pacientes ou mapear a coleta do município".
- **Objetivos:** orientar corretamente os clientes sem perder tempo no balcão; manter a farmácia em conformidade com boas práticas de descarte; direcionar quem procura outros pontos de coleta quando a própria farmácia não recebe determinado item.
- **Necessidades:** informação confiável e atualizada sobre quais pontos da região realmente recebem cada tipo de resíduo (evitando mandar o cliente a um lugar que vai recusar); um jeito rápido de indicar, dentro do próprio atendimento, onde o cliente pode descartar o que a farmácia não aceita.
- **Dores:** segundo a pesquisa, apenas uma pequena parte das farmácias realmente aceita medicamento vencido na prática — Rafael sente o peso disso quando precisa recusar um cliente e não tem para onde indicá-lo; informações sobre pontos de coleta hoje estão espalhadas em sites e apps diferentes por tipo de resíduo (remédio, pilha, eletrônico), o que atrapalha uma resposta rápida no balcão.
- **Comportamentos:** usa o celular constantemente durante o expediente para tirar dúvidas técnicas; confia em fontes oficiais (ANVISA, vigilância sanitária) e desconfia de informação desatualizada; costuma repassar recomendações verbalmente aos clientes, então valoriza rapidez e precisão mais do que design bonito.
- **Relação com o aplicativo:** usuário **diário/operacional**. Consulta o EcoMonitor várias vezes por semana durante o atendimento, usa o guia visual para reforçar orientações aos clientes e pode utilizar o formulário de solicitação de ponto de coleta para sugerir a própria farmácia ou apontar pontos desatualizados na base.

---

## Persona prioritária: Marta Almeida

A persona prioritária é **Marta Almeida** (cidadã comum), pelos seguintes motivos:

1. **Escala do problema.** A pesquisa mostrou que 91% dos descartes domiciliares são feitos incorretamente e que o desconhecimento é generalizado entre a população — o público de Marta é quem mais precisa do produto e é numericamente o maior público-alvo do app.
2. **A missão do produto é educativa e cívica, voltada ao cidadão comum** ("orientando a população sobre pontos de coleta e descarte correto"), e não uma ferramenta profissional B2B.
3. **Os "Pontos de Atenção" do próprio estudo de caso — facilidade de uso, confiabilidade das informações e dispensa de login — são exatamente as expectativas de alguém como a Marta**, um usuário sem paciência para cadastro e que precisa de resposta em segundos, no exato momento em que encontra o resíduo em casa.
4. Rafael (farmacêutico) continua sendo essencial — sua relação de "suporte" ajuda a manter a confiabilidade dos dados usados pela Marta —, mas seu uso é operacional/recorrente e mais tolerante a uma curva de aprendizado, enquanto o sucesso do produto depende de conquistar, no primeiro uso, alguém como a Marta.

