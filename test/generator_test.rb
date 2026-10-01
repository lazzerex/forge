require_relative "test_helper"
require_relative "../lib/forge/lexer"
require_relative "../lib/forge/parser"
require_relative "../lib/forge/semantic_analyzer"
require_relative "../lib/forge/generators/haxe"

class HaxeGeneratorTest < Minitest::Test
  def generate(source)
    tokens = Forge::Lexer.new(source).tokenize
    doc = Forge::Parser.new(tokens).parse
    Forge::SemanticAnalyzer.new("input.forge").analyze(doc)
    Forge::HaxeGenerator.new.generate(doc)
  end

  def test_single_message_one_field
    output = generate("message User { string name; }")
    assert_includes output, "import forge.Runtime;"
    assert_includes output, "public var name:String;"
    assert_includes output, "public function new()"
    assert_includes output, "Runtime.toString(this, \"User\")"
    assert_includes output, "Runtime.toJson(this)"
    assert_includes output, "public static function fromJson"
    assert_includes output, "Runtime.serialize(this)"
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
    assert_includes output, "public var id:String;"
    assert_includes output, "public var name:String;"
    assert_includes output, "public var age:Int;"
    assert_includes output, "public var active:Bool;"
    assert_includes output, "Runtime.toString(this, \"User\")"
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
    assert_includes output, "public var a:String;"
    assert_includes output, "public var b:Int;"
    assert_includes output, "public var c:Float;"
    assert_includes output, "public var d:Bool;"
  end

  def test_multiple_messages
    output = generate(<<~FORGE)
      message User {
        string name;
      }
      message Post {
        string title;
      }
    FORGE
    assert_includes output, "class User {"
    assert_includes output, "class Post {"
    assert_includes output, "Runtime.toString(this, \"User\")"
    assert_includes output, "Runtime.toString(this, \"Post\")"
  end

  def test_messages_separated_by_blank_line
    output = generate(<<~FORGE)
      message A { string x; }
      message B { string y; }
    FORGE
    assert_includes output, "}\n\nclass B"
  end

  def test_empty_message
    output = generate("message Empty { }")
    assert_includes output, "class Empty {"
    assert_includes output, "Runtime.toString(this, \"Empty\")"
    assert_includes output, "public static function fromJson"
  end

  def test_deterministic_output
    source = "message User { string name; int age; }"
    a = generate(source)
    b = generate(source)
    assert_equal a, b
  end

  def test_all_field_types_present
    output = generate(<<~FORGE)
      message Mixed {
        string a;
        int b;
        float c;
        bool d;
        string e;
      }
    FORGE
    assert_includes output, "public var a:String;"
    assert_includes output, "public var b:Int;"
    assert_includes output, "public var c:Float;"
    assert_includes output, "public var d:Bool;"
    assert_includes output, "public var e:String;"
  end

  def test_output_ends_with_newline
    output = generate("message A { string x; }")
    assert output.end_with?("\n")
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
    assert_includes output, "import forge.Runtime;"
    assert_includes output, "public var id:String;"
    assert_includes output, "public var name:String;"
    assert_includes output, "public var age:Int;"
    assert_includes output, "public var active:Bool;"
    assert_includes output, "Runtime.toString(this, \"User\")"
    assert_includes output, "Runtime.serialize(this)"
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
    assert_includes output, "class User {"
    assert_includes output, "class Comment {"
    assert_includes output, "public var body:String;"
    assert_includes output, "public var likes:Int;"
  end

  def test_generator_subclassable
    assert Forge::HaxeGenerator.ancestors.include?(Forge::Generator)
  end

  def test_empty_document_no_import
    tokens = Forge::Lexer.new("").tokenize
    doc = Forge::Parser.new(tokens).parse
    output = Forge::HaxeGenerator.new.generate(doc)
    refute_includes output, "import forge.Runtime;"
  end

  def test_enum_output
    output = generate(<<~FORGE)
      enum Status {
        ACTIVE;
        INACTIVE;
      }
    FORGE
    assert_includes output, "enum abstract Status(String) {"
    assert_includes output, "var ACTIVE = \"ACTIVE\";"
    assert_includes output, "var INACTIVE = \"INACTIVE\";"
    refute_includes output, "import forge.Runtime;"
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
    assert_includes output, "public var author:User;"
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
    assert_includes output, "enum abstract Status(String) {"
    assert_includes output, "public var status:Status;"
  end

  def test_optional_field
    output = generate("message User { int age?; }")
    assert_includes output, "public var age:Null<Int>;"
  end

  def test_array_field
    output = generate("message User { string[] tags; }")
    assert_includes output, "public var tags:Array<String>;"
  end

  def test_map_field
    output = generate("message User { map<string, int> scores; }")
    assert_includes output, "public var scores:Map<String, Int>;"
  end

  def test_optional_array_field
    output = generate("message User { string[] tags?; }")
    assert_includes output, "public var tags:Null<Array<String>>;"
  end
end
