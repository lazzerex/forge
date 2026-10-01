require_relative "token"

module Forge
  class Lexer
    KEYWORDS = { "message" => :KEYWORD, "enum" => :KEYWORD, "import" => :KEYWORD, "map" => :KEYWORD }.freeze
    TYPES = %w[string int float bool].freeze

    def initialize(source)
      @source = source
      @pos = 0
      @line = 1
      @column = 1
    end

    def tokenize
      tokens = []
      until at_end?
        skip_whitespace_and_comments
        break if at_end?
        tokens << scan_token
      end
      tokens << Token.new(type: :EOF, value: "", line: @line, column: @column)
      tokens
    end

    private

    def at_end?
      @pos >= @source.length
    end

    def peek
      @source[@pos]
    end

    def peek_next
      @source[@pos + 1]
    end

    def advance
      ch = @source[@pos]
      @pos += 1
      if ch == "\n"
        @line += 1
        @column = 1
      else
        @column += 1
      end
      ch
    end

    def skip_whitespace_and_comments
      while !at_end?
        ch = peek
        if ch =~ /\s/
          advance
        elsif ch == "/" && peek_next == "/"
          advance while !at_end? && peek != "\n"
        else
          break
        end
      end
    end

    def scan_token
      start_line = @line
      start_col = @column
      ch = advance

      case ch
      when "{"
        Token.new(type: :LBRACE, value: "{", line: start_line, column: start_col)
      when "}"
        Token.new(type: :RBRACE, value: "}", line: start_line, column: start_col)
      when ";"
        Token.new(type: :SEMICOLON, value: ";", line: start_line, column: start_col)
      when "?"
        Token.new(type: :QUESTION, value: "?", line: start_line, column: start_col)
      when "["
        Token.new(type: :LBRACKET, value: "[", line: start_line, column: start_col)
      when "]"
        Token.new(type: :RBRACKET, value: "]", line: start_line, column: start_col)
      when "<"
        Token.new(type: :LT, value: "<", line: start_line, column: start_col)
      when ">"
        Token.new(type: :GT, value: ">", line: start_line, column: start_col)
      when ","
        Token.new(type: :COMMA, value: ",", line: start_line, column: start_col)
      when "\""
        scan_string(start_line, start_col)
      when /[a-zA-Z_]/
        scan_word(ch, start_line, start_col)
      else
        raise Forge::LexerError, "Unexpected character '#{ch}' at #{start_line}:#{start_col}"
      end
    end

    def scan_string(start_line, start_col)
      buf = +""
      while !at_end? && peek != "\""
        raise Forge::LexerError, "Unterminated string at #{start_line}:#{start_col}" if peek == "\n"
        buf << advance
      end
      raise Forge::LexerError, "Unterminated string at #{start_line}:#{start_col}" if at_end?
      advance
      Token.new(type: :STRING, value: buf, line: start_line, column: start_col)
    end

    def scan_word(first_char, start_line, start_col)
      buf = first_char.dup
      buf << advance while !at_end? && peek =~ /[a-zA-Z0-9_]/

      type = if TYPES.include?(buf)
        :TYPE
      elsif KEYWORDS.key?(buf)
        KEYWORDS[buf]
      else
        :IDENTIFIER
      end

      Token.new(type: type, value: buf, line: start_line, column: start_col)
    end
  end
end
