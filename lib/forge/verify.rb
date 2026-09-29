require "tmpdir"
require "fileutils"

module Forge
  class Verify
    RUNTIME_PATH = File.expand_path("../../runtime", __dir__)

    def initialize(filename)
      @filename = filename
    end

    def run
      source = File.read(@filename)
      tokens = Lexer.new(source).tokenize
      doc = Parser.new(tokens).parse
      errors = SemanticAnalyzer.new(@filename).analyze(doc)

      unless errors.empty?
        errors.each { |e| $stderr.puts e.to_s }
        return false
      end

      Dir.mktmpdir do |dir|
        FileUtils.cp_r(RUNTIME_PATH, "#{dir}/runtime")
        doc.messages.each do |msg|
          File.write("#{dir}/#{msg.name}.hx", haxe_output_for(msg))
        end
        File.write("#{dir}/Main.hx", main_haxe(doc))

        runtime_path = "#{dir}/runtime"
        result = system("haxe --interp -p #{runtime_path} -p #{dir} -m Main 2>&1")
        result
      end
    end

    private

    def haxe_output_for(message)
      if message.fields.empty?
        <<~HAXE.strip
          import forge.Runtime;

          class #{message.name} {
              public function new() {
              }

              public function toString():String {
                  return Runtime.toString(this, "#{message.name}");
              }

              public function toJson():Dynamic {
                  return Runtime.toJson(this);
              }

              public static function fromJson(json:Dynamic):#{message.name} {
                  var obj = new #{message.name}();
                  Runtime.fromJson(obj, json);
                  return obj;
              }

              public function serialize():String {
                  return Runtime.serialize(this);
              }
          }
        HAXE
      else
        fields = message.fields.map { |f| "        public var #{f.name}:#{Forge::HaxeGenerator::TYPE_MAP[f.type_name] || f.type_name};" }.join("\n")
        <<~HAXE.strip
          import forge.Runtime;

          class #{message.name} {
          #{fields}

              public function new() {
              }

              public function toString():String {
                  return Runtime.toString(this, "#{message.name}");
              }

              public function toJson():Dynamic {
                  return Runtime.toJson(this);
              }

              public static function fromJson(json:Dynamic):#{message.name} {
                  var obj = new #{message.name}();
                  Runtime.fromJson(obj, json);
                  return obj;
              }

              public function serialize():String {
                  return Runtime.serialize(this);
              }
          }
        HAXE
      end
    end

    def main_haxe(doc)
      msg = doc.messages.first
      return simple_main if msg.nil? || msg.fields.empty?

      varname = msg.name.downcase
      assignments = msg.fields.map { |f| "#{varname}.#{f.name} = #{default_value(f)};" }.join("\n")
      traces = msg.fields.map { |f| "trace(Std.string(#{varname}.#{f.name}));" }.join("\n")

      <<~HAXE
        class Main {
            static function main() {
                var #{varname} = new #{msg.name}();
                #{assignments.split("\n").join("\n                ")}
                #{traces.split("\n").join("\n                ")}
                trace(#{varname}.toString());
                trace(#{varname}.serialize());
            }
        }
      HAXE
    end

    def default_value(field)
      case field.type_name
      when "string" then "\"test\""
      when "int" then "42"
      when "float" then "3.14"
      when "bool" then "true"
      else "null"
      end
    end

    def simple_main
      <<~HAXE
        class Main {
            static function main() {
                trace("ok");
            }
        }
      HAXE
    end
  end
end
