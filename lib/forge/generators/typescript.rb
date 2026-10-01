require_relative "../generator"

module Forge
  class TypeScriptGenerator < Generator
    TYPE_MAP = {
      "string" => "string",
      "int" => "number",
      "float" => "number",
      "bool" => "boolean"
    }.freeze

    def generate(document)
      parts = document.enums.map { |e| generate_enum(e) }
      parts.concat(document.messages.map { |msg| generate_interface(msg) })
      parts.join("\n\n") + "\n"
    end

    private

    def generate_interface(message)
      if message.fields.empty?
        "export interface #{message.name} {\n}"
      else
        fields = message.fields.map { |f| "    #{ts_field(f)}" }.join("\n")
        "export interface #{message.name} {\n#{fields}\n}"
      end
    end

    def ts_field(field)
      optional = field.optional ? "?" : ""
      "#{field.name}#{optional}: #{ts_type(field.type)};"
    end

    def ts_type(type)
      case type.kind
      when :array then "#{ts_type(type.element)}[]"
      when :map then "{ [key: #{ts_type(type.key_type)}]: #{ts_type(type.value_type)} }"
      else TYPE_MAP[type.name] || type.name
      end
    end

    def generate_enum(enum)
      values = enum.values.map { |v| "\"#{v}\"" }.join(" | ")
      "export type #{enum.name} = #{values};"
    end
  end
end
