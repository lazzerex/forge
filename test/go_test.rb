require_relative "test_helper"
require_relative "../lib/forge/lexer"
require_relative "../lib/forge/parser"
require_relative "../lib/forge/semantic_analyzer"
require_relative "../lib/forge/generators/go"

class GoGeneratorTest < Minitest::Test
  def generate(source)
    tokens = Forge::Lexer.new(source).tokenize
    doc = Forge::Parser.new(tokens).parse
    errors = Forge::SemanticAnalyzer.new("input.forge").analyze(doc)
    assert_equal 0, errors.length
    Forge::GoGenerator.new.generate(doc)
  end

  def test_package_clause
    output = generate("message User { string name; }")
    assert_includes output, "package schema"
  end

  def test_simple_struct
    output = generate("message User { string name; }")
    assert_includes output, "type User struct {"
    assert_includes output, "Name string `json:\"name\"`"
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
    assert_includes output, "A string"
    assert_includes output, "B int"
    assert_includes output, "C float64"
    assert_includes output, "D bool"
  end

  def test_empty_struct
    output = generate("message Empty { }")
    assert_includes output, "type Empty struct {"
  end

  def test_multiple_messages
    output = generate("message User { string name; }\nmessage Post { string title; }")
    assert_includes output, "type User struct {"
    assert_includes output, "type Post struct {"
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
    assert_includes output, "Author User `json:\"author\"`"
  end

  def test_enum_output
    output = generate(<<~FORGE)
      enum Status {
        ACTIVE;
        INACTIVE;
      }
    FORGE
    assert_includes output, "type Status string"
    assert_includes output, "StatusACTIVE Status = \"ACTIVE\""
    assert_includes output, "StatusINACTIVE Status = \"INACTIVE\""
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
    assert_includes output, "type Status string"
    assert_includes output, "Status Status `json:\"status\"`"
  end

  def test_output_ends_with_newline
    assert generate("message A { string x; }").end_with?("\n")
  end

  def test_generator_subclassable
    assert Forge::GoGenerator.ancestors.include?(Forge::Generator)
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

  def test_optional_field
    output = generate("message User { int age?; }")
    assert_includes output, "Age *int `json:\"age,omitempty\"`"
  end

  def test_array_field
    output = generate("message User { string[] tags; }")
    assert_includes output, "Tags []string `json:\"tags\"`"
  end

  def test_map_field
    output = generate("message User { map<string, int> scores; }")
    assert_includes output, "Scores map[string]int `json:\"scores\"`"
  end
end
