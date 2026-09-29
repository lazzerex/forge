package forge;

import haxe.Json;

class Runtime {
    public static function toString(obj:Dynamic, className:String):String {
        var fields = Reflect.fields(obj);
        var parts:Array<String> = [];
        for (field in fields) {
            var value:Dynamic = Reflect.field(obj, field);
            parts.push(field + ": " + Std.string(value));
        }
        return className + "(" + parts.join(", ") + ")";
    }

    public static function toJson(obj:Dynamic):Dynamic {
        var result:Dynamic = {};
        for (field in Reflect.fields(obj)) {
            var value:Dynamic = Reflect.field(obj, field);
            if (Std.isOfType(value, String) || Std.isOfType(value, Bool) || Std.isOfType(value, Float) || Std.isOfType(value, Int)) {
                Reflect.setField(result, field, value);
            } else if (Reflect.fields(value).length > 0) {
                Reflect.setField(result, field, toJson(value));
            } else {
                Reflect.setField(result, field, value);
            }
        }
        return result;
    }

    public static function fromJson<T>(obj:T, json:Dynamic):Void {
        for (field in Reflect.fields(json)) {
            var value:Dynamic = Reflect.field(json, field);
            Reflect.setField(obj, field, value);
        }
    }

    public static function serialize(obj:Dynamic):String {
        return Json.stringify(toJson(obj));
    }

    public static function deserialize<T>(obj:T, json:String):Void {
        fromJson(obj, Json.parse(json));
    }
}