require_relative "test_helper"
require "stringio"
require "tmpdir"

class CLITest < Minitest::Test
  VALID = "message User {\n  string name;\n  int age;\n}\n"

  def run_cli(argv)
    stdout = StringIO.new
    stderr = StringIO.new
    code = Forge::CLI.new(argv, stdout: stdout, stderr: stderr).run
    [code, stdout.string, stderr.string]
  end

  def with_schema(content)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "schema.forge")
      File.write(path, content)
      yield path, dir
    end
  end

  def test_check_valid_schema
    with_schema(VALID) do |path, _dir|
      code, _out, err = run_cli(["check", path])
      assert_equal 0, code
      assert_equal "", err
    end
  end

  def test_check_reports_semantic_errors
    with_schema("message A { string name; }\nmessage A { int x; }\n") do |path, _dir|
      code, _out, err = run_cli(["check", path])
      assert_equal 1, code
      assert_includes err, "duplicate message `A`"
    end
  end

  def test_check_reports_unknown_type
    with_schema("message A { Unknown x; }\n") do |path, _dir|
      code, _out, err = run_cli(["check", path])
      assert_equal 1, code
      assert_includes err, "unknown type `Unknown`"
    end
  end

  def test_check_reports_lexer_error
    with_schema("message A { @ }") do |path, _dir|
      code, _out, err = run_cli(["check", path])
      assert_equal 1, code
      assert_includes err, "Unexpected character"
    end
  end

  def test_check_reports_parser_error
    with_schema("message A { string name }") do |path, _dir|
      code, _out, err = run_cli(["check", path])
      assert_equal 1, code
      assert_includes err, "Expected SEMICOLON"
    end
  end

  def test_check_missing_file
    code, _out, err = run_cli(["check", "nope.forge"])
    assert_equal 1, code
    assert_includes err, "File not found"
  end

  def test_check_requires_file
    code, _out, err = run_cli(["check"])
    assert_equal 1, code
    assert_includes err, "requires a schema file"
  end

  def test_generate_stdout_haxe
    with_schema(VALID) do |path, _dir|
      code, out, = run_cli(["generate", path, "--target", "haxe"])
      assert_equal 0, code
      assert_includes out, "class User {"
      assert_includes out, "public var name:String;"
    end
  end

  def test_generate_stdout_typescript
    with_schema(VALID) do |path, _dir|
      code, out, = run_cli(["generate", path, "--target", "typescript"])
      assert_equal 0, code
      assert_includes out, "export interface User {"
      assert_includes out, "name: string;"
    end
  end

  def test_generate_writes_haxe_files
    with_schema(VALID) do |path, dir|
      out_dir = File.join(dir, "generated")
      code, = run_cli(["generate", path, "--target", "haxe", "--out", out_dir])
      assert_equal 0, code
      file = File.join(out_dir, "User.hx")
      assert File.exist?(file)
      assert_includes File.read(file), "class User {"
    end
  end

  def test_generate_writes_typescript_files
    with_schema(VALID) do |path, dir|
      out_dir = File.join(dir, "generated")
      code, = run_cli(["generate", path, "--target", "typescript", "--out", out_dir])
      assert_equal 0, code
      file = File.join(out_dir, "User.ts")
      assert File.exist?(file)
      assert_includes File.read(file), "export interface User {"
    end
  end

  def test_generate_writes_one_file_per_message
    with_schema("message A { string x; }\nmessage B { int y; }\n") do |path, dir|
      out_dir = File.join(dir, "generated")
      code, = run_cli(["generate", path, "--target", "haxe", "--out", out_dir])
      assert_equal 0, code
      assert File.exist?(File.join(out_dir, "A.hx"))
      assert File.exist?(File.join(out_dir, "B.hx"))
    end
  end

  def test_generate_no_writes_on_validation_failure
    with_schema("message A { Unknown x; }\n") do |path, dir|
      out_dir = File.join(dir, "generated")
      code, _out, err = run_cli(["generate", path, "--target", "haxe", "--out", out_dir])
      assert_equal 1, code
      assert_includes err, "unknown type"
      refute Dir.exist?(out_dir)
    end
  end

  def test_generate_no_writes_on_parse_failure
    with_schema("message A { string name }") do |path, dir|
      out_dir = File.join(dir, "generated")
      code, _out, err = run_cli(["generate", path, "--target", "haxe", "--out", out_dir])
      assert_equal 1, code
      assert_includes err, "Expected SEMICOLON"
      refute Dir.exist?(out_dir)
    end
  end

  def test_generate_unknown_target
    with_schema(VALID) do |path, _dir|
      code, _out, err = run_cli(["generate", path, "--target", "rust"])
      assert_equal 1, code
      assert_includes err, "unknown target"
    end
  end

  def test_generate_requires_target
    with_schema(VALID) do |path, _dir|
      code, _out, err = run_cli(["generate", path])
      assert_equal 1, code
      assert_includes err, "--target"
    end
  end

  def test_generate_requires_file
    code, _out, err = run_cli(["generate", "--target", "haxe"])
    assert_equal 1, code
    assert_includes err, "requires a schema file"
  end

  def test_version
    code, out, = run_cli(["version"])
    assert_equal 0, code
    assert_equal Forge::VERSION, out.strip
  end

  def test_help
    code, out, = run_cli(["help"])
    assert_equal 0, code
    assert_includes out, "Usage: forge"
    assert_includes out, "haxe"
    assert_includes out, "typescript"
    assert_includes out, "go"
  end

  def test_no_args_shows_help
    code, out, = run_cli([])
    assert_equal 0, code
    assert_includes out, "Usage: forge"
  end

  def test_unknown_command
    code, _out, err = run_cli(["frobnicate"])
    assert_equal 1, code
    assert_includes err, "Unknown command"
  end

  def test_generate_stdout_go
    with_schema(VALID) do |path, _dir|
      code, out, = run_cli(["generate", path, "--target", "go"])
      assert_equal 0, code
      assert_includes out, "package schema"
      assert_includes out, "type User struct {"
      assert_includes out, "Name string `json:\"name\"`"
    end
  end

  def test_generate_writes_go_files
    with_schema(VALID) do |path, dir|
      out_dir = File.join(dir, "generated")
      code, = run_cli(["generate", path, "--target", "go", "--out", out_dir])
      assert_equal 0, code
      file = File.join(out_dir, "User.go")
      assert File.exist?(file)
      assert_includes File.read(file), "type User struct {"
    end
  end

  def test_check_message_typed_field
    with_schema("message Post { User author; }\nmessage User { string name; }\n") do |path, _dir|
      code, _out, err = run_cli(["check", path])
      assert_equal 0, code
      assert_equal "", err
    end
  end

  def test_check_enum_schema
    with_schema("enum Status { ACTIVE; }\nmessage User { Status status; }\n") do |path, _dir|
      code, _out, err = run_cli(["check", path])
      assert_equal 0, code
      assert_equal "", err
    end
  end

  def test_check_reports_enum_errors
    with_schema("enum Status { }\n") do |path, _dir|
      code, _out, err = run_cli(["check", path])
      assert_equal 1, code
      assert_includes err, "has no values"
    end
  end

  def test_generate_writes_enum_files
    with_schema("enum Status { ACTIVE; }\nmessage User { Status status; }\n") do |path, dir|
      out_dir = File.join(dir, "generated")
      code, = run_cli(["generate", path, "--target", "typescript", "--out", out_dir])
      assert_equal 0, code
      assert File.exist?(File.join(out_dir, "Status.ts"))
      assert File.exist?(File.join(out_dir, "User.ts"))
      assert_includes File.read(File.join(out_dir, "Status.ts")), "export type Status = \"ACTIVE\";"
    end
  end

  def test_generate_stdout_go_with_enum
    with_schema("enum Status { ACTIVE; }\nmessage User { Status status; }\n") do |path, _dir|
      code, out, = run_cli(["generate", path, "--target", "go"])
      assert_equal 0, code
      assert_includes out, "type Status string"
      assert_includes out, "StatusACTIVE Status = \"ACTIVE\""
      assert_includes out, "Status Status `json:\"status\"`"
    end
  end
end