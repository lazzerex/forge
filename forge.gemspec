require_relative "lib/forge/version"

Gem::Specification.new do |spec|
  spec.name = "forge"
  spec.version = Forge::VERSION
  spec.authors = ["Forge Contributors"]
  spec.summary = "Schema language for code generation"
  spec.description = "Define messages with typed fields in a language-agnostic schema, then generate Haxe, TypeScript, Go, and Rust from the same source."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"
  spec.files = Dir["lib/**/*.rb", "runtime/**/*", "exe/*", "README.md"]
  spec.bindir = "exe"
  spec.executables = ["forge"]
  spec.require_paths = ["lib"]
end
