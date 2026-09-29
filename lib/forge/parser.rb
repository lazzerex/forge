require_relative "ast"

module Forge
  class Parser
    def initialize(tokens)
      @tokens = tokens
      @pos = 0
    end

    def parse
      messages = []
      messages << parse_message until at_end?
      Document.new(messages)
    end

    private

    def at_end?
      peek.type == :EOF
    end

    def peek
      @tokens[@pos]
    end

    def advance
      tok = @tokens[@pos]
      @pos += 1
      tok
    end

    def expect(type)
      tok = peek
      raise parse_error("Expected #{type}, got #{tok.type}", tok) unless tok.type == type
      advance
    end

    def parse_error(message, token)
      ParserError.new("#{message} at #{token.line}:#{token.column}")
    end

    def parse_message
      kw = expect(:KEYWORD)
      name = expect(:IDENTIFIER)
      expect(:LBRACE)
      fields = []
      fields << parse_field while peek.type == :TYPE
      expect(:RBRACE)
      Message.new(name: name.value, fields: fields, line: kw.line, column: kw.column)
    end

    def parse_field
      type_tok = expect(:TYPE)
      name_tok = expect(:IDENTIFIER)
      expect(:SEMICOLON)
      Field.new(name: name_tok.value, type_name: type_tok.value, line: type_tok.line, column: type_tok.column)
    end
  end
end
