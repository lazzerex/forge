require "tmpdir"
require "fileutils"

module Forge
  class Verify
    RUNTIME_PATH = File.expand_path("../../runtime", __dir__)

    def initialize(filename)
      @filename = filename
    end

    def run
      doc = Loader.load(@filename)
      errors = SemanticAnalyzer.new(@filename).analyze(doc)

      unless errors.empty?
        errors.each { |e| $stderr.puts e.to_s }
        return false
      end

      Dir.mktmpdir do |dir|
        FileUtils.cp_r(RUNTIME_PATH, "#{dir}/runtime")
        generator = HaxeGenerator.new
        doc.messages.each do |msg|
          File.write("#{dir}/#{msg.name}.hx", generator.generate(Document.new([msg])))
        end
        doc.enums.each do |enum|
          File.write("#{dir}/#{enum.name}.hx", generator.generate(Document.new([], [enum])))
        end
        File.write("#{dir}/Main.hx", main_haxe(doc))

        runtime_path = "#{dir}/runtime"
        result = system("haxe --interp -p #{runtime_path} -p #{dir} -m Main 2>&1")
        result
      end
    end

    private

    def main_haxe(doc)
      msg = doc.messages.first
      return simple_main if msg.nil? || msg.fields.empty?

      varname = msg.name.downcase
      assignable = msg.fields.reject { |f| f.type.array? || f.type.map? }
      assignments = assignable.map { |f| "#{varname}.#{f.name} = #{default_value(f)};" }.join("\n")
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
