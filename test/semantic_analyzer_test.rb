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

  def test_duplicate_message_names
  def test_errors_include_filename
    errors = analyze("message User { Usr name; }", filename: "test.forge")
    assert_match(/^test\.forge:/, errors[0].to_s)
  end

  def test_default_filename
    errors = analyze("message User { Usr name; }")
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
    assert_equal "schema.forge:3:9: duplicate field `name`", errors[0].to_s
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
end
