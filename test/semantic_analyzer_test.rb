require_relative "test_helper"
require_relative "../lib/forge/lexer"
require_relative "../lib/forge/parser"
require_relative "../lib/forge/semantic_analyzer"
require_relative "../lib/forge/errors"

class SemanticAnalyzerTest < Minitest::Test
  def analyze(source, filename: "schema.forge")
    tokens = Forge::Lexer.new(source).tokenize
    doc = Forge::Parser.new(tokens).parse
    Forge::SemanticAnalyzer.new(filename).analyze(doc)
  end

  def test_valid_document_no_errors
    errors = analyze(<<~FORGE)
      message User {
        string name;
        int age;
      }
    FORGE
    assert_equal 0, errors.length
  end

  def test_empty_document_no_errors
    errors = analyze("")
    assert_equal 0, errors.length
  end

  def test_multiple_valid_messages
    errors = analyze(<<~FORGE)
      message User {
        string name;
      }
      message Post {
        string title;
      }
    FORGE
    assert_equal 0, errors.length
  end

  def test_empty_message_no_errors
    errors = analyze("message Empty { }")
    assert_equal 0, errors.length
  end

  def test_unknown_type_detected
    errors = analyze(<<~FORGE)
      message User {
        Usr name;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/unknown type `Usr`/, errors[0].message)
  end

  def test_unknown_type_in_multiple_fields
    errors = analyze(<<~FORGE)
      message User {
        string name;
        Usr ref;
        Foobar id;
      }
    FORGE
    assert_equal 2, errors.length
    assert_match(/unknown type `Usr`/, errors[0].message)
    assert_match(/unknown type `Foobar`/, errors[1].message)
  end

  def test_duplicate_field_names
    errors = analyze(<<~FORGE)
      message User {
        string name;
        int name;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/duplicate field `name`/, errors[0].message)
  end

  def test_duplicate_field_names_multiple
    errors = analyze(<<~FORGE)
      message User {
        string name;
        int name;
        string name;
      }
    FORGE
    assert_equal 2, errors.length
    errors.each do |e|
      assert_match(/duplicate field `name`/, e.message)
    end
  end

  def test_errors_include_filename
    errors = analyze("message User { Usr name; }", filename: "test.forge")
    assert_match(/^test\.forge:/, errors[0].to_s)
  end

  def test_default_filename
    tokens = Forge::Lexer.new("message User { Usr name; }").tokenize
    doc = Forge::Parser.new(tokens).parse
    errors = Forge::SemanticAnalyzer.new.analyze(doc)
    assert_match(/^input\.forge:/, errors[0].to_s)
  end

  def test_error_includes_line_and_column
    errors = analyze(<<~FORGE)
      message User {
        Usr name;
      }
    FORGE
    assert_equal 2, errors[0].line
    assert_equal 3, errors[0].column
  end

  def test_error_diagnostic_format
    errors = analyze(<<~FORGE)
      message User {
        Usr name;
      }
    FORGE
    assert_equal "schema.forge:2:3: unknown type `Usr`", errors[0].to_s
  end

  def test_duplicate_field_error_diagnostic_format
    errors = analyze(<<~FORGE)
      message User {
        string name;
        int name;
      }
    FORGE
    assert_equal "schema.forge:3:3: duplicate field `name`", errors[0].to_s
  end

  def test_duplicate_message_error_diagnostic_format
    errors = analyze(<<~FORGE)
      message User { string name; }
      message User { int age; }
    FORGE
    assert_equal "schema.forge:2:1: duplicate message `User`", errors[0].to_s
  end

  def test_duplicate_field_in_second_message
    errors = analyze(<<~FORGE)
      message User {
        string name;
      }
      message Post {
        string title;
        string title;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/duplicate field `title`/, errors[0].message)
  end

  def test_unknown_type_does_not_affect_other_messages
    errors = analyze(<<~FORGE)
      message User {
        Usr ref;
      }
      message Post {
        string title;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/unknown type `Usr`/, errors[0].message)
  end

  def test_symbol_table_populated
    tokens = Forge::Lexer.new("message User { string name; }").tokenize
    doc = Forge::Parser.new(tokens).parse
    analyzer = Forge::SemanticAnalyzer.new("test.forge")
    analyzer.analyze(doc)
    table = analyzer.symbol_table
    assert table.message?("User")
    assert table.known_type?("string")
    refute table.known_type?("Usr")
  end

  def test_symbol_table_knows_all_built_in_types
    table = Forge::SemanticAnalyzer.new.symbol_table
    %w[string int float bool].each do |t|
      assert table.known_type?(t)
    end
  end

  def test_semantic_error_is_standard_error
    errors = analyze("message User { Usr name; }")
    assert_kind_of StandardError, errors[0]
    assert_kind_of Forge::SemanticError, errors[0]
  end

  def test_analyze_returns_array
    assert_instance_of Array, analyze("")
  end

  def test_multiple_errors_collected_not_raised
    errors = analyze(<<~FORGE)
      message User {
        Usr ref;
        string name;
        string name;
      }
    FORGE
    assert_equal 2, errors.length
  end

  def test_duplicate_message_names
    errors = analyze(<<~FORGE)
      message User {
        string name;
      }
      message User {
        int age;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/duplicate message `User`/, errors[0].message)
  end

  def test_duplicate_fields_and_unknown_type_same_message
    errors = analyze(<<~FORGE)
      message User {
        string name;
        string name;
        Foobar id;
      }
    FORGE
    assert_equal 2, errors.length
    types = errors.map(&:message)
    assert(types.any? { |m| m.include?("duplicate field `name`") })
    assert(types.any? { |m| m.include?("unknown type `Foobar`") })
  end

  def test_message_typed_field_valid
    errors = analyze(<<~FORGE)
      message User {
        string name;
      }
      message Post {
        User author;
      }
    FORGE
    assert_equal 0, errors.length
  end

  def test_forward_message_reference_valid
    errors = analyze(<<~FORGE)
      message Post {
        User author;
      }
      message User {
        string name;
      }
    FORGE
    assert_equal 0, errors.length
  end

  def test_self_reference_valid
    errors = analyze("message Node { Node next; }")
    assert_equal 0, errors.length
  end

  def test_enum_typed_field_valid
    errors = analyze(<<~FORGE)
      enum Status {
        ACTIVE;
        INACTIVE;
      }
      message User {
        Status status;
      }
    FORGE
    assert_equal 0, errors.length
  end

  def test_duplicate_enum_name
    errors = analyze(<<~FORGE)
      enum Status {
        ACTIVE;
      }
      enum Status {
        INACTIVE;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/duplicate type `Status`/, errors[0].message)
  end

  def test_enum_name_clashing_with_message
    errors = analyze(<<~FORGE)
      message Status {
        string name;
      }
      enum Status {
        ACTIVE;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/duplicate type `Status`/, errors[0].message)
  end

  def test_message_name_clashing_with_enum
    errors = analyze(<<~FORGE)
      enum Status {
        ACTIVE;
      }
      message Status {
        string name;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/duplicate type `Status`/, errors[0].message)
  end

  def test_duplicate_enum_value
    errors = analyze(<<~FORGE)
      enum Status {
        ACTIVE;
        ACTIVE;
      }
    FORGE
    assert_equal 1, errors.length
    assert_match(/duplicate enum value `ACTIVE`/, errors[0].message)
  end

  def test_empty_enum_rejected
    errors = analyze("enum Status { }")
    assert_equal 1, errors.length
    assert_match(/enum `Status` has no values/, errors[0].message)
  end

  def test_array_of_unknown_type
    errors = analyze("message User { Unknown[] items; }")
    assert_equal 1, errors.length
    assert_match(/unknown type `Unknown`/, errors[0].message)
  end

  def test_map_with_string_key_valid
    errors = analyze("message User { map<string, int> scores; }")
    assert_equal 0, errors.length
  end

  def test_map_with_int_key_valid
    errors = analyze("message User { map<int, string> names; }")
    assert_equal 0, errors.length
  end

  def test_map_with_bool_key_invalid
    errors = analyze("message User { map<bool, int> scores; }")
    assert_equal 1, errors.length
    assert_match(/map key must be `string` or `int`/, errors[0].message)
  end

  def test_map_with_message_key_invalid
    errors = analyze("message Post { }
message User { map<Post, int> scores; }")
    assert_equal 1, errors.length
    assert_match(/map key must be/, errors[0].message)
  end

  def test_map_with_unknown_value_type
    errors = analyze("message User { map<string, Unknown> scores; }")
    assert_equal 1, errors.length
    assert_match(/unknown type `Unknown`/, errors[0].message)
  end

  def test_optional_field_valid
    errors = analyze("message User { int age?; string name; }")
    assert_equal 0, errors.length
  end

  def test_array_of_message_valid
    errors = analyze("message Post { string title; }
message User { Post[] posts; }")
    assert_equal 0, errors.length
  end
end
