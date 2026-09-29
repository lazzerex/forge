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
      header = document.messages.empty? ? "" : RUNTIME_HEADER
      header + document.messages.map { |msg| generate_class(msg) }.join("\n\n") + "\n"
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
      haxe_type = TYPE_MAP[field.type_name] || field.type_name
      "public var #{field.name}:#{haxe_type};"
    end
  end
end
