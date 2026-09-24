# Justificativas

## 1. Escolha das cores

No protótipo final, decidimos usar o verde como cor principal porque ele faz a ligação direta com o tema ambiental do projeto. Usamos um verde mais escuro nos ícones de localização e na barra superior para dar um contraste forte com o fundo claro do mapa, o que ajuda o usuário a encontrar os ecopontos mais rápido. Para marcar a localização da própria pessoa no mapa, mantivemos o clássico ponto azul, que é um padrão que todo mundo já conhece e entende na hora. Como no protótipo de baixa fidelidade não tínhamos cores, essa foi uma evolução importante na alta fidelidade para deixar a tela mais legível.

## 2. Tipografia

Usamos uma fonte sem serifa, porque ela é limpa e facilita a leitura em telas de celular. Para organizar os textos, criamos uma hierarquia simples na alta fidelidade: quando o usuário clica em um ponto no mapa, o nome do local, como Farmácia São Paulo, aparece em negrito e com uma letra maior, enquanto o endereço e a distância, como 1,2 km, ficam com uma fonte menor e mais fina. Isso ajuda diretamente a nossa persona Marta, que é uma usuária ocasional e só quer bater o olho na tela e pegar a informação em segundos, sem ter que ler blocos de texto.

## 3. Organização das informações

A nossa pesquisa inicial mostrou que muitas pessoas nunca viram um ecoponto, então organizamos a interface para que o aplicativo abra direto no mapa, sem pedir login ou criar conta. Colocamos os filtros de resíduos, como Remédios, Seringas e Pilhas, bem no topo da tela para a pessoa filtrar o mapa logo de cara. Na baixa fidelidade, as informações do ecoponto abriam ocupando uma tela inteira, mas na alta fidelidade evoluímos isso para um card que sobe na parte de baixo da tela. Achamos melhor assim porque o mapa e as rotas continuam visíveis no fundo, sem tirar o usuário do contexto principal.

## 4. Navegação

O usuário abre o app, clica no marcador do ecoponto e depois aperta o botão de rota. O menu principal ficou fixo na parte de baixo da tela com as abas "home", "guia", "eventos" e "sugerir". Isso facilita a vida dos usuários, porque tanto o Rafael quanto a Marta conseguem pular do mapa para o guia de descarte usando só um dedo. O caminho que desenhamos na baixa fidelidade se manteve, mas a alta fidelidade deixou a troca entre ver o mapa e abrir os detalhes do ponto muito mais rápida.

## 5. Componentes

Utilizamos componentes que as pessoas já estão acostumadas a ver em aplicativos de mapa e mobilidade. Lá no topo temos os botões de filtro com ícones pequenos do lado dos nomes, para a pessoa filtrar os materiais com um toque só. No mapa, usamos marcadores (pins) padrão. Dentro do card do ecoponto, colocamos um botão de ação redondo com um ícone de seta/aviãozinho para iniciar a navegação. Usar esses componentes familiares resolve o nosso problema sem exigir que os usuários aprendam a usar o app, o que se encaixa bem no perfil da Marta, que foge de burocracia.

## 6. Acessibilidade

O contraste entre os marcadores verdes escuros e o mapa claro ajuda a visualizar os pontos sem forçar a vista, o que faz diferença se a pessoa estiver usando o celular na rua, debaixo de sol. Também nos preocupamos em colocar ícones junto com os textos nos filtros e no menu inferior para agilizar o reconhecimento das funções. Outra decisão importante, focada na segurança do usuário, foi deixar os botões de remédios e seringas separados logo de cara, reforçando a regra da Anvisa, que mapeamos nos requisitos, de que materiais com risco biológico não podem ser misturados.

## 7. Contexto de uso

O EcoMonitor vai ser usado por pessoas que estão com o lixo especial na mão, prestes a sair de casa ou já na rua, querendo resolver o descarte rápido. É por isso que eliminamos qualquer tela de cadastro. A pessoa pega o celular, abre o app e vê para onde ir. Como o usuário vai estar em movimento até a farmácia ou posto de saúde, a interface tem botões grandes para evitar toques errados. Além disso, a aplicação foi pensada para manter as informações armazenadas offline, permitindo que a pessoa chegue até o ponto mesmo se perder o sinal do 4G no meio do caminho.

## 8. Arquitetura do sistema

O projeto funciona como um aplicativo mobile que trabalha em conjunto com o GPS do celular para encontrar as coordenadas de onde a pessoa está e traçar a distância até os ecopontos mais próximos. A principal escolha da arquitetura foi utilizar o cacheamento de dados locais no aparelho para garantir o requisito funcional de acesso offline aos pontos de coleta. Além disso, a funcionalidade de sugerir novos pontos usa um formulário que apenas envia os dados do local de forma anônima, dispensando a necessidade de criarmos uma estrutura de autenticação de usuários para essa funcionalidade.
