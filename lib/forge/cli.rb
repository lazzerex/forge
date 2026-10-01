require "fileutils"

module Forge
  class CLI
    TARGETS = {
      "haxe" => { generator: HaxeGenerator, ext: "hx" },
      "typescript" => { generator: TypeScriptGenerator, ext: "ts" },
      "go" => { generator: GoGenerator, ext: "go" },
      "rust" => { generator: RustGenerator, ext: "rs" }
    }.freeze

    def initialize(argv, stdout: $stdout, stderr: $stderr)
      @argv = argv.dup
      @stdout = stdout
      @stderr = stderr
    end

    def run
      command = @argv.shift
      case command
      when "check" then run_check
      when "generate" then run_generate
      when "version" then run_version
      when "help", "--help", "-h", nil then run_help
      else
        @stderr.puts "Unknown command: #{command}"
        @stderr.puts
        run_help
        1
      end
    end

    private

    def run_check
      file = @argv.first
      return usage_error("check requires a schema file") unless file
      doc, errors = compile(file)
      return 1 unless doc
      return print_errors(errors) unless errors.empty?
      0
    end

    def run_generate
      file = nil
      target = nil
      out = nil
      until @argv.empty?
        arg = @argv.shift
        case arg
        when "--target" then target = @argv.shift
        when "--out" then out = @argv.shift
        else file ||= arg
        end
      end
      return usage_error("generate requires a schema file") unless file
      return usage_error("generate requires --target") unless target
      entry = TARGETS[target]
      return usage_error("unknown target `#{target}` (targets: #{TARGETS.keys.join(", ")})") unless entry

      doc, errors = compile(file)
      return 1 unless doc
      return print_errors(errors) unless errors.empty?

      generator = entry[:generator].new
      if out
        FileUtils.mkdir_p(out)
        doc.messages.each do |msg|
          File.write(File.join(out, "#{msg.name}.#{entry[:ext]}"), generator.generate(Document.new([msg])))
        end
        doc.enums.each do |enum|
          File.write(File.join(out, "#{enum.name}.#{entry[:ext]}"), generator.generate(Document.new([], [enum])))
        end
      else
        @stdout.print generator.generate(doc)
      end
      0
    end

    def run_version
      @stdout.puts VERSION
      0
    end

    def run_help
      @stdout.puts <<~HELP
        Usage: forge <command> [options]

        Commands:
          check <schema.forge>
              Validate a schema file
          generate <schema.forge> --target <target> [--out <dir>]
              Generate code from a schema
          version
              Print version
          help
              Show this help

        Targets: #{TARGETS.keys.join(", ")}
      HELP
      0
    end

    def usage_error(message)
      @stderr.puts "Error: #{message}"
      1
    end

    def print_errors(errors)
      errors.each { |e| @stderr.puts e.to_s }
      1
    end

    def compile(filename)
      doc = Loader.load(filename)
      errors = SemanticAnalyzer.new(filename).analyze(doc)
      [doc, errors]
    rescue LoaderError, LexerError, ParserError => e
      @stderr.puts e.message
      [nil, []]
    end
  end
end