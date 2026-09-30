module Forge
  class Document
    attr_reader :messages, :enums

    def initialize(messages, enums = [])
      @messages = messages
      @enums = enums
    end
  end

  class Message
    attr_reader :name, :fields, :line, :column

    def initialize(name:, fields:, line:, column:)
      @name = name
      @fields = fields
      @line = line
      @column = column
    end
  end

  class Field
    attr_reader :name, :type_name, :line, :column

    def initialize(name:, type_name:, line:, column:)
      @name = name
      @type_name = type_name
      @line = line
      @column = column
    end
  end

  class Enum
    attr_reader :name, :values, :line, :column

    def initialize(name:, values:, line:, column:)
      @name = name
      @values = values
      @line = line
      @column = column
    end
  end
end
