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
} derive(Debug)

///|
pub impl Show for ExpressionError with fn output(self, logger) {
  match self {
    UnmatchedBrace(position~, message~) =>
      logger.write_string(
        "UnmatchedBrace(position=\{position}, message=\{Repr(message)})",
      )
    UnmatchedParen(position~, message~) =>
      logger.write_string(
        "UnmatchedParen(position=\{position}, message=\{Repr(message)})",
      )
    CannotEscape(position~, character~, message~) =>
      logger.write_string(
        "CannotEscape(position=\{position}, character=\{Repr(character)}, message=\{Repr(message)})",
      )
    UnexpectedEscapeEnd(position~, message~) =>
      logger.write_string(
        "UnexpectedEscapeEnd(position=\{position}, message=\{Repr(message)})",
      )
    ValidationError(position~, message~) =>
      logger.write_string(
        "ValidationError(position=\{position}, message=\{Repr(message)})",
      )
    UnknownParameterType(name~, message~) =>
      logger.write_string(
        "UnknownParameterType(name=\{Repr(name)}, message=\{Repr(message)})",
      )
  }
}

///|
pub extend ExpressionError with Show::{to_string, output}

///|
#deprecated
pub extend ExpressionError with @debug.Debug::{to_repr}
