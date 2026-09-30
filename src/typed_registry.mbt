///|
/// The number of top-level capture groups of all regexps, added together.
fn count_capture_groups(
  name : String,
  regexps : Array[RegexPattern],
) -> Int raise ParameterTypeError {
  let mut total = 0
  for regexp in regexps {
    guard create_group_builder(regexp.to_string()) is Some(builder) else {
      raise InvalidRegexp(name~, regexp=regexp.to_string())
    }
    total = total + builder.children.length()
  }
  total
}

///|
/// Register a typed parameter type that decodes its capture groups with
/// `captures`, and return its handle.
///
/// `captures` must decode as many values as the regexps have top-level
/// capture groups, added over all regexps. A decoder of one value also
/// accepts regexps with no groups; it then gets the whole match. Otherwise
/// `ArityMismatch` is raised. The checks of `register` also apply, before
/// the arity check.
///
/// Groups are counted over all regexps. So with the regexps `(a)b` and `c`,
/// a decoder of one value is accepted, but a match of `c` raises
/// `GroupDidNotMatch`, because the group of the first regexp did not match.
/// Wrap the part in `Captures::optional`, or give each regexp the same
/// groups.
pub fn[T] ParamTypeRegistry::define_with(
  self : ParamTypeRegistry,
  name : String,
  regexps : Array[RegexPattern],
  captures : Captures1[T],
  use_for_snippets? : Bool = true,
  prefer_for_regexp_match? : Bool = false,
) -> ParameterType[T] raise ParameterTypeError {
  self.check_name_and_regexps(name, regexps)
  let groups = count_capture_groups(name, regexps)
  let expected = captures.count
  let fits = if expected == 1 { groups <= 1 } else { groups == expected }
  if !fits {
    raise ArityMismatch(name~, expected~, groups~)
  }
  let handle : ParameterType[T] = ParameterType::new(name)
  self.register(
    name,
    Custom(name),
    regexps,
    transformer=Transformer::with_missing(values => {
      handle.wrap(captures.run(name, values))
    }),
    use_for_snippets~,
    prefer_for_regexp_match~,
  )
  handle
}
