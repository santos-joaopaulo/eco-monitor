# EcoMonitor

Aplicativo Flutter de educação ambiental para o descarte correto de medicamentos vencidos, seringas e pilhas.


## Sobre o Projeto

O EcoMonitor é uma plataforma integrada que funciona como mapa de pontos de coleta e guia informativo de classificação de resíduos. O objetivo é transformar o descarte correto em uma ação simples e rápida, conectando o cidadão ao ponto de coleta mais próximo em poucas interações.

**Funcionalidades em desenvolvimento:**

- Mapa de pontos de coleta (farmácias, UBS e ecopontos)
- Guia visual de classificação de resíduos
- Alertas de campanhas de coleta
- Formulário de solicitação de novos pontos de coleta

**Princípios:**

- Funcionamento offline
- Aprendizado em até 1 minuto de interação
- Dados de localização usados exclusivamente para exibir pontos de coleta próximos


## Como Executar

### Clonando o Repositório

```bash
git clone https://github.com/santos-joaopaulo/eco-monitor.git
cd eco-monitor
```

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado e no `PATH`

### Rodando o Projeto

```bash
cd eco_monitor
flutter pub get
flutter run -d web-server --web-port 3000
```

O aplicativo será servido em `http://localhost:3000`.

### Executar o aplicativo com o mapa Mapbox

É necessário ter o Flutter instalado, um dispositivo Android ou emulador configurado, acesso à internet e um token público Mapbox (`pk...`). Na pasta do projeto Flutter (`eco_monitor`), instale as dependências e execute:

```bash
flutter pub get
flutter run --dart-define=ACCESS_TOKEN=pk.seu_token_publico
```

No VS Code, também é possível iniciar a configuração **EcoMonitor (Mapbox)** em **Run and Debug**. O arquivo `eco_monitor/.vscode/launch.json` solicita o token em um campo oculto e não armazena seu valor.

Não use um token secreto (`sk...`) no aplicativo nem publique o token em arquivos versionados.

### Build de Produção

```bash
flutter build web
```
