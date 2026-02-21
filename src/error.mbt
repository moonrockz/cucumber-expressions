///|
/// Errors that can occur during cucumber expression parsing.
pub suberror ExpressionError {
  /// Unmatched opening brace `{`.
  UnmatchedBrace(position~ : Int, message~ : String)
  /// Unmatched opening parenthesis `(`.
  UnmatchedParen(position~ : Int, message~ : String)
  /// Cannot escape the given character.
  CannotEscape(position~ : Int, character~ : Char, message~ : String)
  /// End of line cannot be escaped.
  UnexpectedEscapeEnd(position~ : Int, message~ : String)
  /// Expression validation error (e.g., nested optionals, empty alternation).
  ValidationError(position~ : Int, message~ : String)
  /// Unknown parameter type name.
  UnknownParameterType(name~ : String, message~ : String)
} derive(Show)
