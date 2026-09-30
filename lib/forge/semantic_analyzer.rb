require_relative "ast"

module Forge
  class SymbolTable
    KNOWN_TYPES = %w[string int float bool].freeze

    def initialize
      @messages = {}
      @enums = {}
      @types = KNOWN_TYPES.dup
    end

    def add_message(message)
      @messages[message.name] = message
    end

    def add_enum(enum)
      @enums[enum.name] = enum
    end

    def message?(name)
      @messages.key?(name)
    end

    def enum?(name)
      @enums.key?(name)
    end

    def known_type?(name)
      @types.include?(name) || @messages.key?(name) || @enums.key?(name)
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

      document.messages.each { |m| register_message(m) }
      document.enums.each { |e| register_enum(e) }
      document.messages.each { |m| check_fields(m) }

      @errors
    end

    def symbol_table
      @symbol_table
    end

    private

    def register_message(message)
      if @symbol_table.message?(message.name) || @symbol_table.enum?(message.name)
        @errors << error(
          "duplicate message `#{message.name}`",
          line: message.line,
          column: message.column
        )
      end
      @symbol_table.add_message(message)
    end

    def register_enum(enum)
      if @symbol_table.message?(enum.name) || @symbol_table.enum?(enum.name)
        @errors << error(
          "duplicate type `#{enum.name}`",
          line: enum.line,
          column: enum.column
        )
      end
      if enum.values.empty?
        @errors << error(
          "enum `#{enum.name}` has no values",
          line: enum.line,
          column: enum.column
        )
      end
      seen = {}
      enum.values.each do |v|
        if seen.key?(v)
          @errors << error(
            "duplicate enum value `#{v}`",
            line: enum.line,
            column: enum.column
          )
        end
        seen[v] = true
      end
      @symbol_table.add_enum(enum)
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
