require_relative "test_helper"
require_relative "../lib/forge/lexer"
require_relative "../lib/forge/errors"

class LexerTest < Minitest::Test
  def test_empty_input
    tokens = Forge::Lexer.new("").tokenize
    assert_equal 1, tokens.length
    assert_equal :EOF, tokens[0].type
  end

  def test_single_message_keyword
    tokens = Forge::Lexer.new("message").tokenize
    assert_equal :KEYWORD, tokens[0].type
    assert_equal "message", tokens[0].value
  end

  def test_identifier
    tokens = Forge::Lexer.new("User").tokenize
    assert_equal :IDENTIFIER, tokens[0].type
    assert_equal "User", tokens[0].value
  end

  def test_types
    tokens = Forge::Lexer.new("string int float bool").tokenize
    assert_equal 5, tokens.length
    types = tokens.map(&:type)
    assert_equal [:TYPE, :TYPE, :TYPE, :TYPE, :EOF], types
    assert_equal %w[string int float bool], tokens.map(&:value).take(4)
  end

  def test_braces_and_semicolons
    tokens = Forge::Lexer.new("{ } ;").tokenize
    assert_equal [:LBRACE, :RBRACE, :SEMICOLON, :EOF], tokens.map(&:type)
  end

  def test_simple_message
    tokens = Forge::Lexer.new("message User { }").tokenize
    types = tokens.map(&:type)
    assert_equal [:KEYWORD, :IDENTIFIER, :LBRACE, :RBRACE, :EOF], types
  end

  def test_full_message
    source = "message User {\n  string id;\n  string name;\n  int age;\n  bool active;\n}"
    tokens = Forge::Lexer.new(source).tokenize
    expected = [
      [:KEYWORD, "message"],
      [:IDENTIFIER, "User"],
      [:LBRACE, "{"],
      [:TYPE, "string"],
      [:IDENTIFIER, "id"],
      [:SEMICOLON, ";"],
      [:TYPE, "string"],
      [:IDENTIFIER, "name"],
      [:SEMICOLON, ";"],
      [:TYPE, "int"],
      [:IDENTIFIER, "age"],
      [:SEMICOLON, ";"],
      [:TYPE, "bool"],
      [:IDENTIFIER, "active"],
      [:SEMICOLON, ";"],
      [:RBRACE, "}"],
      [:EOF, ""]
    ]
    assert_equal expected.length, tokens.length
    tokens.zip(expected).each do |actual, exp|
      assert_equal exp[0], actual.type
      assert_equal exp[1], actual.value
    end
  end

  def test_multiple_messages
    source = <<~FORGE
      message User {
        string name;
      }
      message Post {
        string title;
      }
    FORGE
    tokens = Forge::Lexer.new(source).tokenize
    keywords = tokens.select { |t| t.type == :KEYWORD }
    assert_equal 2, keywords.length
  end

  def test_comments_skipped
    source = "// this is a comment\nmessage"
    tokens = Forge::Lexer.new(source).tokenize
    assert_equal [:KEYWORD, :EOF], tokens.map(&:type)
  end

  def test_inline_comment
    source = "message // comment\nUser"
    tokens = Forge::Lexer.new(source).tokenize
    assert_equal [:KEYWORD, :IDENTIFIER, :EOF], tokens.map(&:type)
  end

  def test_multiple_comment_lines
    source = "// line 1\n// line 2\nmessage"
    tokens = Forge::Lexer.new(source).tokenize
    assert_equal [:KEYWORD, :EOF], tokens.map(&:type)
  end

  def test_whitespace_handling
    tokens = Forge::Lexer.new("  \t\n  message  \n  ").tokenize
    assert_equal [:KEYWORD, :EOF], tokens.map(&:type)
  end

  def test_line_tracking
    source = "message\nUser\n{"
    tokens = Forge::Lexer.new(source).tokenize
    assert_equal 1, tokens[0].line
    assert_equal 2, tokens[1].line
    assert_equal 3, tokens[2].line
  end

  def test_column_tracking
    tokens = Forge::Lexer.new("  name").tokenize
    assert_equal 3, tokens[0].column
  end

  def test_column_tracking_after_newline
    source = "a\n  b"
    tokens = Forge::Lexer.new(source).tokenize
    assert_equal 1, tokens[0].column
    assert_equal 3, tokens[1].column
  end

  def test_invalid_character_raises
    err = assert_raises(Forge::LexerError) { Forge::Lexer.new("@").tokenize }
    assert_match(/Unexpected character/, err.message)
    assert_match(/1:1/, err.message)
  end

  def test_invalid_character_location
    err = assert_raises(Forge::LexerError) { Forge::Lexer.new("  @").tokenize }
    assert_match(/1:3/, err.message)
  end

  def test_identifier_with_underscores
    tokens = Forge::Lexer.new("_private").tokenize
    assert_equal :IDENTIFIER, tokens[0].type
    assert_equal "_private", tokens[0].value
  end

  def test_identifier_with_digits
    tokens = Forge::Lexer.new("field2").tokenize
    assert_equal :IDENTIFIER, tokens[0].type
    assert_equal "field2", tokens[0].value
  end

  def test_type_keyword_not_overridden_by_identifier
    tokens = Forge::Lexer.new("string").tokenize
    assert_equal :TYPE, tokens[0].type
  end

  def test_message_keyword_not_overridden
    tokens = Forge::Lexer.new("message").tokenize
    assert_equal :KEYWORD, tokens[0].type
  end

  def test_eof_always_present
    tokens = Forge::Lexer.new("a").tokenize
    assert_equal :EOF, tokens.last.type
  end

  def test_eof_always_last
    tokens = Forge::Lexer.new("message User { string name; }").tokenize
    assert_equal :EOF, tokens.last.type
  end

  def test_no_tokens_after_eof
    tokens = Forge::Lexer.new("").tokenize
    assert_equal 1, tokens.length
  end

  def test_enum_keyword
    tokens = Forge::Lexer.new("enum").tokenize
    assert_equal :KEYWORD, tokens[0].type
    assert_equal "enum", tokens[0].value
  end

  def test_enum_declaration_tokens
    tokens = Forge::Lexer.new("enum Status { ACTIVE; }").tokenize
    assert_equal [:KEYWORD, :IDENTIFIER, :LBRACE, :IDENTIFIER, :SEMICOLON, :RBRACE, :EOF], tokens.map(&:type)
    assert_equal "Status", tokens[1].value
    assert_equal "ACTIVE", tokens[3].value
  end
end
