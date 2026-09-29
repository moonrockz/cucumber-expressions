///|
/// A step pattern written as a regular expression, for example
/// `^I have (\d+) cukes$`.
///
/// Each top-level capture group gives one parameter. The registry finds the
/// parameter type from the source of the group, for example `\d+` gives
/// `{int}`. A group with no registered type gives an `AnonymousVal`, and a
/// group that did not match gives `NullVal`.
pub(all) struct RegularExpression {
  priv tree_regexp : TreeRegexp
  priv registry : ParamTypeRegistry
}

///|
/// Compile a regular expression. Raises an error when the regex is not
/// valid.
pub fn RegularExpression::new(
  regexp : String,
  registry? : ParamTypeRegistry = ParamTypeRegistry::default(),
) -> RegularExpression raise ExpressionError {
  let tree_regexp = TreeRegexp::new(regexp) catch {
    e =>
      raise ExpressionError::ValidationError(
        position=0,
        message="Invalid regular expression /\{regexp}/: \{e}",
      )
  }
  { tree_regexp, registry, }
}

///|
/// The source of the regular expression.
pub fn RegularExpression::source(self : RegularExpression) -> String {
  self.tree_regexp.source
}

///|
/// The regex. This is the same as `source`.
pub fn RegularExpression::regexp(self : RegularExpression) -> String {
  self.tree_regexp.source
}

///|
/// Match the regular expression against a text.
///
/// Returns `None` if the text does not match. Raises an
/// `AmbiguousParameterTypeError` when a group matches more than one
/// parameter type and none of them is preferential, and the error of a
/// transformer.
pub fn RegularExpression::match_(
  self : RegularExpression,
  text : String,
) -> Match? raise {
  guard self.tree_regexp.match_(text) is Some(group) else { return None }
  let builders = self.tree_regexp.group_builder.children
  let params : Array[Param] = []
  for i, builder in builders {
    let entry = self.registry.lookup_by_regexp(
      builder.source,
      self.tree_regexp.source,
      text,
    )
    let arg_group = group.children[i]
    let raw = arg_group.value.unwrap_or("")
    let (value, type_) = match (entry, arg_group.value) {
      (_, None) => (NullVal, entry.map(e => e.type_).unwrap_or(Anonymous))
      (Some(entry), Some(_)) => {
        let values = arg_group.values().map(v => v.unwrap_or(""))
        (entry.transformer.call(values), entry.type_)
      }
      (None, Some(_)) =>
        (AnonymousVal(arg_group.values()[0].unwrap_or("")), Anonymous)
    }
    params.push({ value, type_, raw, group: arg_group, })
  }
  Some({ params, })
}
