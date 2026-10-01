require_relative "../generator"

module Forge
  class HaxeGenerator < Generator
    TYPE_MAP = {
      "string" => "String",
      "int" => "Int",
      "float" => "Float",
      "bool" => "Bool"
    }.freeze

    RUNTIME_HEADER = "import forge.Runtime;\n"

    def generate(document)
      parts = document.enums.map { |e| generate_enum(e) }
      parts.concat(document.messages.map { |msg| generate_class(msg) })
      header = document.messages.empty? ? "" : RUNTIME_HEADER
      header + parts.join("\n\n") + "\n"
    end

    private

    def generate_class(message)
      if message.fields.empty?
        <<~HAXE.strip
          class #{message.name} {
              public function new() {
              }

              public function toString():String {
                  return Runtime.toString(this, "#{message.name}");
              }

              public function toJson():Dynamic {
                  return Runtime.toJson(this);
              }

              public static function fromJson(json:Dynamic):#{message.name} {
                  var obj = new #{message.name}();
                  Runtime.fromJson(obj, json);
                  return obj;
              }

              public function serialize():String {
                  return Runtime.serialize(this);
              }
          }
        HAXE
      else
        fields = message.fields.map { |f| "    #{generate_field(f)}" }.join("\n")
        <<~HAXE.strip
          class #{message.name} {
          #{fields}

              public function new() {
              }

              public function toString():String {
                  return Runtime.toString(this, "#{message.name}");
              }

              public function toJson():Dynamic {
                  return Runtime.toJson(this);
              }

              public static function fromJson(json:Dynamic):#{message.name} {
                  var obj = new #{message.name}();
                  Runtime.fromJson(obj, json);
                  return obj;
              }

              public function serialize():String {
                  return Runtime.serialize(this);
              }
          }
        HAXE
      end
    end

    def generate_field(field)
      "public var #{field.name}:#{haxe_type(field.type, field.optional)};"
    end

    def haxe_type(type, optional)
      rendered = case type.kind
      when :array then "Array<#{haxe_type(type.element, false)}>"
      when :map then "Map<#{haxe_type(type.key_type, false)}, #{haxe_type(type.value_type, false)}>"
      else TYPE_MAP[type.name] || type.name
      end
      optional ? "Null<#{rendered}>" : rendered
    end

    def generate_enum(enum)
      values = enum.values.map { |v| "        var #{v} = \"#{v}\";" }.join("\n")
      "enum abstract #{enum.name}(String) {\n#{values}\n}"
    end
  end
end
