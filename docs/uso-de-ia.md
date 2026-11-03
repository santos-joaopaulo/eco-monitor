# Uso de IA


## Padrões de Codificação

Estes padrões devem ser fornecidos ao LLM ao solicitar geração ou modificação de código Dart/Flutter.


### Idioma

- Todo o código (identificadores, comentários, nomes de variáveis, classes, métodos) deve ser escrito em **inglês**.
- Exceção: strings exibidas ao usuário (labels, tooltips, textos de UI) devem ser em **português**.


### Strings

- Preferir aspas duplas (`"`) sobre aspas simples (`'`).
- Exceção: strings que contêm aspas duplas internas podem usar aspas simples.


### Comentários

- **Não** incluir comentários padrão do framework (explicações educacionais de `setState`, `build`, widgets de layout, "TRY THIS", etc.).
- **Manter** comentários de estrutura que organizam o arquivo, no formato:

```dart
// Section name ------------------------------------------------------------ //
```

- Exemplos:

```dart
// Init -------------------------------------------------------------------- //
// Classes ----------------------------------------------------------------- //
// Methods ----------------------------------------------------------------- //
```


### Quebras de Linha

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
