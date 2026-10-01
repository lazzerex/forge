require_relative "errors"
require_relative "lexer"
require_relative "parser"
require_relative "ast"

module Forge
  class Loader
    def self.load(filename)
      new.load(filename)
    end

    def initialize
      @visited = {}
    end

    def load(filename)
      path = File.expand_path(filename)
      return @visited[path] if @visited.key?(path)
      @visited[path] = Document.new([], [], [])

      source = File.read(path)
      begin
        tokens = Lexer.new(source).tokenize
        doc = Parser.new(tokens).parse
      rescue LexerError, ParserError => e
        raise e.class, "#{path}: #{e.message}"
      end

      messages = doc.messages.dup
      enums = doc.enums.dup
      doc.imports.each do |imp|
        imported_path = File.expand_path(imp.path, File.dirname(path))
        imported = load(imported_path)
        messages.concat(imported.messages)
        enums.concat(imported.enums)
      end

      merged = Document.new(messages, enums, [])
      @visited[path] = merged
      merged
    rescue Errno::ENOENT
      raise LoaderError, "File not found: #{filename}"
    end
  end
end