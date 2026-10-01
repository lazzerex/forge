require_relative "test_helper"
require "stringio"
require "tmpdir"
require "fileutils"

class ImportTest < Minitest::Test
  def run_cli(argv)
    stdout = StringIO.new
    stderr = StringIO.new
    code = Forge::CLI.new(argv, stdout: stdout, stderr: stderr).run
    [code, stdout.string, stderr.string]
  end

  def test_check_with_import
    Dir.mktmpdir do |dir|
      File.write("#{dir}/user.forge", "message User { string name; }\n")
      schema = "import \"user.forge\";\nmessage Post { User author; }\n"
      File.write("#{dir}/schema.forge", schema)
      code, _out, err = run_cli(["check", "#{dir}/schema.forge"])
      assert_equal 0, code
      assert_equal "", err
    end
  end

  def test_import_in_subdirectory
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/types")
      File.write("#{dir}/types/user.forge", "message User { string name; }\n")
      schema = "import \"types/user.forge\";\nmessage Post { User author; }\n"
      File.write("#{dir}/schema.forge", schema)
      code, _out, err = run_cli(["check", "#{dir}/schema.forge"])
      assert_equal 0, code
      assert_equal "", err
    end
  end

  def test_nested_imports
    Dir.mktmpdir do |dir|
      File.write("#{dir}/base.forge", "enum Status { ACTIVE; }\n")
      File.write("#{dir}/user.forge", "import \"base.forge\";\nmessage User { Status status; }\n")
      File.write("#{dir}/schema.forge", "import \"user.forge\";\nmessage Post { User author; }\n")
      code, _out, err = run_cli(["check", "#{dir}/schema.forge"])
      assert_equal 0, code
      assert_equal "", err
    end
  end

  def test_missing_import_reported
    Dir.mktmpdir do |dir|
      schema = "import \"nope.forge\";\nmessage User { string name; }\n"
      File.write("#{dir}/schema.forge", schema)
      code, _out, err = run_cli(["check", "#{dir}/schema.forge"])
      assert_equal 1, code
      assert_includes err, "File not found"
      assert_includes err, "nope.forge"
    end
  end

  def test_import_semantic_errors_reported
    Dir.mktmpdir do |dir|
      File.write("#{dir}/bad.forge", "message User { Unknown x; }\n")
      File.write("#{dir}/schema.forge", "import \"bad.forge\";\n")
      code, _out, err = run_cli(["check", "#{dir}/schema.forge"])
      assert_equal 1, code
      assert_includes err, "unknown type `Unknown`"
    end
  end

  def test_generate_writes_imported_messages
    Dir.mktmpdir do |dir|
      File.write("#{dir}/user.forge", "message User { string name; }\n")
      File.write("#{dir}/schema.forge", "import \"user.forge\";\nmessage Post { string title; }\n")
      out_dir = File.join(dir, "generated")
      code, = run_cli(["generate", "#{dir}/schema.forge", "--target", "typescript", "--out", out_dir])
      assert_equal 0, code
      assert File.exist?(File.join(out_dir, "User.ts"))
      assert File.exist?(File.join(out_dir, "Post.ts"))
    end
  end

  def test_import_cycle_terminates
    Dir.mktmpdir do |dir|
      File.write("#{dir}/a.forge", "import \"b.forge\";\nmessage A { string x; }\n")
      File.write("#{dir}/b.forge", "import \"a.forge\";\nmessage B { A a; }\n")
      code, _out, err = run_cli(["check", "#{dir}/a.forge"])
      assert_equal 0, code
      assert_equal "", err
    end
  end

  def test_duplicate_message_across_imports_detected
    Dir.mktmpdir do |dir|
      File.write("#{dir}/a.forge", "message User { string name; }\n")
      File.write("#{dir}/b.forge", "message User { int age; }\n")
      schema = "import \"a.forge\";\nimport \"b.forge\";\n"
      File.write("#{dir}/schema.forge", schema)
      code, _out, err = run_cli(["check", "#{dir}/schema.forge"])
      assert_equal 1, code
      assert_includes err, "duplicate message `User`"
    end
  end
end
