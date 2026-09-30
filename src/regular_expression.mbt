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
  let tree_regexp = TreeRegexp::new(regexp, on_error=detail => {
    ValidationError(
      position=0,
      message="Invalid regular expression /\{regexp}/: \{detail}",
    )
  })
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
        let values = typed_values(entry, builder.source, arg_group.values())
        (entry.transformer.call_with_missing(values), entry.type_)
      }
      (None, Some(_)) =>
        (AnonymousVal(arg_group.values()[0].unwrap_or("")), Anonymous)
    }
    params.push({ value, type_, raw, group: arg_group, })
  }
  Some({ params, })
}

///|
/// The values for the transformer of `entry`, when the group has the
/// regexp `source`.
///
/// A typed parameter type decodes the groups of all its regexps. The group
/// has only the groups of one regexp, so put them at the offset of that
/// regexp, and give `None` for the groups of the other regexps. Other
/// transformers get `values` unchanged.
fn typed_values(
  entry : ParamTypeEntry,
  source : String,
  values : Array[String?],
) -> Array[String?] {
  guard entry.transformer.with_missing is Some(_) && entry.patterns.length() > 1 else {
    return values
  }
  let counts = entry.patterns.map(p => {
    match create_group_builder(p.to_string()) {
      Some(builder) => builder.children.length()
      None => 0
    }
  })
  let total = counts.fold(init=0, (a, b) => a + b)
  guard total > 0 else { return values }
  let result : Array[String?] = Array::make(total, None)
  let mut offset = 0
  for i, pattern in entry.patterns {
    if pattern.to_string() == source {
      for j in 0..<counts[i] {
        result[offset + j] = values.get(j).unwrap_or(None)
      }
      return result
    }
    offset = offset + counts[i]
  }
  values
}
