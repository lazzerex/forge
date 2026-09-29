# Forge

A schema language for generating Haxe and TypeScript code from message definitions.

Forge lets you define messages with typed fields in a simple, language-agnostic schema format, then generate target-language code from those definitions.

```
message User {
    string id;
    string name;
    int age;
    bool active;
}
```

## Installation

Requires Ruby 3.x.

```
bundle install
```

## Usage

```
bundle exec rake test
```

## Project Structure

```
lib/
  forge.rb              # Main entry point
  forge/
    errors.rb           # LexerError, ParserError
    token.rb            # Token struct
    lexer.rb            # Hand-written lexer
    ast.rb              # AST node classes (Document, Message, Field)
    parser.rb           # Recursive-descent parser
    version.rb          # Version constant
test/
  test_helper.rb        # Minitest setup
  forge_test.rb         # Basic sanity tests
  lexer_test.rb         # Lexer tests (25 tests)
  parser_test.rb        # Parser tests (24 tests)
```

## Design

**Lexer**: Single-pass character scanner. No regex tokenization. Produces tokens with source locations (line, column). Supports `//` line comments, whitespace skipping, and error reporting with positions.

**Parser**: Hand-written recursive-descent parser. Consumes the token stream and produces a target-independent AST. Does not contain any Haxe-specific or TypeScript-specific logic.

**AST**: Three node types — `Document` (root, contains messages), `Message` (name + fields), and `Field` (type name + field name). All nodes carry source locations for diagnostics. The AST is intentionally language-independent so that multiple code generators (Haxe, TypeScript, Go, Rust) can consume the same parse tree.

**Grammar**:

```
document      := message_declaration*
message       := 'message' IDENTIFIER '{' field* '}'
field         := TYPE IDENTIFIER ';'
```

**Built-in types**: `string`, `int`, `float`, `bool`

## Testing

Tests use Minitest. Run all tests:

```
bundle exec rake test
```

## License

MIT
