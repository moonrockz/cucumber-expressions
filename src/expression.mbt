///|
/// A parsed and compiled cucumber expression, ready for matching.
pub(all) struct Expression {
  priv source : String
  priv tree_regexp : TreeRegexp
  priv parameter_types : Array[ParamTypeEntry]
}

///|
/// A successful match result with extracted parameters.
pub(all) struct Match {
  params : Array[Param]
} derive(Debug, Eq)

///|
/// An extracted parameter value.
///
/// `raw` is the matched text. For `{string}` it is the text between the
/// quotes, before the escaped quotes are changed. `group` is the capture
/// group of the parameter, with its position and the groups inside it.
pub(all) struct Param {
  value : ParamValue
  type_ : ParamType
  raw : String
  group : Group
} derive(Debug, Eq)

///|
/// Parse a cucumber expression with the default parameter type registry.
pub fn Expression::parse(
  expression : String,
) -> Expression raise ExpressionError {
  Expression::parse_with_registry(expression, ParamTypeRegistry::default())
}

///|
/// Parse a cucumber expression with a custom parameter type registry.
pub fn Expression::parse_with_registry(
  expression : String,
  registry : ParamTypeRegistry,
) -> Expression raise ExpressionError {
  let ast = parse_expression(expression)
  let compiled = compile_ast(expression, ast, registry)
  let tree_regexp = TreeRegexp::new(compiled.regex, on_error=detail => {
    regex_does_not_compile_error(compiled.regex, detail)
  })
  let groups = tree_regexp.group_builder.children.length()
  if groups != compiled.parameter_types.length() {
    raise regex_does_not_compile_error(
      compiled.regex,
      "it has \{groups} top-level capture groups, but \{compiled.parameter_types.length()} parameters",
    )
  }
  {
    source: expression,
    tree_regexp,
    parameter_types: compiled.parameter_types,
  }
}

///|
/// Get the original expression source string.
pub fn Expression::source(self : Expression) -> String {
  self.source
}

///|
/// Get the regex that this expression compiles to.
pub fn Expression::regexp(self : Expression) -> String {
  self.tree_regexp.source
}

///|
/// Match this expression against a text string.
///
/// Returns `None` if the text does not match. Each transformer gets the
/// values of the capture groups of its parameter, or the whole match of the
/// parameter when its regexps have no capture groups. A group that did not
/// match gives an empty string. An error from a transformer goes to the
/// caller.
pub fn Expression::match_(self : Expression, text : String) -> Match? raise {
  guard self.tree_regexp.match_(text) is Some(group) else { return None }
  let arg_groups = group.children
  let params = self.parameter_types.mapi((i, entry) => {
    let group = arg_groups[i]
    let values = group.values().map(v => v.unwrap_or(""))
    let value = entry.transformer.call(values)
    { value, type_: entry.type_, raw: raw_text(entry.type_, group), group, }
  })
  Some({ params, })
}

///|
fn raw_text(type_ : ParamType, group : Group) -> String {
  let s = group.value.unwrap_or("")
  let quoted = s.length() >= 2 &&
    (
      (s.has_prefix("\"") && s.has_suffix("\"")) ||
      (s.has_prefix("'") && s.has_suffix("'"))
    )
  match type_ {
    String_ if quoted =>
      s.view(start_offset=1, end_offset=s.length() - 1).to_owned()
    _ => s
  }
}

///|
#deprecated
pub extend Match with Eq::{not_equal, equal}

///|
#deprecated
pub extend Match with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Param with Eq::{not_equal, equal}

///|
#deprecated
pub extend Param with @debug.Debug::{to_repr}
