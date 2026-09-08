# Pesquisa

## 1. O problema
O descarte inadequado de medicamentos vencidos e outros resíduos de saúde (como seringas e pilhas) é um grave problema ambiental e de saúde pública no Brasil. A maioria da população tem o costume de jogar remédios no lixo comum, na pia ou no vaso sanitário, o que contamina o solo, rios e lençóis freáticos. 

O grande problema é que as estações de tratamento de esgoto não conseguem filtrar totalmente os princípios ativos dos medicamentos, como hormônios, antibióticos e analgésicos. Isso afeta diretamente a vida aquática e pode gerar bactérias super-resistentes. Apesar de o Brasil possuir legislação para a logística reversa de medicamentos, a adesão ainda é baixa porque as pessoas simplesmente não sabem o que fazer com a "farmacinha" de casa quando o remédio vence ou sobra.

## 2. Público e usuários
Com base no estudo de caso do EcoMonitor, os usuários do nosso aplicativo se dividem em dois grandes grupos:
* **Usuários sazonais (Cidadãos comuns e donas de casa):** São as pessoas que acumulam remédios, pilhas ou eletrônicos em casa e precisam, de vez em quando, fazer o descarte de tudo que venceu.
* **Usuários frequentes/profissionais (Farmacêuticos, agentes de vigilância sanitária e gestores):** Pessoas que lidam diariamente com o recebimento e monitoramento desses resíduos e podem usar o app para orientar pacientes, solicitar ecopontos ou divulgar campanhas de coleta.

## 3. Necessidades e dificuldades dos usuários
A principal dificuldade do público geral é a falta de informação aliada à conveniência. Pesquisas apontam que mais da metade das pessoas nunca nem reparou que existem pontos de coleta de remédios nas farmácias ou Unidades Básicas de Saúde (UBSs).

As necessidades e dores reais que mapeamos são:
* **Praticidade rápida:** O usuário não quer gastar tempo procurando. Ele precisa abrir o aplicativo e descobrir rapidamente para onde levar aquele remédio.
* **Dúvidas sobre o preparo:** As pessoas não sabem como separar o lixo. "Levo a caixa junto com a cartela?", "Onde jogo a agulha da seringa?". Falta um guia visual simples que responda isso de forma direta.
* **Dificuldade de acesso:** Em áreas com sinal instável, tentar carregar um mapa pesado pode ser frustrante, fazendo a pessoa desistir do descarte correto. Além disso, ter que criar login é uma grande barreira para aplicativos de uso apenas ocasional.

## 4. Dados relevantes para o projeto
Durante o levantamento, encontramos dados e normas que vão influenciar diretamente nas decisões do aplicativo:
* **Alto índice de descarte incorreto:** Estudos recentes mostram que cerca de 81% das pessoas descartam medicamentos de forma errada (lixo comum, pia ou vaso sanitário). Apenas 17% fazem o descarte correto. *Como isso influencia:* O design e a experiência (UX) precisam educar o usuário logo no início. O foco do "Guia visual" deve ser ensinar o jeito certo para reverter esse hábito errado.
* **Volume de coleta já existente:** Em 2023, o Sistema Nacional de Informações sobre a Gestão dos Resíduos Sólidos (SINIR) registrou mais de 448 mil quilos de medicamentos recolhidos em mais de 6.200 pontos de coleta no país. *Como isso influencia:* Isso prova que os pontos físicos já existem em grande escala. O desafio principal do projeto é a tecnologia de localização. A integração com a API do Google Maps para traçar as rotas será a funcionalidade mais importante.
* **Regras da ANVISA (RDC 222/2018):** A Agência Nacional de Vigilância Sanitária tem classificações rigorosas. Seringas são do Grupo E (perfurocortantes) e não podem ser misturadas com químicos (Grupo B, medicamentos). *Como isso influencia:* No desenvolvimento do guia, precisaremos criar ícones bem distintos (ex: usar o símbolo específico de perfurocortante) e separar as instruções de forma clara, garantindo a segurança do farmacêutico que vai receber o material.
