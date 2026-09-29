///|
/// The kind of a token in a cucumber expression.
pub(all) enum TokenType {
  StartOfLine
  EndOfLine
  WhiteSpace
  BeginOptional
  EndOptional
  BeginParameter
  EndParameter
  Alternation
  Text
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A token of a cucumber expression.
///
/// `start` and `end` are code point offsets into the expression. For a text
/// token, the range includes the escape characters, but `text` does not.
pub(all) struct Token {
  type_ : TokenType
  text : String
  start : Int
  end : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
let escape_character : Char = '\\'

///|
fn can_escape(ch : Char) -> Bool {
  match ch {
    ' ' | '\\' | '/' | '{' | '}' | '(' | ')' => true
    _ => false
  }
}

///|
fn token_type_of(ch : Char) -> TokenType {
  match ch {
    ' ' => WhiteSpace
    '/' => Alternation
    '{' => BeginParameter
    '}' => EndParameter
    '(' => BeginOptional
    ')' => EndOptional
    _ => Text
  }
}

///|
/// The character a token type stands for, or "" for other token types.
fn symbol_of(type_ : TokenType) -> String {
  match type_ {
    BeginOptional => "("
    EndOptional => ")"
    BeginParameter => "{"
    EndParameter => "}"
    Alternation => "/"
    _ => ""
  }
}

///|
/// What a token type is used for, as text for error messages.
fn purpose_of(type_ : TokenType) -> String {
  match type_ {
    BeginOptional | EndOptional => "optional text"
    BeginParameter | EndParameter => "a parameter"
    Alternation => "alternation"
    _ => ""
  }
}

///|
/// Tokenize a cucumber expression.
///
/// The result starts with a `StartOfLine` token and ends with an `EndOfLine`
/// token. Adjacent text and adjacent white space join into one token. Only a
/// space is white space.
pub fn tokenize(expression : String) -> Array[Token] raise ExpressionError {
  let chars = expression.to_array()
  let tokens : Array[Token] = []
  let buffer = StringBuilder()
  let mut buffer_length = 0
  let mut buffer_start = 0
  let mut previous_type : TokenType = StartOfLine
  let mut treat_as_text = false
  let mut escaped = 0
  fn flush(type_ : TokenType) -> Unit {
    let mut escape_tokens = 0
    if type_ == Text {
      escape_tokens = escaped
      escaped = 0
    }
    let end = buffer_start + buffer_length + escape_tokens
    tokens.push({ type_, text: buffer.to_string(), start: buffer_start, end, })
    buffer.reset()
    buffer_length = 0
    buffer_start = end
  }

  if chars.is_empty() {
    tokens.push({ type_: StartOfLine, text: "", start: 0, end: 0, })
  }
  for ch in chars {
    if !treat_as_text && ch == escape_character {
      escaped = escaped + 1
      treat_as_text = true
      continue
    }
    let current_type : TokenType = if treat_as_text {
      if !can_escape(ch) {
        raise cant_escape_error(
          expression,
          buffer_start + buffer_length + escaped,
        )
      }
      Text
    } else {
      token_type_of(ch)
    }
    treat_as_text = false
    let new_token = current_type != previous_type ||
      (current_type != WhiteSpace && current_type != Text)
    if new_token {
      flush(previous_type)
    }
    previous_type = current_type
    buffer.write_char(ch)
    buffer_length = buffer_length + 1
  }
  if buffer_length > 0 {
    flush(previous_type)
  }
  if treat_as_text {
    raise end_of_line_escaped_error(expression)
  }
  tokens.push({
    type_: EndOfLine,
    text: "",
    start: chars.length(),
    end: chars.length(),
  })
  tokens
}

///|
pub extend TokenType with ToJson::{to_json}

///|
pub extend TokenType with @json.FromJson::{from_json}

///|
#deprecated
pub extend TokenType with Eq::{not_equal, equal}

///|
#deprecated
pub extend TokenType with @debug.Debug::{to_repr}

///|
pub extend Token with ToJson::{to_json}

///|
pub extend Token with @json.FromJson::{from_json}

///|
#deprecated
pub extend Token with Eq::{not_equal, equal}

///|
#deprecated
pub extend Token with @debug.Debug::{to_repr}
