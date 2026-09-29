///|
/// A step pattern: a Cucumber Expression or a regular expression.
pub(all) enum StepExpression {
  Cucumber(Expression)
  Regular(RegularExpression)
}

///|
/// The source of the expression.
pub fn StepExpression::source(self : StepExpression) -> String {
  match self {
    Cucumber(e) => e.source()
    Regular(e) => e.source()
  }
}

///|
/// Match the expression against a text.
pub fn StepExpression::match_(
  self : StepExpression,
  text : String,
) -> Match? raise {
  match self {
    Cucumber(e) => e.match_(text)
    Regular(e) => e.match_(text)
  }
}

///|
/// Makes a Cucumber Expression or a regular expression from a string, with
/// the same rules as the reference Java implementation:
///
/// - A string that starts with `^` or ends with `$` is a regular expression.
/// - A string that starts and ends with `/` is a regular expression without
///   the slashes.
/// - All other strings are Cucumber Expressions.
pub(all) struct ExpressionFactory {
  priv registry : ParamTypeRegistry
}

///|
pub fn ExpressionFactory::new(
  registry : ParamTypeRegistry,
) -> ExpressionFactory {
  { registry, }
}

///|
/// Make an expression from a string.
pub fn ExpressionFactory::create_expression(
  self : ExpressionFactory,
  expression : String,
) -> StepExpression raise ExpressionError {
  let length = expression.length()
  if length == 0 {
    return Cucumber(Expression::parse_with_registry(expression, self.registry))
  }
  if expression.has_prefix("^") || expression.has_suffix("$") {
    let regex = RegularExpression::new(expression, registry=self.registry) catch {
      ValidationError(..) if has_parameter(expression) =>
        raise ExpressionError::ValidationError(
          position=0,
          message="You cannot use anchors (^ or $) in Cucumber Expressions. Please remove them from \{expression}",
        )
      e => raise e
    }
    return Regular(regex)
  }
  if length >= 2 && expression.has_prefix("/") && expression.has_suffix("/") {
    let inner = expression
      .view(start_offset=1, end_offset=length - 1)
      .to_owned()
    return Regular(RegularExpression::new(inner, registry=self.registry))
  }
  Cucumber(Expression::parse_with_registry(expression, self.registry))
}

///|
/// True when the text has something that looks like a parameter, for
/// example `{int}`.
fn has_parameter(text : String) -> Bool {
  guard text.find("{") is Some(start) else { return false }
  text.view(start_offset=start).contains("}")
}
