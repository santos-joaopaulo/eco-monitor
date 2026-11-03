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

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado e no `PATH`

### Rodando o Projeto

```bash
cd eco_monitor
flutter pub get
flutter run -d web-server --web-port 3000
```

O aplicativo será servido em `http://localhost:3000`.

### Build de Produção

```bash
flutter build web
```
