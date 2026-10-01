require_relative "test_helper"
require_relative "../lib/forge/lexer"
require_relative "../lib/forge/parser"
require_relative "../lib/forge/semantic_analyzer"
require_relative "../lib/forge/generators/rust"

class RustGeneratorTest < Minitest::Test
  def generate(source)
    tokens = Forge::Lexer.new(source).tokenize
    doc = Forge::Parser.new(tokens).parse
    errors = Forge::SemanticAnalyzer.new("input.forge").analyze(doc)
    assert_equal 0, errors.length
    Forge::RustGenerator.new.generate(doc)
  end

  def test_simple_struct
    output = generate("message User { string name; }")
    assert_includes output, "#[derive(Debug, Clone, PartialEq)]"
    assert_includes output, "pub struct User {"
    assert_includes output, "pub name: String,"
  end

  def test_type_mapping
    output = generate(<<~FORGE)
      message All {
        string a;
        int b;
        float c;
        bool d;
      }
    FORGE
    assert_includes output, "pub a: String,"
    assert_includes output, "pub b: i32,"
    assert_includes output, "pub c: f64,"
    assert_includes output, "pub d: bool,"
  end

  def test_empty_struct
    output = generate("message Empty { }")
    assert_includes output, "pub struct Empty {}"
  end

  def test_multiple_messages
    output = generate("message User { string name; }\nmessage Post { string title; }")
    assert_includes output, "pub struct User {"
    assert_includes output, "pub struct Post {"
  end

  def test_message_typed_field
    output = generate(<<~FORGE)
      message User {
        string name;
      }
      message Post {
        User author;
      }
    FORGE
    assert_includes output, "pub author: User,"
  end

  def test_enum_output
    output = generate(<<~FORGE)
      enum Status {
        ACTIVE;
        INACTIVE;
      }
    FORGE
    assert_includes output, "#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]"
    assert_includes output, "pub enum Status {"
    assert_includes output, "Active,"
    assert_includes output, "Inactive,"
  end

  def test_enum_field
    output = generate(<<~FORGE)
      enum Status {
        ACTIVE;
      }
      message User {
        Status status;
      }
    FORGE
    assert_includes output, "pub status: Status,"
  end

  def test_optional_field
    output = generate("message User { int age?; }")
    assert_includes output, "pub age: Option<i32>,"
  end

  def test_array_field
    output = generate("message User { string[] tags; }")
    assert_includes output, "pub tags: Vec<String>,"
  end

  def test_map_field
    output = generate("message User { map<string, int> scores; }")
    assert_includes output, "pub scores: std::collections::HashMap<String, i32>,"
  end

  def test_optional_array_field
    output = generate("message User { string[] tags?; }")
    assert_includes output, "pub tags: Option<Vec<String>>,"
  end

  def test_deterministic_output
    source = "message User { string name; int age; }"
    assert_equal generate(source), generate(source)
  end

  def test_output_ends_with_newline
    assert generate("message A { string x; }").end_with?("\n")
  end

  def test_generator_subclassable
    assert Forge::RustGenerator.ancestors.include?(Forge::Generator)
  end

  def test_no_haxe_syntax
    output = generate("message User { string name; }")
    refute_includes output, "public function"
    refute_includes output, "import forge.Runtime"
  end

  def test_no_typescript_syntax
    output = generate("message User { string name; }")
    refute_includes output, "export interface"
  end

  def test_no_go_syntax
    output = generate("message User { string name; }")
    refute_includes output, "package schema"
  end
end
