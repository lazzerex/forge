require_relative "../generator"

module Forge
  class RustGenerator < Generator
    TYPE_MAP = {
      "string" => "String",
      "int" => "i32",
      "float" => "f64",
      "bool" => "bool"
    }.freeze

    def generate(document)
      parts = document.enums.map { |e| generate_enum(e) }
      parts.concat(document.messages.map { |msg| generate_struct(msg) })
      parts.join("\n\n") + "\n"
    end

    private

    def generate_struct(message)
      if message.fields.empty?
        "pub struct #{message.name} {}"
      else
        fields = message.fields.map { |f| generate_field(f) }.join("\n")
        "#[derive(Debug, Clone, PartialEq)]\npub struct #{message.name} {\n#{fields}\n}"
      end
    end

    def generate_field(field)
      "    pub #{field.name}: #{rust_type(field.type, field.optional)},"
    end

    def rust_type(type, optional)
      rendered = case type.kind
      when :array then "Vec<#{rust_type(type.element, false)}>"
      when :map then "std::collections::HashMap<#{rust_type(type.key_type, false)}, #{rust_type(type.value_type, false)}>"
      else TYPE_MAP[type.name] || type.name
      end
      optional ? "Option<#{rendered}>" : rendered
    end

    def generate_enum(enum)
      values = enum.values.map { |v| "    #{rust_variant(v)}," }.join("\n")
      "#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]\npub enum #{enum.name} {\n#{values}\n}"
    end

    def rust_variant(value)
      value.split("_").map(&:capitalize).join
    end
  end
end