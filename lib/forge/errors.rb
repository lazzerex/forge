module Forge
  class LexerError < StandardError; end
  class ParserError < StandardError; end
  class SemanticError < StandardError
    attr_reader :line, :column, :filename

    def initialize(message, filename:, line:, column:)
      super(message)
      @filename = filename
      @line = line
      @column = column
    end

    def to_s
      "#{@filename}:#{@line}:#{@column}: #{super}"
    end
  end
end
