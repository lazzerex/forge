require_relative "ast"

module Forge
  class SymbolTable
    KNOWN_TYPES = %w[string int float bool].freeze

    def initialize
      @messages = {}
      @types = KNOWN_TYPES.dup
    end

    def add_message(message)
      @messages[message.name] = message
    end

    def message?(name)
      @messages.key?(name)
    end

    def known_type?(name)
      @types.include?(name)
    end

    def add_type(name)
      @types << name unless @types.include?(name)
    end

    def messages
      @messages.values
    end
  end

  class SemanticAnalyzer
    def initialize(filename = "input.forge")
      @filename = filename
      @symbol_table = SymbolTable.new
      @errors = []
    end

    def analyze(document)
      @errors = []
      @symbol_table = SymbolTable.new

      document.messages.each do |message|
        register_message(message)
        check_fields(message)
      end

      @errors
    end

    def symbol_table
      @symbol_table
    end

    private

    def register_message(message)
      if @symbol_table.message?(message.name)
        @errors << error(
          "duplicate message `#{message.name}`",
          line: message.line,
          column: message.column
        )
      end
      @symbol_table.add_message(message)
    end

    def check_fields(message)
      seen_fields = {}

      message.fields.each do |field|
        unless @symbol_table.known_type?(field.type_name)
          @errors << error(
            "unknown type `#{field.type_name}`",
            line: field.line,
            column: field.column
          )
        end

        if seen_fields.key?(field.name)
          @errors << error(
            "duplicate field `#{field.name}`",
            line: field.line,
            column: field.column
          )
        end
        seen_fields[field.name] = true
      end
    end

    def error(message, line:, column:)
      SemanticError.new(
        message,
        filename: @filename,
        line: line,
        column: column
      )
    end
  end
end
