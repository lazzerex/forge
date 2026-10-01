module Forge
  class Document
    attr_reader :messages, :enums, :imports

    def initialize(messages, enums = [], imports = [])
      @messages = messages
      @enums = enums
      @imports = imports
    end
  end

  class Import
    attr_reader :path, :line, :column

    def initialize(path:, line:, column:)
      @path = path
      @line = line
      @column = column
    end
  end

  class FieldType
    attr_reader :kind, :name, :element, :key_type, :value_type

    def initialize(kind:, name:, element: nil, key_type: nil, value_type: nil)
      @kind = kind
      @name = name
      @element = element
      @key_type = key_type
      @value_type = value_type
    end

    def named?
      @kind == :named
    end

    def array?
      @kind == :array
    end

    def map?
      @kind == :map
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
    attr_reader :name, :type, :optional, :line, :column

    def initialize(name:, type:, optional: false, line:, column:)
      @name = name
      @type = type
      @optional = optional
      @line = line
      @column = column
    end

    def type_name
      @type.name
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
