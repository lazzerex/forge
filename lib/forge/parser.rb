require_relative "ast"

module Forge
  class Parser
    def initialize(tokens)
      @tokens = tokens
      @pos = 0
    end

    def parse
      messages = []
      enums = []
      imports = []
      until at_end?
        tok = peek
        if tok.type == :KEYWORD && tok.value == "enum"
          enums << parse_enum
        elsif tok.type == :KEYWORD && tok.value == "import"
          imports << parse_import
        else
          messages << parse_message
        end
      end
      Document.new(messages, enums, imports)
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
      fields << parse_field while field_start?
      expect(:RBRACE)
      Message.new(name: name.value, fields: fields, line: kw.line, column: kw.column)
    end

    def field_start?
      peek.type == :TYPE || peek.type == :IDENTIFIER || (peek.type == :KEYWORD && peek.value == "map")
    end

    def parse_field
      start_tok = peek
      type = parse_field_type
      name_tok = expect(:IDENTIFIER)
      optional = false
      if peek.type == :QUESTION
        advance
        optional = true
      end
      expect(:SEMICOLON)
      Field.new(name: name_tok.value, type: type, optional: optional, line: start_tok.line, column: start_tok.column)
    end

    def parse_field_type
      if peek.type == :KEYWORD && peek.value == "map"
        advance
        expect(:LT)
        key = parse_type_ref
        expect(:COMMA)
        value = parse_type_ref
        expect(:GT)
        type = FieldType.new(kind: :map, name: "map", key_type: key, value_type: value)
      else
        tok = advance
        unless tok.type == :TYPE || tok.type == :IDENTIFIER
          raise parse_error("Expected TYPE or IDENTIFIER, got #{tok.type}", tok)
        end
        type = FieldType.new(kind: :named, name: tok.value)
      end

      while peek.type == :LBRACKET
        expect(:LBRACKET)
        expect(:RBRACKET)
        type = FieldType.new(kind: :array, name: type.name, element: type)
      end
      type
    end

    def parse_type_ref
      tok = advance
      unless tok.type == :TYPE || tok.type == :IDENTIFIER
        raise parse_error("Expected TYPE or IDENTIFIER, got #{tok.type}", tok)
      end
      FieldType.new(kind: :named, name: tok.value)
    end

    def parse_import
      kw = expect(:KEYWORD)
      path = expect(:STRING)
      expect(:SEMICOLON)
      Import.new(path: path.value, line: kw.line, column: kw.column)
    end

    def parse_enum
      kw = expect(:KEYWORD)
      name = expect(:IDENTIFIER)
      expect(:LBRACE)
      values = []
      values << parse_enum_value while peek.type == :IDENTIFIER
      expect(:RBRACE)
      Enum.new(name: name.value, values: values, line: kw.line, column: kw.column)
    end

    def parse_enum_value
      tok = expect(:IDENTIFIER)
      expect(:SEMICOLON)
      tok.value
    end
  end
end
