require_relative "test_helper"
require_relative "../lib/forge/lexer"
require_relative "../lib/forge/parser"
require_relative "../lib/forge/errors"

class ParserTest < Minitest::Test
  def parse(source)
    tokens = Forge::Lexer.new(source).tokenize
    Forge::Parser.new(tokens).parse
  end

  def test_empty_document
    doc = parse("")
    assert_equal 0, doc.messages.length
  end

  def test_single_message
    doc = parse("message User { }")
    assert_equal 1, doc.messages.length
    assert_equal "User", doc.messages[0].name
  end

  def test_message_with_fields
    doc = parse(<<~FORGE)
      message User {
        string name;
        int age;
      }
    FORGE
    msg = doc.messages[0]
    assert_equal "User", msg.name
    assert_equal 2, msg.fields.length
    assert_equal "name", msg.fields[0].name
    assert_equal "string", msg.fields[0].type_name
    assert_equal "age", msg.fields[1].name
    assert_equal "int", msg.fields[1].type_name
  end

  def test_all_field_types
    doc = parse(<<~FORGE)
      message All {
        string a;
        int b;
        float c;
        bool d;
      }
    FORGE
    assert_equal 4, doc.messages[0].fields.length
    types = doc.messages[0].fields.map(&:type_name)
    assert_equal %w[string int float bool], types
  end

  def test_multiple_messages
    doc = parse(<<~FORGE)
      message User {
        string name;
      }
      message Post {
        string title;
      }
    FORGE
    assert_equal 2, doc.messages.length
    assert_equal "User", doc.messages[0].name
    assert_equal "Post", doc.messages[1].name
  end

  def test_message_line_location
    doc = parse("message User { }")
    assert_equal 1, doc.messages[0].line
    assert_equal 1, doc.messages[0].column
  end

  def test_second_message_line_location
    doc = parse("message User { }\nmessage Post { }")
    assert_equal 2, doc.messages[1].line
  end

  def test_field_location
    doc = parse(<<~FORGE)
      message User {
        string name;
      }
    FORGE
    field = doc.messages[0].fields[0]
    assert_equal 2, field.line
    assert_equal 3, field.column
  end

  def test_missing_closing_brace
    err = assert_raises(Forge::ParserError) { parse("message User {") }
    assert_match(/Expected RBRACE/, err.message)
    assert_match(/1:15/, err.message)
  end

  def test_missing_opening_brace
    err = assert_raises(Forge::ParserError) { parse("message User string name; }") }
    assert_match(/Expected LBRACE/, err.message)
  end

  def test_missing_semicolon
    err = assert_raises(Forge::ParserError) { parse("message User { string name }") }
    assert_match(/Expected SEMICOLON/, err.message)
    assert_match(/1:28/, err.message)
  end

  def test_missing_field_name
    err = assert_raises(Forge::ParserError) { parse("message User { string; }") }
    assert_match(/Expected IDENTIFIER/, err.message)
  end

  def test_missing_message_name
    err = assert_raises(Forge::ParserError) { parse("message { }") }
    assert_match(/Expected IDENTIFIER/, err.message)
  end

  def test_not_a_message_declaration
    err = assert_raises(Forge::ParserError) { parse("foo") }
    assert_match(/Expected KEYWORD/, err.message)
  end

  def test_missing_type_in_field
    err = assert_raises(Forge::ParserError) { parse("message User { name; }") }
    assert_match(/Expected IDENTIFIER, got SEMICOLON/, err.message)
  end

  def test_malformed_empty_braces
    doc = parse("message User { }")
    assert_equal 0, doc.messages[0].fields.length
  end

  def test_fields_without_semicolon_and_brace
    err = assert_raises(Forge::ParserError) { parse("message User { string name string age }") }
    assert_match(/Expected SEMICOLON/, err.message)
  end

  def test_two_messages_first_valid_second_missing_brace
    err = assert_raises(Forge::ParserError) { parse("message A { }\nmessage B {") }
    assert_match(/Expected RBRACE/, err.message)
    assert_match(/2:/, err.message)
  end

  def test_message_with_many_fields
    source = "message Big {\n" + (1..20).map { |i| "  int field#{i};" }.join("\n") + "\n}"
    doc = parse(source)
    assert_equal 20, doc.messages[0].fields.length
    assert_equal "field1", doc.messages[0].fields[0].name
    assert_equal "field20", doc.messages[0].fields[19].name
  end

  def test_comment_between_fields
    doc = parse(<<~FORGE)
      message User {
        string name;
        // comment
        int age;
      }
    FORGE
    assert_equal 2, doc.messages[0].fields.length
  end

  def test_document_has_no_location
    doc = parse("message User { }")
    assert_respond_to doc, :messages
    refute_respond_to doc, :line
  end

  def test_error_includes_line_and_column
    err = assert_raises(Forge::ParserError) { parse("message User { string name string age; }") }
    assert_match(/\d+:\d+/, err.message)
  end

  def test_parse_returns_document
    result = parse("message A { }")
    assert_instance_of Forge::Document, result
  end

  def test_ast_nodes_are_target_independent
    doc = parse(<<~FORGE)
      message User {
        string name;
      }
    FORGE
    msg = doc.messages[0]
    assert_instance_of Forge::Message, msg
    assert_instance_of Forge::Field, msg.fields[0]
    refute msg.respond_to?(:to_haxe)
    refute msg.fields[0].respond_to?(:to_haxe)
  end

  def test_enum_declaration
    doc = parse("enum Status { ACTIVE; INACTIVE; }")
    assert_equal 0, doc.messages.length
    assert_equal 1, doc.enums.length
    enum = doc.enums[0]
    assert_equal "Status", enum.name
    assert_equal %w[ACTIVE INACTIVE], enum.values
    assert_equal 1, enum.line
    assert_equal 1, enum.column
  end

  def test_enum_and_messages
    doc = parse(<<~FORGE)
      enum Status {
        ACTIVE;
      }
      message User {
        string name;
      }
    FORGE
    assert_equal 1, doc.enums.length
    assert_equal 1, doc.messages.length
  end

  def test_empty_enum_values
    doc = parse("enum Status { }")
    assert_equal [], doc.enums[0].values
  end

  def test_enum_missing_semicolon
    err = assert_raises(Forge::ParserError) { parse("enum Status { ACTIVE }") }
    assert_match(/Expected SEMICOLON/, err.message)
  end

  def test_enum_missing_name
    err = assert_raises(Forge::ParserError) { parse("enum { ACTIVE; }") }
    assert_match(/Expected IDENTIFIER/, err.message)
  end

  def test_enum_node_target_independent
    doc = parse("enum Status { ACTIVE; }")
    enum = doc.enums[0]
    assert_instance_of Forge::Enum, enum
    refute enum.respond_to?(:to_haxe)
  end

  def test_optional_field
    doc = parse("message User { int age?; }")
    field = doc.messages[0].fields[0]
    assert_equal "age", field.name
    assert field.optional
    assert_equal "int", field.type_name
    assert field.type.named?
  end

  def test_non_optional_field_default
    doc = parse("message User { int age; }")
    refute doc.messages[0].fields[0].optional
  end

  def test_array_field
    doc = parse("message User { string[] tags; }")
    field = doc.messages[0].fields[0]
    assert field.type.array?
    assert_equal "string", field.type.element.name
  end

  def test_map_field
    doc = parse("message User { map<string, int> scores; }")
    field = doc.messages[0].fields[0]
    assert field.type.map?
    assert_equal "string", field.type.key_type.name
    assert_equal "int", field.type.value_type.name
  end

  def test_array_of_message_field
    doc = parse("message User { Post[] posts; }")
    field = doc.messages[0].fields[0]
    assert field.type.array?
    assert_equal "Post", field.type.element.name
  end

  def test_import_declaration
    doc = parse("import \"user.forge\";
message User { string name; }")
    assert_equal 1, doc.imports.length
    assert_equal "user.forge", doc.imports[0].path
    assert_equal 1, doc.imports[0].line
    assert_equal 1, doc.messages.length
  end

  def test_import_missing_string
    err = assert_raises(Forge::ParserError) { parse("import user;") }
    assert_match(/Expected STRING/, err.message)
  end

  def test_import_missing_semicolon
    err = assert_raises(Forge::ParserError) { parse("import \"user.forge\"") }
    assert_match(/Expected SEMICOLON/, err.message)
  end

  def test_map_missing_comma
    err = assert_raises(Forge::ParserError) { parse("message User { map<string int> x; }") }
    assert_match(/Expected COMMA/, err.message)
  end

  def test_map_missing_gt
    err = assert_raises(Forge::ParserError) { parse("message User { map<string, int x; }") }
    assert_match(/Expected GT/, err.message)
  end

  def test_array_missing_rbracket
    err = assert_raises(Forge::ParserError) { parse("message User { string[ x; }") }
    assert_match(/Expected RBRACKET/, err.message)
  end
end
