# Diagrama de Classes — Modelos de Domínio

O EcoMonitor não possui uma entidade `Usuario`: o cidadão usa o app sem cadastro (RNF07), e sugestões e avaliações são anônimas (RF11, RNF06). Favoritos e lembretes ficam salvos apenas no aparelho. O administrador também não é uma entidade persistida; ele é identificado apenas pela chave de acesso validada no `AdminAuthService`.

As entidades centrais giram em torno do **tipo de resíduo** (`WasteType`), que liga pontos de coleta, campanhas, sugestões e guias de descarte. As entidades ficam em `lib/domain/entities` (a pasta `lib/models` apenas reexporta esses arquivos).

## Arquitetura em camadas

```mermaid
flowchart TB
    ui["Apresentação<br/>screens, widgets e notifiers (Provider)"]
    uc["Domínio: casos de uso<br/>FilterPoints, GetNearestPoint,<br/>SubmitSuggestion, GetCampaigns"]
    contratos["Domínio: contratos<br/>interfaces I*Repository"]
    ent["Domínio: entidades<br/>CollectionPoint, Campaign, PointSuggestion,<br/>PointReview, Residue, DisposalGuide"]
    dados["Dados<br/>repositórios Firestore + cache local"]
    serv["Serviços<br/>autenticação admin, lembretes,<br/>busca, localização, rotas"]

    ui --> uc
    ui --> serv
    uc --> contratos
    uc --> ent
    dados -. "implementa" .-> contratos
    dados --> ent
```

A apresentação depende dos **contratos** (interfaces), e não das classes concretas. As implementações são injetadas pelo `buildAppProviders` (`lib/presentation/state/app_providers.dart`).

## 1. Entidades de domínio

### 1.1 Pontos de coleta, campanhas e sugestões

```mermaid
classDiagram
    direction LR

    class WasteType {
        <<enumeration>>
        medicines
        sharps
        batteries
        electronics
        glass
        +wasteTypeByName(name) WasteType?
        +wasteTypesFromJson(raw) Set~WasteType~
    }

    class PointType {
        <<enumeration>>
        pharmacy
        healthCenter
        ecoPoint
    }

    class PointStatus {
        <<enumeration>>
        active
        inactive
    }

    class CampaignStatus {
        <<enumeration>>
        active
        upcoming
        finished
    }

    class SuggestionStatus {
        <<enumeration>>
        pending
        reviewing
        approved
        rejected
    }

    class CollectionPoint {
        +String id
        +String name
        +PointType type
        +double latitude
        +double longitude
        +String address
        +Set~WasteType~ acceptedWasteTypes
        +String hours
        +PointStatus status
        +bool isActive
        +accepts(WasteType type) bool
        +acceptsAny(Set~WasteType~ types) bool
        +fromJson(Map json)$ CollectionPoint
        +toJson() Map
    }

    class Campaign {
        +String id
        +String title
        +String description
        +Set~WasteType~ wasteTypes
        +String locationName
        +String address
        +double latitude
        +double longitude
        +DateTime startDate
        +DateTime endDate
        +CampaignStatus status
        +bool isActive
        +bool isUpcoming
        +accepts(WasteType type) bool
        +fromJson(Map json)$ Campaign
        +toJson() Map
    }

    class PointSuggestion {
        +String id
        +String name
        +String address
        +Set~WasteType~ acceptedWasteTypes
        +String hours
        +double? latitude
        +double? longitude
        +SuggestionStatus status
        +DateTime createdAt
        +fromJson(Map json)$ PointSuggestion
        +toJson() Map
    }

    CollectionPoint --> PointType : type
    CollectionPoint --> PointStatus : status
    CollectionPoint "0..*" --> "1..*" WasteType : aceita
    Campaign --> CampaignStatus : status
    Campaign "0..*" --> "1..*" WasteType : coleta
    PointSuggestion --> SuggestionStatus : status
    PointSuggestion "0..*" --> "1..*" WasteType : propõe aceitar
    PointSuggestion ..> CollectionPoint : convertida em (admin)
```

### 1.2 Avaliações de pontos

```mermaid
classDiagram
    direction LR

    class CollectionPoint {
        +String id
        +String name
    }

    class PointReview {
        +String id
        +String pointId
        +int rating
        +List~String~ tags
        +DateTime createdAt
        +String comment
        +fromJson(Map json)$ PointReview
        +toJson() Map
    }

    class PointReviewStats {
        +String pointId
        +double averageRating
        +int totalReviews
        +Map~String,int~ tagCounts
        +bool hasReviews
        +List~String~ topTags
    }

    class PointReviewTags {
        <<constants>>
        +String accessibleCollector
        +String fullCollector
        +String divergentHours
        +String veryGood
        +List~String~ all
    }

    class PointReviewSubmitResult {
        <<enumeration>>
        sent
        queuedOffline
    }

    CollectionPoint "1" <-- "0..*" PointReview : avalia (pointId)
    PointReview ..> PointReviewTags : usa
    PointReviewStats ..> PointReview : resume
    PointReviewStats --> CollectionPoint : pointId
```

### 1.3 Guia de descarte e buscas

```mermaid
classDiagram
    direction LR

    class WasteType {
        <<enumeration>>
    }

    class Residue {
        +WasteType type
        +String title
        +String description
        +int minutes
        +int totalSteps
        +tryFromJson(Map json)$ Residue?
        +toJson() Map
    }

    class DisposalGuide {
        +String title
        +String subtitle
        +String warning
        +List~DisposalStep~ steps
        +fromJson(Map json)$ DisposalGuide
        +toJson() Map
    }

    class DisposalStep {
        +String title
        +String description
        +fromJson(Map json)$ DisposalStep
        +toJson() Map
    }

    class WasteSearchStat {
        +WasteType type
        +int count
        +double percentage
    }

    class WasteTypeSearchResult {
        +WasteType type
        +String matchedTerm
        +int score
    }

    Residue "1" --> "1" WasteType : type
    Residue "1" ..> "0..1" DisposalGuide : guia do mesmo WasteType
    DisposalGuide "1" *-- "1..*" DisposalStep : steps
    WasteSearchStat --> WasteType
    WasteTypeSearchResult --> WasteType
```

### Relacionamentos

| Relação | Tipo | Significado |
|---|---|---|
| `CollectionPoint` → `WasteType` | Associação (N:N) | Um ponto aceita um ou mais tipos de resíduo; o filtro do mapa usa `acceptsAny`. |
| `Campaign` → `WasteType` | Associação (N:N) | Uma campanha coleta um ou mais tipos de resíduo. |
| `PointSuggestion` → `WasteType` | Associação (N:N) | O cidadão informa quais resíduos o local sugerido aceitaria. |
| `PointSuggestion` ⇢ `CollectionPoint` | Dependência | O administrador pode converter uma sugestão em ponto de coleta (RN07). |
| `PointReview` → `CollectionPoint` | Associação (N:1) | Cada avaliação referencia um ponto pelo `pointId`; um ponto pode ter várias avaliações. |
| `PointReviewStats` ⇢ `PointReview` | Dependência | Estatísticas (média e tags mais votadas) calculadas a partir das avaliações. |
| `Residue` → `WasteType` | Associação (1:1) | Cada item do guia representa um tipo de resíduo. |
| `Residue` ⇢ `DisposalGuide` | Dependência | O passo a passo é encontrado pelo `WasteType` do resíduo (`stepsGuideFor`). |
| `DisposalGuide` ◆ `DisposalStep` | Composição | Os passos só existem dentro do guia. |
| `WasteSearchStat` → `WasteType` | Associação | Contagem de buscas por tipo de resíduo, usada no ranking do guia. |

## 2. Camada de dados e serviços

As telas não acessam o Firestore diretamente. Elas usam **casos de uso** e **notifiers** que dependem de contratos (`I*Repository`). As implementações concretas, coordenadas pelo `AppDataSync`, decidem entre dados remotos, cache local e dados empacotados no app (offline-first). Para facilitar a leitura, a camada foi dividida em diagramas menores.

### 2.1 Coordenação da sincronização

```mermaid
classDiagram
    direction LR

    class AppDataSync {
        <<ChangeNotifier>>
        +bool isOnline
        +bool isStale
        +bool isSyncing
        +DateTime? lastUpdated
        +int pendingSuggestionsCount
        +initialize() Future
        +refreshAll() Future
        +submitSuggestion(PointSuggestion s) Future
    }

    class CollectPointsRepository
    class CampaignsRepository
    class DisposalGuideRepositorySynced
    class PointSuggestionsRepository
    class PointReviewsRepository
    class ConnectivityService {
        +checkNow() Future~bool~
    }

    AppDataSync *-- CollectPointsRepository
    AppDataSync *-- CampaignsRepository
    AppDataSync *-- DisposalGuideRepositorySynced
    AppDataSync *-- PointSuggestionsRepository
    AppDataSync *-- PointReviewsRepository : reenvia fila
    AppDataSync --> ConnectivityService
```

### 2.2 Contratos de domínio: pontos, campanhas e sugestões

```mermaid
classDiagram
    direction TB

    class ICollectPointsRepository {
        <<interface>>
        +DateTime? lastUpdated
        +bool isStale
        +bool hasRemoteSource
        +loadOffline() Future
        +refresh() Future
        +upsertLocalPoints(List points) Future
    }

    class ICampaignsRepository {
        <<interface>>
        +DateTime? lastUpdated
        +bool isStale
        +bool hasRemoteSource
        +loadOffline() Future
        +refresh() Future
    }

    class IPointSuggestionsRepository {
        <<interface>>
        +submit(PointSuggestion s) Future
        +flushPending() Future~int~
        +pendingCount() Future~int~
    }

    class CollectPointsRepository
    class CampaignsRepository
    class PointSuggestionsRepository

    ICollectPointsRepository <|.. CollectPointsRepository
    ICampaignsRepository <|.. CampaignsRepository
    IPointSuggestionsRepository <|.. PointSuggestionsRepository
```

### 2.3 Contratos de domínio: favoritos, avaliações, buscas e guia

```mermaid
classDiagram
    direction TB

    class IFavoritesRepository {
        <<interface>>
        +getFavoriteIds() Future
        +isFavorite(String pointId) Future~bool~
        +addFavorite(String pointId) Future
        +removeFavorite(String pointId) Future
        +toggleFavorite(String pointId) Future~bool~
        +watchFavoriteIds() Stream
    }

    class IPointReviewsRepository {
        <<interface>>
        +submitReview(PointReview r) Future
        +getReviewsForPoint(String pointId) Future
        +getStatsForPoint(String pointId) Future
        +flushPending() Future~int~
        +pendingCount() Future~int~
    }

    class IWasteSearchAnalyticsRepository {
        <<interface>>
        +recordSearch(WasteType type) Future
        +getSearchCount(WasteType type) Future~int~
        +getRankedStats() Future
        +clear() Future
    }

    class DisposalGuideRepository {
        <<interface>>
        +listResidues() List~Residue~
        +stepsGuideFor(WasteType type) DisposalGuide?
    }

    class FavoritesRepository
    class PointReviewsRepository
    class WasteSearchAnalyticsRepository
    class DisposalGuideRepositoryLocal
    class DisposalGuideRepositorySynced

    IFavoritesRepository <|.. FavoritesRepository
    IPointReviewsRepository <|.. PointReviewsRepository
    IWasteSearchAnalyticsRepository <|.. WasteSearchAnalyticsRepository
    DisposalGuideRepository <|.. DisposalGuideRepositoryLocal
    DisposalGuideRepository <|.. DisposalGuideRepositorySynced
    DisposalGuideRepositorySynced --> DisposalGuideRepositoryLocal : conteúdo padrão
```

### 2.4 Casos de uso

```mermaid
classDiagram
    direction LR

    class FilterPointsUseCase {
        +execute(points, selectedWasteTypes, onlyFavorites, favoriteIds) List
    }

    class GetNearestPointUseCase {
        +execute(userLatitude, userLongitude, points, selectedWasteTypes, maxDistanceMeters) NearestPointResult?
    }

    class NearestPointResult {
        +CollectionPoint point
        +double distanceMeters
    }

    class SubmitSuggestionUseCase {
        +execute(name, address, acceptedWasteTypes, hours, latitude, longitude) Future
    }

    class GetCampaignsUseCase {
        +executeOffline(filter) Future
        +executeRefresh(filter) Future
        +filterList(campaigns, filter) List
    }

    class CampaignStatusFilter {
        <<enumeration>>
        all
        active
        upcoming
    }

    class IPointSuggestionsRepository {
        <<interface>>
    }
    class ICampaignsRepository {
        <<interface>>
    }

    GetNearestPointUseCase ..> NearestPointResult : retorna
    SubmitSuggestionUseCase --> IPointSuggestionsRepository
    GetCampaignsUseCase --> ICampaignsRepository
    GetCampaignsUseCase ..> CampaignStatusFilter
```

### 2.5 Camada de apresentação (estado com Provider)

```mermaid
classDiagram
    direction LR

    class PointsNotifier {
        <<ChangeNotifier>>
        +List points
        +List filteredPoints
        +Set selectedWasteTypes
        +CollectionPoint? selectedPoint
        +bool isListView
        +loadOffline() Future
        +refresh() Future
        +toggleWasteFilter(WasteType type)
        +selectPoint(CollectionPoint? p)
        +toggleListView()
    }

    class CampaignsNotifier {
        <<ChangeNotifier>>
        +List campaigns
        +List filteredCampaigns
        +CampaignStatusFilter filter
        +loadCampaigns() Future
        +refreshCampaigns() Future
        +setFilter(CampaignStatusFilter f)
    }

    class FavoritesNotifier {
        <<ChangeNotifier>>
        +Set favoriteIds
        +isFavorite(String pointId) bool
        +toggleFavorite(String pointId) Future~bool~
    }

    class CampaignRemindersNotifier {
        <<ChangeNotifier>>
        +Set activeCampaignIds
        +isReminderActive(String id) bool
        +toggleReminder(Campaign c) Future~bool~
    }

    class LocationNotifier {
        <<ChangeNotifier>>
        +UserLocation? userLocation
        +bool hasLocation
        +locateUser() Future
        +openSettings() Future
    }

    class SyncNotifier {
        <<ChangeNotifier>>
        +bool isOnline
        +bool isStale
        +int pendingSuggestionsCount
        +refreshAll() Future
    }

    class FilterPointsUseCase
    class GetNearestPointUseCase
    class GetCampaignsUseCase
    class IFavoritesRepository {
        <<interface>>
    }
    class CampaignReminderService
    class LocationService
    class AppDataSync

    PointsNotifier --> FilterPointsUseCase
    PointsNotifier --> GetNearestPointUseCase
    CampaignsNotifier --> GetCampaignsUseCase
    FavoritesNotifier --> IFavoritesRepository
    CampaignRemindersNotifier --> CampaignReminderService
    LocationNotifier --> LocationService
    SyncNotifier --> AppDataSync
```

### 2.6 Painel administrativo e serviços

```mermaid
classDiagram
    direction TB

    class AdminDatabaseRepository {
        <<interface>>
        +fetchPoints() Future
        +savePoint(CollectionPoint p) Future
        +savePointsBatch(List points) Future
        +deletePoint(String id) Future
        +fetchCampaigns() Future
        +saveCampaign(Campaign c) Future
        +deleteCampaign(String id) Future
        +fetchSuggestions() Future
        +updateSuggestionStatus(String id, SuggestionStatus s) Future
        +deleteSuggestion(String id) Future
    }
    class FirestoreAdminDatabaseRepository

    class AdminAuthService {
        +isAuthorized() Future~bool~
        +authenticate(String key) Future
        +remainingLockoutSeconds() Future~int~
        +revokeAuthorization() Future
    }

    class CampaignReminderService {
        +isReminderActive(String id) Future~bool~
        +setReminder(Campaign c) Future~bool~
        +cancelReminder(String id) Future~bool~
        +toggleReminder(Campaign c) Future~bool~
    }

    class INotificationScheduler {
        <<interface>>
        +initialize() Future
        +scheduleNotification(id, title, body, scheduledDate) Future
        +cancelNotification(int id) Future
    }
    class LocalNotificationsScheduler
    class InMemoryNotificationScheduler

    class ResidueSearchService {
        +search(String query) List
    }

    class LocalStore {
        <<interface>>
        +getString(String key) Future
        +setString(String key, String value) Future
        +getInt(String key) Future
        +setInt(String key, int value) Future
        +remove(String key) Future
    }
    class SharedPreferencesLocalStore
    class InMemoryLocalStore

    AdminDatabaseRepository <|.. FirestoreAdminDatabaseRepository
    CampaignReminderService --> INotificationScheduler
    INotificationScheduler <|.. LocalNotificationsScheduler
    INotificationScheduler <|.. InMemoryNotificationScheduler
    LocalStore <|.. SharedPreferencesLocalStore
    LocalStore <|.. InMemoryLocalStore
    AdminAuthService --> LocalStore : token e bloqueio
```

### Responsabilidades

| Classe | Responsabilidade |
|---|---|
| `AppDataSync` | Raiz de composição dos dados. Inicializa os repositórios, monitora a conectividade e, ao reconectar, atualiza os dados e reenvia as filas de sugestões e avaliações. |
| `CollectPointsRepository` / `CampaignsRepository` | Leem do Firestore, gravam cache versionado no `SharedPreferences` e caem para o JSON empacotado em `assets/data` quando não há rede nem cache. |
| `DisposalGuideRepository` | Contrato usado pelas telas do guia. A versão `Synced` mescla o conteúdo remoto com o local, garantindo o guia offline (RNF09). |
| `PointSuggestionsRepository` / `PointReviewsRepository` | Enviam dados anônimos ao Firestore e mantêm filas offline protegidas por mutex (RN04, RN19). |
| `FavoritesRepository` | Guarda os IDs dos pontos favoritos no aparelho (RN18). |
| `WasteSearchAnalyticsRepository` | Conta buscas por tipo de resíduo e gera o ranking com percentual (RN23). |
| Casos de uso | Concentram as regras de negócio independentes de tela: filtro de pontos, ponto mais próximo, validação de sugestão e filtro de campanhas. |
| Notifiers | Guardam o estado das telas e avisam a interface quando ele muda (padrão Provider + `ChangeNotifier`). |
| `CampaignReminderService` | Agenda e cancela as notificações locais dos lembretes de campanha (RN21). |
| `ResidueSearchService` | Encontra o tipo de resíduo a partir de termos populares e sinônimos (RN22). |
| `AdminDatabaseRepository` | Operações de CRUD do painel administrativo, incluindo gravação de pontos em lote. |
| `AdminAuthService` | Valida a chave do administrador com SHA-256 e aplica o bloqueio por tentativas (RN05, RN06). |
| `LocalStore` | Abstração de armazenamento local, com versão real e versão em memória para testes. |
