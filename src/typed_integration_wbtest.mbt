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
