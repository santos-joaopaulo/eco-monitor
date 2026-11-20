# Uso de IA


## Padrões de Codificação

Estes padrões devem ser fornecidos ao LLM ao solicitar geração ou modificação de código Dart/Flutter.


### Idioma

- Todo o código (identificadores, nomes de variáveis, classes, métodos) deve ser escrito em **inglês**.
- Comentários devem ser escritos em **português**.
- Exceção: strings exibidas ao usuário (labels, tooltips, textos de UI) devem ser em **português**.


### Strings

- Preferir aspas duplas (`"`) sobre aspas simples (`'`).
- Exceção: strings que contêm aspas duplas internas podem usar aspas simples.


### Comentários

- **Não** incluir comentários padrão do framework (explicações educacionais de `setState`, `build`, widgets de layout, "TRY THIS", etc.).
- Adicionar comentários **apenas** para lógica importante ou decisões não óbvias — evitar comentários excessivos ou descritivos.
- Comentários devem ser escritos em **português**.
- **Manter** comentários de estrutura que organizam o arquivo, com **duas linhas em branco acima e abaixo** e 80 caractéres no total, somente esse tipo de comentário deve ser escrito em **inglês**, seguindo o formato:

```dart


// Section name ------------------------------------------------------------ //


```

- Exemplos:

```dart


// Init -------------------------------------------------------------------- //


// Classes ----------------------------------------------------------------- //


// Methods ----------------------------------------------------------------- //


```

- Se durante o trabalho em um arquivo forem observadas violações desses padrões, **corrigi-las** — mantendo o foco na tarefa atual.


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
