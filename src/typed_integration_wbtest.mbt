///|
test "typed types: the snippet generator uses them" {
  let reg = ParamTypeRegistry::default()
  let _ = reg.define1("fruit", [RegexPattern("apple|pear")], s => s)
  let generated = CucumberExpressionGenerator::new(reg).generate_expressions(
    "I eat a pear",
  )
  inspect(generated[0].source(), content="I eat a {fruit}")
}

///|
test "typed types: a regular expression group resolves to them" {
  let reg = ParamTypeRegistry::default()
  let fruit = reg.define1(
    "fruit",
    [RegexPattern("apple|pear")],
    s => s.to_upper(),
    prefer_for_regexp_match=true,
  )
  let expr = RegularExpression::new("^I eat an? (apple|pear)$", registry=reg)
  guard expr.match_("I eat a pear") is Some(m) else { fail("expected a match") }
  inspect(fruit.get(m.params[0]), content="PEAR")
}

///|
test "typed types: an unmatched regular expression group is NullVal" {
  let reg = ParamTypeRegistry::default()
  let _ = reg.define1(
    "fruit",
    [RegexPattern("apple|pear")],
    s => s,
    prefer_for_regexp_match=true,
  )
  let expr = RegularExpression::new("^I eat ?(apple|pear)?$", registry=reg)
  guard expr.match_("I eat") is Some(m) else { fail("expected a match") }
  debug_inspect(m.params[0].value, content="NullVal")
}

///|
test "typed types: a regular expression group of any regexp of the type" {
  let reg_first = ParamTypeRegistry::default()
  let first = reg_first.define_with(
    "either",
    [RegexPattern("(\\d+)"), RegexPattern("([A-Z]+)")],
    Captures::optional(Captures::int())
    .zip(Captures::optional(Captures::string()))
    .map((n, s) => (n, s)),
  )
  let expr = RegularExpression::new("^x ((\\d+))$", registry=reg_first)
  guard expr.match_("x 5") is Some(m) else { fail("expected a match") }
  debug_inspect(first.get(m.params[0]), content="(Some(5), None)")
  let reg_second = ParamTypeRegistry::default()
  let second = reg_second.define_with(
    "either",
    [RegexPattern("(\\d+)"), RegexPattern("([A-Z]+)")],
    Captures::optional(Captures::int())
    .zip(Captures::optional(Captures::string()))
    .map((n, s) => (n, s)),
  )
  let expr = RegularExpression::new("^x (([A-Z]+))$", registry=reg_second)
  guard expr.match_("x AB") is Some(m) else { fail("expected a match") }
  debug_inspect(second.get(m.params[0]), content="(None, Some(\"AB\"))")
}

///|
test "typed types: a group of another regexp that did not match raises" {
  let reg = ParamTypeRegistry::default()
  let strict = reg.define2(
    "strict",
    [RegexPattern("(\\d+)"), RegexPattern("([A-Z]+)")],
    (a, b) => a + b,
  )
  let message = try
    RegularExpression::new("^x ((\\d+))$", registry=reg).match_("x 5")
  catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="Capture group 2 of the parameter type {strict} did not match",
  )
  ignore(strict)
}
