///|
/// Errors that can occur when a cucumber expression is parsed or compiled.
///
/// `position` is the code point offset of the problem in the expression.
/// `message` is the full message, in the same format as the reference
/// implementation.
pub suberror ExpressionError {
  /// A `{` has no matching `}`.
  UnmatchedBrace(position~ : Int, message~ : String)
  /// A `(` has no matching `)`.
  UnmatchedParen(position~ : Int, message~ : String)
  /// A character that can not be escaped follows a `\`.
  CannotEscape(position~ : Int, character~ : Char, message~ : String)
  /// The expression ends with a `\`.
  UnexpectedEscapeEnd(position~ : Int, message~ : String)
  /// The expression has a structure that is not permitted, for example an
  /// optional inside an optional.
  ValidationError(position~ : Int, message~ : String)
  /// The expression uses a parameter type that is not registered.
  UnknownParameterType(name~ : String, position~ : Int, message~ : String)
} derive(Debug)

///|
/// The full error message.
pub fn ExpressionError::message(self : ExpressionError) -> String {
  match self {
    UnmatchedBrace(message~, ..)
    | UnmatchedParen(message~, ..)
    | CannotEscape(message~, ..)
    | UnexpectedEscapeEnd(message~, ..)
    | ValidationError(message~, ..)
    | UnknownParameterType(message~, ..) => message
  }
}

///|
/// The code point offset of the problem in the expression.
pub fn ExpressionError::position(self : ExpressionError) -> Int {
  match self {
    UnmatchedBrace(position~, ..)
    | UnmatchedParen(position~, ..)
    | CannotEscape(position~, ..)
    | UnexpectedEscapeEnd(position~, ..)
    | ValidationError(position~, ..)
    | UnknownParameterType(position~, ..) => position
  }
}

///|
pub impl Show for ExpressionError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
pub extend ExpressionError with Show::{to_string, output}

///|
/// Build a message in the reference format.
fn error_message(
  index : Int,
  expression : String,
  pointer : String,
  problem : String,
  solution : String,
) -> String {
  "This Cucumber Expression has a problem at column \{index + 1}:\n\n\{expression}\n\{pointer}\n\{problem}.\n\{solution}"
}

///|
fn point_at(index : Int) -> String {
  " ".repeat(index) + "^"
}

///|
fn point_at_range(start : Int, end : Int) -> String {
  let buf = StringBuilder()
  buf.write_string(point_at(start))
  if start + 1 < end {
    buf.write_string("-".repeat(end - start - 2))
    buf.write_char('^')
  }
  buf.to_string()
}

///|
fn cant_escape_error(expression : String, index : Int) -> ExpressionError {
  let chars = expression.to_array()
  CannotEscape(
    position=index,
    character=chars[index],
    message=error_message(
      index,
      expression,
      point_at(index),
      "Only the characters '{', '}', '(', ')', '\\', '/' and whitespace can be escaped",
      "If you did mean to use an '\\' you can use '\\\\' to escape it",
    ),
  )
}

///|
fn end_of_line_escaped_error(expression : String) -> ExpressionError {
  let index = expression.to_array().length() - 1
  UnexpectedEscapeEnd(
    position=index,
    message=error_message(
      index,
      expression,
      point_at(index),
      "The end of line can not be escaped",
      "You can use '\\\\' to escape the '\\'",
    ),
  )
}

///|
fn missing_end_token_error(
  expression : String,
  begin : TokenType,
  end : TokenType,
  current : Token,
) -> ExpressionError {
  let begin_symbol = symbol_of(begin)
  let end_symbol = symbol_of(end)
  let purpose = purpose_of(begin)
  let message = error_message(
    current.start,
    expression,
    point_at_range(current.start, current.end),
    "The '\{begin_symbol}' does not have a matching '\{end_symbol}'",
    "If you did not intend to use \{purpose} you can use '\\\{begin_symbol}' to escape the \{purpose}",
  )
  match begin {
    BeginParameter => UnmatchedBrace(position=current.start, message~)
    _ => UnmatchedParen(position=current.start, message~)
  }
}

///|
fn alternation_in_optional_error(
  expression : String,
  current : Token,
) -> ExpressionError {
  ValidationError(
    position=current.start,
    message=error_message(
      current.start,
      expression,
      point_at_range(current.start, current.end),
      "An alternation can not be used inside an optional",
      "If you did not mean to use an alternation you can use '\\/' to escape the '/'. Otherwise rephrase your expression or consider using a regular expression instead.",
    ),
  )
}

///|
fn invalid_parameter_name_in_node_error(
  expression : String,
  token : Token,
) -> ExpressionError {
  ValidationError(
    position=token.start,
    message=error_message(
      token.start,
      expression,
      point_at_range(token.start, token.end),
      "Parameter names may not contain '{', '}', '(', ')', '\\' or '/'",
      "Did you mean to use a regular expression?",
    ),
  )
}

///|
/// An error about a node, with the pointer under the whole node.
fn node_error(
  expression : String,
  node : Node,
  problem : String,
  solution : String,
) -> ExpressionError {
  ValidationError(
    position=node.start,
    message=error_message(
      node.start,
      expression,
      point_at_range(node.start, node.end),
      problem,
      solution,
    ),
  )
}

///|
fn undefined_parameter_type_error(
  expression : String,
  node : Node,
  name : String,
) -> ExpressionError {
  UnknownParameterType(
    name~,
    position=node.start,
    message=error_message(
      node.start,
      expression,
      point_at_range(node.start, node.end),
      "Undefined parameter type '\{name}'",
      "Please register a ParameterType for '\{name}'",
    ),
  )
}

///|
/// The compiled regex does not compile, for example because a parameter
/// type has a regexp that is not valid. There is no column in the
/// expression for this problem, so the position is 0.
fn regex_does_not_compile_error(
  regex : String,
  error : String,
) -> ExpressionError {
  ValidationError(
    position=0,
    message="The regex \{regex} of this Cucumber Expression does not compile: \{error}",
  )
}

///|
#deprecated
pub extend ExpressionError with @debug.Debug::{to_repr}

///|
/// Errors that can occur when a parameter type is registered.
pub suberror ParameterTypeError {
  /// A parameter type with the name is already registered.
  DuplicateParameterType(name~ : String)
  /// The name has a character that is not permitted.
  IllegalParameterName(name~ : String)
  /// The parameter type has no regexps.
  NoRegexps(name~ : String)
  /// Two preferential parameter types have the same regexp.
  DuplicatePreferentialParameterType(
    regexp~ : String,
    first~ : String,
    second~ : String
  )
  /// A typed handle was used on a parameter of another type.
  WrongParameterType(expected~ : String, actual~ : String)
  /// No parameter of the match has the type of the handle.
  MissingParameter(name~ : String)
  /// More than one parameter of the match has the type of the handle.
  AmbiguousParameter(name~ : String, count~ : Int)
} derive(Debug)

///|
/// The error message.
pub fn ParameterTypeError::message(self : ParameterTypeError) -> String {
  match self {
    DuplicateParameterType(name="") =>
      "The anonymous parameter type has already been defined"
    DuplicateParameterType(name~) =>
      "There is already a parameter type with name \{name}"
    IllegalParameterName(name~) =>
      "Illegal character in parameter name {\{name}}. Parameter names may not contain '{', '}', '(', ')', '\\' or '/'"
    NoRegexps(name~) =>
      "The parameter type {\{name}} must have at least one regexp"
    DuplicatePreferentialParameterType(regexp~, first~, second~) =>
      "There can only be one preferential parameter type per regexp. The regexp /\{regexp}/ is used for two preferential parameter types, {\{first}} and {\{second}}"
    WrongParameterType(expected~, actual~) =>
      "Expected a parameter of type {\{expected}}, but the parameter has type {\{actual}}"
    MissingParameter(name~) => "The match has no parameter of type {\{name}}"
    AmbiguousParameter(name~, count~) =>
      "The match has \{count} parameters of type {\{name}}; use get_all"
  }
}

///|
pub impl Show for ParameterTypeError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
pub extend ParameterTypeError with Show::{to_string, output}

///|
#deprecated
pub extend ParameterTypeError with @debug.Debug::{to_repr}

///|
/// A capture group of a regular expression matches more than one parameter
/// type, and none of them is preferential.
pub suberror AmbiguousParameterTypeError {
  AmbiguousParameterType(
    regexp~ : String,
    expression_regexp~ : String,
    names~ : Array[String],
    generated~ : Array[String]
  )
} derive(Debug)

///|
/// The error message, in the same format as the reference implementation.
pub fn AmbiguousParameterTypeError::message(
  self : AmbiguousParameterTypeError,
) -> String {
  let AmbiguousParameterType(regexp~, expression_regexp~, names~, generated~) = self
  let names = names.map(n => "{\{n}}").join("\n   ")
  let generated = generated.join("\n   ")
  (
    $|Your Regular Expression /\{expression_regexp}/
    $|matches multiple parameter types with regexp \{regexp}:
    $|   \{names}
    $|
    $|I couldn't decide which one to use. You have two options:
    $|
    $|1) Use a Cucumber Expression instead of a Regular Expression. Try one of these:
    $|   \{generated}
    $|
    $|2) Make one of the parameter types preferential and continue to use a Regular Expression.
    $|
  )
}

///|
pub impl Show for AmbiguousParameterTypeError with fn output(self, logger) {
  logger.write_string(self.message())
}

///|
pub extend AmbiguousParameterTypeError with Show::{to_string, output}

///|
#deprecated
pub extend AmbiguousParameterTypeError with @debug.Debug::{to_repr}
