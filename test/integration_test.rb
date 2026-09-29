require_relative "test_helper"
require_relative "../lib/forge/lexer"
require_relative "../lib/forge/parser"
require_relative "../lib/forge/semantic_analyzer"
require_relative "../lib/forge/generators/haxe"
require "tmpdir"
require "fileutils"

class HaxeIntegrationTest < Minitest::Test
  HAXE_AVAILABLE = system("haxe --version > /dev/null 2>&1")
  RUNTIME_PATH = File.expand_path("../runtime", __dir__)

  def setup
    skip "haxe not installed" unless HAXE_AVAILABLE
  end

  def compile_and_run(dir)
    FileUtils.cp_r(RUNTIME_PATH, "#{dir}/runtime")
    system("haxe --interp -p #{dir}/runtime -p #{dir} -m Main 2>&1")
  end

  def test_single_message_compiles
    Dir.mktmpdir do |dir|
      haxe = generate_haxe(<<~FORGE)
        message User {
          string name;
          int age;
        }
      FORGE
      File.write("#{dir}/User.hx", haxe)
      File.write("#{dir}/Main.hx", <<~HAXE)
        class Main {
            static function main() {
                var user = new User();
                user.name = "alice";
                user.age = 30;
                trace(user.name);
            }
        }
      HAXE
      assert compile_and_run(dir), "Haxe compilation failed"
    end
  end

  def test_all_types_compile
    Dir.mktmpdir do |dir|
      haxe = generate_haxe(<<~FORGE)
        message All {
          string a;
          int b;
          float c;
          bool d;
        }
      FORGE
      File.write("#{dir}/All.hx", haxe)
      File.write("#{dir}/Main.hx", <<~HAXE)
        class Main {
            static function main() {
                var all = new All();
                all.a = "hello";
                all.b = 42;
                all.c = 3.14;
                all.d = true;
                trace(all.a);
                trace(all.b);
                trace(all.c);
                trace(all.d);
            }
        }
      HAXE
      assert compile_and_run(dir), "Haxe compilation failed"
    end
  end

  def test_multiple_messages_compile
    Dir.mktmpdir do |dir|
      tokens = Forge::Lexer.new(<<~FORGE).tokenize
        message User {
          string name;
        }
        message Post {
          string title;
          int likes;
        }
      FORGE
      doc = Forge::Parser.new(tokens).parse
      Forge::SemanticAnalyzer.new("test.forge").analyze(doc)

      gen = Forge::HaxeGenerator.new
      doc.messages.each do |msg|
        single_doc = Forge::Document.new([msg])
        File.write("#{dir}/#{msg.name}.hx", gen.generate(single_doc))
      end

      File.write("#{dir}/Main.hx", <<~HAXE)
        class Main {
            static function main() {
                var user = new User();
                user.name = "bob";
                var post = new Post();
                post.title = "hello";
                post.likes = 5;
                trace(user.name);
                trace(post.title);
            }
        }
      HAXE
      assert compile_and_run(dir), "Haxe compilation failed"
    end
  end

  def test_end_to_end_generates_valid_haxe
    source = <<~FORGE
      message User {
        string id;
        string name;
        int age;
        bool active;
      }
    FORGE
    tokens = Forge::Lexer.new(source).tokenize
    doc = Forge::Parser.new(tokens).parse
    errors = Forge::SemanticAnalyzer.new("test.forge").analyze(doc)
    assert_equal 0, errors.length
    haxe = Forge::HaxeGenerator.new.generate(doc)

    Dir.mktmpdir do |dir|
      File.write("#{dir}/User.hx", haxe)
      File.write("#{dir}/Main.hx", <<~HAXE)
        class Main {
            static function main() {
                var user = new User();
                user.id = "1";
                user.name = "alice";
                user.age = 30;
                user.active = true;
                trace(user.id);
                trace(user.name);
                trace(user.age);
                trace(user.active);
            }
        }
      HAXE
      assert compile_and_run(dir), "Full pipeline produced invalid Haxe"
    end
  end

  def test_verify_class_works
    Dir.mktmpdir do |dir|
      schema = "#{dir}/test.forge"
      File.write(schema, <<~FORGE)
        message User {
          string name;
          int age;
        }
      FORGE
      result = Forge::Verify.new(schema).run
      assert result, "Verify failed for valid schema"
    end
  end

  def test_verify_reports_semantic_errors
    Dir.mktmpdir do |dir|
      schema = "#{dir}/test.forge"
      File.write(schema, <<~FORGE)
        message User {
          Usr ref;
        }
      FORGE
      output = capture_stderr { Forge::Verify.new(schema).run }
      assert_match(/unknown type/, output)
    end
  end

  def test_toString_via_runtime
    Dir.mktmpdir do |dir|
      haxe = generate_haxe("message User { string name; int age; }")
      File.write("#{dir}/User.hx", haxe)
      File.write("#{dir}/Main.hx", <<~HAXE)
        class Main {
            static function main() {
                var user = new User();
                user.name = "alice";
                user.age = 30;
                trace(user.toString());
            }
        }
      HAXE
      assert compile_and_run(dir), "Runtime toString failed"
    end
  end

  def test_serialize_via_runtime
    Dir.mktmpdir do |dir|
      haxe = generate_haxe("message User { string name; int age; }")
      File.write("#{dir}/User.hx", haxe)
      File.write("#{dir}/Main.hx", <<~HAXE)
        class Main {
            static function main() {
                var user = new User();
                user.name = "bob";
                user.age = 25;
                trace(user.serialize());
            }
        }
      HAXE
      assert compile_and_run(dir), "Runtime serialize failed"
    end
  end

  def test_from_json_roundtrip
    Dir.mktmpdir do |dir|
      haxe = generate_haxe("message User { string name; int age; }")
      File.write("#{dir}/User.hx", haxe)
      File.write("#{dir}/Main.hx", <<~HAXE)
        class Main {
            static function main() {
                var user = new User();
                user.name = "alice";
                user.age = 30;
                var json = user.toJson();
                var user2 = User.fromJson(json);
                trace(user2.name);
                trace(user2.age);
            }
        }
      HAXE
      assert compile_and_run(dir), "Runtime fromJson roundtrip failed"
    end
  end

  private

  def generate_haxe(source)
    tokens = Forge::Lexer.new(source).tokenize
    doc = Forge::Parser.new(tokens).parse
    Forge::SemanticAnalyzer.new("test.forge").analyze(doc)
    Forge::HaxeGenerator.new.generate(doc)
  end

  def capture_stderr
    old = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old
  end
end
