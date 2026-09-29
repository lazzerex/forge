module Forge
  Token = Struct.new(:type, :value, :line, :column, keyword_init: true)
end
