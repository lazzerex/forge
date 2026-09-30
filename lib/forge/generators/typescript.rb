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
        fields = message.fields.map { |f| "    #{f.name}: #{TYPE_MAP[f.type_name] || f.type_name};" }.join("\n")
        "export interface #{message.name} {\n#{fields}\n}"
      end
    end

    def generate_enum(enum)
      values = enum.values.map { |v| "\"#{v}\"" }.join(" | ")
      "export type #{enum.name} = #{values};"
    end
  end
end