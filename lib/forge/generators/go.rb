require_relative "../generator"

module Forge
  class GoGenerator < Generator
    TYPE_MAP = {
      "string" => "string",
      "int" => "int",
      "float" => "float64",
      "bool" => "bool"
    }.freeze

    def generate(document)
      parts = document.enums.map { |e| generate_enum(e) }
      parts.concat(document.messages.map { |msg| generate_struct(msg) })
      "package schema\n\n" + parts.join("\n\n") + "\n"
    end

    private

    def generate_struct(message)
      if message.fields.empty?
        "type #{message.name} struct {\n}"
      else
        fields = message.fields.map { |f| generate_field(f) }.join("\n")
        "type #{message.name} struct {\n#{fields}\n}"
      end
    end

    def generate_field(field)
      go_type = go_type(field.type, field.optional)
      exported = field.name[0].upcase + field.name[1..]
      tag = field.optional ? "#{field.name},omitempty" : field.name
      "    #{exported} #{go_type} `json:\"#{tag}\"`"
    end

    def go_type(type, optional)
      case type.kind
      when :array then "[]#{go_type(type.element, false)}"
      when :map then "map[#{go_type(type.key_type, false)}]#{go_type(type.value_type, false)}"
      else
        base = TYPE_MAP[type.name] || type.name
        optional ? "*#{base}" : base
      end
    end

    def generate_enum(enum)
      values = enum.values.map { |v| "    #{enum.name}#{v} #{enum.name} = \"#{v}\"" }.join("\n")
      "type #{enum.name} string\n\nconst (\n#{values}\n)"
    end
  end
end
