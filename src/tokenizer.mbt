///|
/// Tokens produced by the cucumber expression tokenizer.
pub(all) enum Token {
  /// Literal text content.
  Text(String)
  /// Opening brace `{` — start of parameter.
  BeginParameter
  /// Closing brace `}` — end of parameter.
  EndParameter
  /// Opening parenthesis `(` — start of optional.
  BeginOptional
  /// Closing parenthesis `)` — end of optional.
  EndOptional
  /// Forward slash `/` — alternation separator.
  Alternation
  /// Whitespace run.
  WhiteSpace(String)
} derive(Show, Eq)

///|
/// Tokenize a cucumber expression string into an array of tokens.
///
/// Converts the raw expression into a flat token stream. Does not validate
/// matching braces or parentheses — that is the parser's responsibility.
pub fn tokenize(expression : String) -> Array[Token] raise ExpressionError {
  let tokens : Array[Token] = []
  let buf = StringBuilder::new()
  let chars = expression.to_array()
  let len = chars.length()
  let mut i = 0
  while i < len {
    let ch = chars[i]
    match ch {
      '\\' => {
        if i + 1 >= len {
          raise ExpressionError::UnexpectedEscapeEnd(
            position=i,
            message="The end of line can not be escaped",
          )
        }
        let next = chars[i + 1]
        if is_escapable(next) {
          buf.write_char(next)
          i = i + 2
        } else {
          raise ExpressionError::CannotEscape(
            position=i,
            character=next,
            message="Can't escape '\{next}'",
          )
        }
      }
      '{' => {
        flush_text(tokens, buf)
        tokens.push(BeginParameter)
        i = i + 1
      }
      '}' => {
        flush_text(tokens, buf)
        tokens.push(EndParameter)
        i = i + 1
      }
      '(' => {
        flush_text(tokens, buf)
        tokens.push(BeginOptional)
        i = i + 1
      }
      ')' => {
        flush_text(tokens, buf)
        tokens.push(EndOptional)
        i = i + 1
      }
      '/' => {
        flush_text(tokens, buf)
        tokens.push(Alternation)
        i = i + 1
      }
      _ =>
        if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
          flush_text(tokens, buf)
          let ws = StringBuilder::new()
          ws.write_char(ch)
          i = i + 1
          while i < len {
            let wch = chars[i]
            if wch == ' ' || wch == '\t' || wch == '\n' || wch == '\r' {
              ws.write_char(wch)
              i = i + 1
            } else {
              break
            }
          }
          tokens.push(WhiteSpace(ws.to_string()))
        } else {
          buf.write_char(ch)
          i = i + 1
        }
    }
  }
  flush_text(tokens, buf)
  tokens
}

///|
fn flush_text(tokens : Array[Token], buf : StringBuilder) -> Unit {
  let s = buf.to_string()
  if s.length() > 0 {
    tokens.push(Text(s))
    buf.reset()
  }
}

///|
fn is_escapable(ch : Char) -> Bool {
  match ch {
    '(' | ')' | '{' | '}' | '/' | '\\' | ' ' => true
    _ => false
  }
}
