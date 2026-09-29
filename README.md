<h1 align="center">Forge</h1>

<p align="center">
  <strong>Schema language for code generation</strong><br />
  Define messages with typed fields in a language-agnostic schema,
  then generate Haxe, TypeScript, and more from the same source.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Ruby-3.x-CC342D?logo=ruby&logoColor=white" alt="Ruby 3.x" />
  <img src="https://img.shields.io/badge/Parser-Recursive--Descent-blue" alt="Recursive Descent" />
  <img src="https://img.shields.io/badge/Lexer-Hand--written-6B4C9A" alt="Hand-written Lexer" />
  <img src="https://img.shields.io/badge/Targets-Haxe%20%7C%20TypeScript-FF681F?label=codegen" alt="Haxe + TypeScript" />
</p>

<p align="center">
  <a href="#schema-language">Schema Language</a> ·
  <a href="#architecture">Architecture</a> ·
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
| [**Project Structure**](#project-structure) | [**Testing**](#testing) |

---

## Schema Language

Forge defines messages with typed fields:

```
message User {
    string id;
    string name;
    int age;
    bool active;
}
```

Each message has a name and zero or more fields. Every field has a type and a
name, terminated by a semicolon. Comments use `//` and are ignored by the lexer.

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
Source → Lexer → Tokens → Parser → AST → [Semantic Analysis] → [Code Generation]
```

### Lexer

Single-pass character scanner. No regex tokenization. Produces tokens with
source locations (line, column). Reports errors with exact positions.

| Token Type | Examples |
|-----------|----------|
| `KEYWORD` | `message` |
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

Three node types — `Document` (root, contains messages), `Message` (name +
fields), and `Field` (type name + field name). All nodes carry source locations.
The AST is intentionally language-independent so that multiple code generators
can consume the same parse tree.

The AST is kept separate from Haxe because TypeScript, Go, and Rust generators
will eventually use the same structure. Keeping it generic means code generators
don't need to handle parsing — they just walk the tree.

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

### Symbol Table

The symbol table is a lookup structure used by the semantic analyzer. It tracks
registered message names and known types (built-in + user-defined). Separated
from the AST because the AST is a parse tree (syntax), while the symbol table
is a semantic structure — they change for different reasons and serve different
purposes. This separation means you can re-analyze with a different symbol table
without re-parsing.

The symbol table is designed for future expansion: `add_type` will eventually
register user-defined types, and the registry will grow to cover enums, services,
imports, and cross-file references.

### Grammar

```
document      := message_declaration*
message       := 'message' IDENTIFIER '{' field* '}'
field         := TYPE IDENTIFIER ';'
```

---

## Project Structure

```
lib/
  forge.rb                # Main entry point
  forge/
    errors.rb             # LexerError, ParserError, SemanticError
    token.rb              # Token struct
    lexer.rb              # Hand-written lexer
    ast.rb                # AST node classes
    parser.rb             # Recursive-descent parser
    semantic_analyzer.rb  # Semantic analysis + symbol table
    version.rb            # Version constant
test/
  test_helper.rb          # Minitest setup
  forge_test.rb           # Sanity tests
  lexer_test.rb           # Lexer tests
  parser_test.rb          # Parser tests
  semantic_analyzer_test.rb  # Semantic analysis tests
```

---

## Testing

Tests use Minitest. Run the full suite:

```bash
bundle exec rake test
```

Each phase includes its own test file. Lexer and parser tests cover both
happy paths and error cases (malformed input, missing braces, missing
semicolons, invalid declarations).

---

## License

MIT
