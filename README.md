<h1 align="center">Forge</h1>

<p align="center">
  <strong>Schema language for code generation</strong><br />
  Define messages with typed fields in a language-agnostic schema,
  then generate Haxe, TypeScript, and more from the same source.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Ruby-3.x-CC342D?logo=ruby&logoColor=white" alt="Ruby 3.x" />
  <img src="https://img.shields.io/badge/Lexer-6B4C9A" alt="Lexer" />
  <img src="https://img.shields.io/badge/Parser-Recursive--Descent-blue" alt="Recursive Descent" />
  <img src="https://img.shields.io/badge/Testing-Minitest-CC342D?logo=ruby&logoColor=white" alt="Minitest" />
  <img src="https://img.shields.io/badge/Build-Rake-CC342D?logo=rake&logoColor=white" alt="Rake" />
  <img src="https://img.shields.io/badge/Target-Haxe-FF681F?logo=haxe&logoColor=white" alt="Haxe" />
  <img src="https://img.shields.io/badge/Target-TypeScript-3178C6?logo=typescript&logoColor=white" alt="TypeScript" />
  <img src="https://img.shields.io/badge/Target-Go-00ADD8?logo=go&logoColor=white" alt="Go" />
</p>

<p align="center">
  <a href="#schema-language">Schema Language</a> ·
  <a href="#architecture">Architecture</a> ·
  <a href="#cli">CLI</a> ·
  <a href="#project-structure">Structure</a> ·
  <a href="#testing">Testing</a>
</p>

---

## Contents

| | |
|---|---|
| [**Schema Language**](#schema-language) | [**Architecture**](#architecture) |
| [**Built-in Types**](#built-in-types) | [**Semantic Analyzer**](#semantic-analyzer) |
| [**Grammar**](#grammar) | [**Symbol Table**](#symbol-table) |
| [**Haxe Generator**](#haxe-generator) | [**TypeScript Generator**](#typescript-generator) |
| [**Go Generator**](#go-generator) | [**CLI**](#cli) |
| [**Project Structure**](#project-structure) | [**Testing**](#testing) |

---

## Schema Language

Forge defines messages with typed fields, and enums for closed value sets:

```
message User {
    string id;
    string name;
    int age;
    bool active;
    Status status;
    Post latest_post;
}

enum Status {
    ACTIVE;
    INACTIVE;
}

message Post {
    string title;
}
```

Each message has a name and zero or more fields. Every field has a type and a
name, terminated by a semicolon. A field type may be a built-in type, the name
of another message, or the name of an enum — references may point forward.
Enums list their values as identifiers terminated by semicolons. Comments use
`//` and are ignored by the lexer.

### Built-in Types

| Type | Description |
|------|-------------|
| `string` | UTF-8 text |
| `int` | Integer number |
| `float` | Floating-point number |
| `bool` | Boolean value |

---

## Architecture

Forge is a multi-phase compiler frontend. Each phase has a single responsibility:

```
Source → Lexer → Tokens → Parser → AST → Semantic Analysis → Generators → Haxe Source | TypeScript Source | Go Source
```

### Lexer

Single-pass character scanner. No regex tokenization. Produces tokens with
source locations (line, column). Reports errors with exact positions.

| Token Type | Examples |
|-----------|----------|
| `KEYWORD` | `message`, `enum` |
| `TYPE` | `string`, `int`, `float`, `bool` |
| `IDENTIFIER` | `User`, `name`, `age` |
| `LBRACE` / `RBRACE` | `{` / `}` |
| `SEMICOLON` | `;` |
| `EOF` | end of input |

### Parser

Hand-written recursive-descent parser. Consumes the token stream and produces
a target-independent AST. The parser handles syntax only — it accepts any
identifier as a field type and leaves type validation to the semantic analyzer.

### AST

Four node types — `Document` (root, contains messages and enums), `Message`
(name + fields), `Field` (type name + field name), and `Enum` (name + values).
All nodes carry source locations. The AST is intentionally language-independent
so that multiple code generators can consume the same parse tree.

The AST is kept separate from any target language because TypeScript, Go, and
Rust generators all consume the same structure. Keeping it generic means code
generators don't need to handle parsing — they just walk the tree.

### Semantic Analyzer

Walks the AST and validates semantics. Reports all errors without stopping at
the first one. Diagnostics include filename, line, column, and a message:

```
schema.forge:8:5: unknown type `Usr`
schema.forge:12:9: duplicate field `name`
```

**Checks performed:**

| Check | Example diagnostic |
|-------|-------------------|
| Unknown type | `unknown type \`Usr\`` |
| Duplicate field | `duplicate field \`name\`` |
| Duplicate message | `duplicate message \`User\`` |
| Duplicate type (enum vs message/enum) | `duplicate type \`Status\`` |
| Duplicate enum value | `duplicate enum value \`ACTIVE\`` |
| Empty enum | `enum \`Status\` has no values` |

### Symbol Table

The symbol table is a lookup structure used by the semantic analyzer. It tracks
registered message names, enum names, and known types (built-in + user-defined).
Separated from the AST because the AST is a parse tree (syntax), while the
symbol table is a semantic structure — they change for different reasons and
serve different purposes. This separation means you can re-analyze with a
different symbol table without re-parsing.

The analyzer registers all messages and enums first, then checks field types —
so forward references between messages and enums work in any declaration order.

### Grammar

```
document      := (message_declaration | enum_declaration)*
message       := 'message' IDENTIFIER '{' field* '}'
field         := TYPE IDENTIFIER ';'
enum          := 'enum' IDENTIFIER '{' enum_value* '}'
enum_value    := IDENTIFIER ';'
TYPE          := 'string' | 'int' | 'float' | 'bool' | IDENTIFIER
```

---

## Haxe Generator

The first code-generation target. Consumes the target-independent AST and
produces valid Haxe source code.

```
message User {
    string id;
    string name;
    int age;
    bool active;
}
```

generates:

```haxe
class User {
    public var id:String;
    public var name:String;
    public var age:Int;
    public var active:Bool;

    public function new() {
    }
}
```

### Type Mapping

| Forge | Haxe |
|-------|------|
| `string` | `String` |
| `int` | `Int` |
| `float` | `Float` |
| `bool` | `Bool` |

Message- and enum-typed fields are emitted by name (`public var author:User;`).
Enums become Haxe enum abstracts over `String`:

```haxe
enum abstract Status(String) {
    var ACTIVE = "ACTIVE";
    var INACTIVE = "INACTIVE";
}
```

The generator is built behind a `Generator` base class. The TypeScript and Go
generators subclass it, and future targets (Rust) can do the same, providing
their own type mappings and output format without modifying the parser or AST.

---

## TypeScript Generator

Second code-generation target. Consumes the same target-independent AST —
no TypeScript-specific parser or AST nodes exist.

```
message User {
    string id;
    string name;
    int age;
}
```

generates:

```typescript
export interface User {
    id: string;
    name: string;
    age: number;
}
```

### Type Mapping

| Forge | TypeScript |
|-------|------------|
| `string` | `string` |
| `int` | `number` |
| `float` | `number` |
| `bool` | `boolean` |

Output is idiomatic TypeScript (`export interface`), not a mechanical
translation of the Haxe output. The same AST drives both generators; only
the generator class knows its target language. Message- and enum-typed fields
reference types by name (`author: User;`), and enums become string-literal
unions:

```typescript
export type Status = "ACTIVE" | "INACTIVE";
```

---

## Go Generator

Third code-generation target. Same AST, same pipeline — only the generator
class knows Go.

```
message User {
    string id;
    string name;
    int age;
    bool active;
}
```

generates:

```go
package schema

type User struct {
    Id string `json:"id"`
    Name string `json:"name"`
    Age int `json:"age"`
    Active bool `json:"active"`
}
```

### Type Mapping

| Forge | Go |
|-------|-----|
| `string` | `string` |
| `int` | `int` |
| `float` | `float64` |
| `bool` | `bool` |

Fields are exported (first letter capitalized) and carry JSON tags matching
the schema field names. Message- and enum-typed fields use the referenced type
name directly. Enums use the standard Go string-based pattern:

```go
type Status string

const (
    StatusACTIVE Status = "ACTIVE"
    StatusINACTIVE Status = "INACTIVE"
)
```

The package clause is currently fixed to `package schema`.

---

## CLI

The Forge release includes a command-line executable. The compiler pipeline
stays usable as a plain Ruby library — the CLI is a thin wrapper.

```bash
forge check schema.forge

forge generate schema.forge --target haxe
forge generate schema.forge --target haxe --out generated/
forge generate schema.forge --target typescript --out generated/
forge generate schema.forge --target go --out generated/

forge version
forge help
```

Behavior:

* `check` runs lexer, parser, and semantic analysis. Prints diagnostics
  for lexer, parser, and semantic errors with source locations.
* `generate` validates first. No files are written when validation fails.
* With `--out`, writes one file per message and per enum (`User.hx`,
  `User.ts`, `User.go`, `Status.ts`). Without it, prints generated code
  to stdout.
* Exit code `0` on success, `1` on any error.

---

## Project Structure

```
lib/
  forge.rb                    # Main entry point
  forge/
    cli.rb                    # Command-line interface
    errors.rb                 # LexerError, ParserError, SemanticError
    token.rb                  # Token struct
    lexer.rb                  # Hand-written lexer
    ast.rb                    # AST node classes
    parser.rb                 # Recursive-descent parser
    semantic_analyzer.rb      # Semantic analysis + symbol table
    generator.rb              # Base generator abstraction
    generators/
      haxe.rb                 # Haxe code generator
      typescript.rb           # TypeScript code generator
      go.rb                   # Go code generator
    verify.rb                 # Compile-check generated Haxe
    version.rb                # Version constant
runtime/
  forge/
    Runtime.hx                # Haxe runtime helpers
test/
  test_helper.rb              # Minitest setup
  forge_test.rb               # Sanity tests
  lexer_test.rb               # Lexer tests
  parser_test.rb              # Parser tests
  semantic_analyzer_test.rb   # Semantic analysis tests
  generator_test.rb           # Haxe generator tests
  typescript_test.rb          # TypeScript generator tests
  go_test.rb                  # Go generator tests
  cli_test.rb                 # CLI tests
  integration_test.rb         # Haxe compilation integration tests
```

---

## Testing

Tests use Minitest. Run the full suite:

```bash
bundle exec rake test
```

Each phase includes its own test file. Lexer and parser tests cover both
happy paths and error cases (malformed input, missing braces, missing
semicolons, invalid declarations). Generator tests include end-to-end
tests that run the full pipeline from source to generated output for the
Haxe, TypeScript, and Go targets.

CLI tests cover `check` and `generate` for all three targets: exit codes,
diagnostics, file writing, and the guarantee that no files are written
when validation fails.

Integration tests generate Haxe from schemas, compile them with
`haxe --interp`, and verify the output runs correctly. These require
Haxe to be installed.

### Verify command

Compile-check a schema's generated Haxe output:

```bash
bundle exec rake verify[schema.forge]
```

This runs the full pipeline (lexer → parser → semantic analysis → Haxe
generator), writes the output to a temp directory, compiles with
`haxe --interp`, and exits 0 on success, 1 on failure.

---

## License

MIT
