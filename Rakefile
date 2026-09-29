require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

desc "Verify generated Haxe compiles and runs"
task :verify, [:file] do |t, args|
  require_relative "lib/forge"
  file = args[:file] || "schema.forge"
  result = Forge::Verify.new(file).run
  exit(result ? 0 : 1)
end

task default: :test
