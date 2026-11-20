# EcoMonitor

Aplicativo Flutter de educação ambiental para o descarte correto de medicamentos vencidos, seringas e pilhas.

## Sobre o Projeto

O EcoMonitor é uma plataforma integrada que funciona como mapa de pontos de coleta e guia informativo de classificação de resíduos. O objetivo é transformar o descarte correto em uma ação simples e rápida, conectando o cidadão ao ponto de coleta mais próximo em poucas interações.

**Princípios:**

- Funcionamento offline
- Aprendizado em até 1 minuto de interação
- Dados de localização usados exclusivamente para exibir pontos de coleta próximos

## Como Executar

### 1. Clonar o repositório
```bash
git clone https://github.com/santos-joaopaulo/eco-monitor.git
cd eco-monitor
```

### 2. Pré‑requisitos
- **Flutter SDK** instalado e disponível no `PATH`. Consulte o [guia oficial de instalação](https://docs.flutter.dev/get-started/install).
- **Dispositivo Android** ou emulador configurado (para testes nativos) **ou** navegador para execução web.
- Conexão com a internet para baixar dependências.

### 3. Instalar dependências do Flutter
```bash
cd eco_monitor
flutter pub get
```

### 4. Execução rápida
#### a) Web (servidor de desenvolvimento)
```bash
flutter run -d web-server --web-port 3000 --dart-define=MAPBOX_ACCESS_TOKEN=pk.seu_token_publico
```
O aplicativo ficará disponível em `http://localhost:3000`.
> **Importante:** funcionalidades relacionadas ao mapa só funcionam em dispositivos mobile.

#### b) Android / Emulador
```bash
# Liste os dispositivos conectados e seus IDs
flutter devices
```

```bash
# Substitua <device_id> pelo ID do seu dispositivo e execute
flutter run -d <device_id> --dart-define=MAPBOX_ACCESS_TOKEN=pk.seu_token_publico
```

> **Importante:** o mapa utiliza o Mapbox. Forneça um **token público** (`pk.*`). Não use tokens secret (`sk.*`).

> **Dica:** No VS Code, abra a paleta de comandos → **Run and Debug** e selecione **EcoMonitor (Mapbox)**. O arquivo `eco_monitor/.vscode/launch.json` solicita o token em um campo oculto e não o armazena no repositório.

### 5. Build de produção
#### a) Web
```bash
flutter build web --dart-define=MAPBOX_ACCESS_TOKEN=pk.seu_token_publico
```
Os arquivos gerados ficarão em `build/web/` e podem ser servidos por qualquer servidor HTTP estático.

#### b) Android (APK)
```bash
flutter build apk --dart-define=MAPBOX_ACCESS_TOKEN=pk.seu_token_publico
```
