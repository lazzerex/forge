require_relative "test_helper"
require_relative "../lib/forge/lexer"
require_relative "../lib/forge/parser"
require_relative "../lib/forge/semantic_analyzer"
require_relative "../lib/forge/generators/typescript"

class TypeScriptGeneratorTest < Minitest::Test
  def generate(source)
    tokens = Forge::Lexer.new(source).tokenize
    doc = Forge::Parser.new(tokens).parse
    Forge::SemanticAnalyzer.new("input.forge").analyze(doc)
    Forge::TypeScriptGenerator.new.generate(doc)
  end

  def test_single_message_one_field
    output = generate("message User { string name; }")
    assert_includes output, "export interface User {"
    assert_includes output, "name: string;"
    assert_includes output, "}"
  end

  def test_multiple_fields
    output = generate(<<~FORGE)
      message User {
        string id;
        string name;
        int age;
        bool active;
      }
    FORGE
    assert_includes output, "id: string;"
    assert_includes output, "name: string;"
    assert_includes output, "age: number;"
    assert_includes output, "active: boolean;"
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
    assert_includes output, "a: string;"
    assert_includes output, "b: number;"
    assert_includes output, "c: number;"
    assert_includes output, "d: boolean;"
  end

  def test_multiple_messages
    output = generate("message User { string name; }\nmessage Post { string title; }")
    assert_includes output, "export interface User {"
    assert_includes output, "export interface Post {"
  end

  def test_messages_separated_by_blank_line
    output = generate("message A { string x; }\nmessage B { string y; }")
    assert_includes output, "}\n\nexport interface B"
  end

  def test_empty_message
    output = generate("message Empty { }")
    assert_includes output, "export interface Empty {"
  end

  def test_deterministic_output
    source = "message User { string name; int age; }"
    assert_equal generate(source), generate(source)
  end

  def test_output_ends_with_newline
    assert generate("message A { string x; }").end_with?("\n")
  end

  def test_end_to_end_full_pipeline
    source = <<~FORGE
      message User {
        string id;
        string name;
        int age;
        bool active;
      }
    FORGE
    output = generate(source)
    assert_includes output, "export interface User {"
    assert_includes output, "id: string;"
    assert_includes output, "name: string;"
    assert_includes output, "age: number;"
    assert_includes output, "active: boolean;"
  end

  def test_end_to_end_multiple_messages
    source = <<~FORGE
      message User {
        string name;
      }
      message Comment {
        string body;
        int likes;
      }
    FORGE
    output = generate(source)
    assert_includes output, "export interface User {"
    assert_includes output, "export interface Comment {"
    assert_includes output, "body: string;"
    assert_includes output, "likes: number;"
  end

  def test_generator_subclassable
    assert Forge::TypeScriptGenerator.ancestors.include?(Forge::Generator)
  end

  def test_no_haxe_syntax
    output = generate("message User { string name; }")
    refute_includes output, "public var"
    refute_includes output, "class User"
    refute_includes output, "Runtime"
  end

  def test_same_ast_both_generators
    source = "message User { string name; int age; }"
    tokens = Forge::Lexer.new(source).tokenize
    doc = Forge::Parser.new(tokens).parse
    haxe = Forge::HaxeGenerator.new.generate(doc)
    ts = Forge::TypeScriptGenerator.new.generate(doc)
    assert_includes haxe, "public var name:String;"
    assert_includes ts, "name: string;"
  end

  def test_enum_output
    output = generate(<<~FORGE)
      enum Status {
        ACTIVE;
        INACTIVE;
      }
    FORGE
    assert_includes output, "export type Status = \"ACTIVE\" | \"INACTIVE\";"
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
    assert_includes output, "author: User;"
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
    assert_includes output, "export type Status = \"ACTIVE\";"
    assert_includes output, "status: Status;"
  end
end