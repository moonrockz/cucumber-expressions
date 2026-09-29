// Ports of the reference RegularExpressionTest, ParameterTypeRegistryTest,
// ExpressionFactoryTest and CucumberExpressionGeneratorTest.

///|
fn regex_values(regexp : String, text : String) -> Array[String]? raise {
  let expr = RegularExpression::new(regexp)
  guard expr.match_(text) is Some(m) else { return None }
  Some(m.params.map(p => p.value.to_string()))
}

///|
test "regular expression: does no transform by default (#16)" {
  debug_inspect(
    regex_values("(\\d\\d)", "22"),
    content="Some([\"AnonymousVal(22)\"])",
  )
}

///|
test "regular expression: does not transform anonymous (#16)" {
  debug_inspect(
    regex_values("(.*)", "22"),
    content="Some([\"AnonymousVal(22)\"])",
  )
}

///|
test "regular expression: transforms negative int (#16)" {
  debug_inspect(
    regex_values("(-?\\d+)", "-22"),
    content="Some([\"IntVal(-22)\"])",
  )
}

///|
test "regular expression: transforms positive int (#16)" {
  debug_inspect(regex_values("(\\d+)", "22"), content="Some([\"IntVal(22)\"])")
}

///|
test "regular expression: returns None when there is no match (#16)" {
  debug_inspect(regex_values("hello", "world"), content="None")
}

///|
test "regular expression: matches empty string (#16)" {
  debug_inspect(
    regex_values("^The value equals \"([^\"]*)\"$", "The value equals \"\""),
    content="Some([\"AnonymousVal()\"])",
  )
}

///|
test "regular expression: nested capture group without match (#16)" {
  debug_inspect(
    regex_values("^a user( named \"([^\"]*)\")?$", "a user"),
    content="Some([\"NullVal\"])",
  )
}

///|
test "regular expression: nested capture group with match (#16)" {
  debug_inspect(
    regex_values("^a user( named \"([^\"]*)\")?$", "a user named \"Charlie\""),
    content="Some([\"AnonymousVal(Charlie)\"])",
  )
}

///|
test "regular expression: capture group nested in optional one (#16)" {
  let regexp = "^a (pre-commercial transaction |pre buyer fee model )?purchase(?: for \\$(\\d+))?$"
  debug_inspect(
    regex_values(regexp, "a purchase"),
    content="Some([\"NullVal\", \"NullVal\"])",
  )
  debug_inspect(
    regex_values(regexp, "a purchase for $33"),
    content="Some([\"NullVal\", \"IntVal(33)\"])",
  )
  debug_inspect(
    regex_values(regexp, "a pre buyer fee model purchase"),
    content="Some([\"AnonymousVal(pre buyer fee model )\", \"NullVal\"])",
  )
}

///|
test "regular expression: ignores non capturing groups (#16)" {
  debug_inspect(
    regex_values(
      "(\\S+) ?(can|cannot)? (?:delete|cancel) the (\\d+)(?:st|nd|rd|th) (attachment|slide) ?(?:upload)?",
      "I can cancel the 1st slide upload",
    ),
    content=(
      #|Some(
      #|  [
      #|    "AnonymousVal(I)",
      #|    "AnonymousVal(can)",
      #|    "IntVal(1)",
      #|    "AnonymousVal(slide)",
      #|  ],
      #|)
    ),
  )
}

///|
test "regular expression: works with escaped parenthesis (#16)" {
  debug_inspect(
    regex_values("Across the line\\(s\\)", "Across the line(s)"),
    content="Some([])",
  )
}

///|
test "regular expression: exposes regexp and source (#16)" {
  let expr = RegularExpression::new("I have (\\d+) cukes? in my (.+) now")
  inspect(expr.source(), content="I have (\\d+) cukes? in my (.+) now")
  inspect(expr.regexp(), content="I have (\\d+) cukes? in my (.+) now")
}

///|
test "regular expression: paren in a character class is not a group (#16)" {
  debug_inspect(
    regex_values("^drawings: ([A-Z_, ()]+)$", "drawings: ONE, TWO(ABC)"),
    content="Some([\"AnonymousVal(ONE, TWO(ABC))\"])",
  )
}

///|
fn capitalised_registry(prefer : Array[Bool]) -> ParamTypeRegistry raise {
  let reg = ParamTypeRegistry::default()
  for i, name in ["name", "person", "place"][:prefer.length()] {
    reg.register(
      name,
      Custom(name),
      [RegexPattern("[A-Z]+\\w+")],
      prefer_for_regexp_match=prefer[i],
    )
  }
  reg
}

///|
test "registry: one preferential parameter type for each regexp (#15)" {
  let err = try capitalised_registry([true, false, true]) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    err,
    content=(
      #|There can only be one preferential parameter type per regexp. The regexp /[A-Z]+\w+/ is used for two preferential parameter types, {name} and {place}
    ),
  )
}

///|
test "registry: looks up the preferential parameter type by regexp (#15)" {
  let reg = capitalised_registry([false, true, false])
  let found = reg.lookup_by_regexp(
    "[A-Z]+\\w+", "([A-Z]+\\w+) and ([A-Z]+\\w+)", "Lisa and Bob",
  )
  debug_inspect(found.map(e => e.name), content="Some(\"person\")")
}

///|
test "registry: ambiguous parameter types for a regexp (#15)" {
  let reg = capitalised_registry([false, false])
  let expr = RegularExpression::new(
    "^([A-Z]+\\w+) and ([A-Z]+\\w+)$",
    registry=reg,
  )
  let err = try expr.match_("Lisa and Bob") catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    err,
    content=(
      #|Your Regular Expression /^([A-Z]+\w+) and ([A-Z]+\w+)$/
      #|matches multiple parameter types with regexp [A-Z]+\w+:
      #|   {name}
      #|   {person}
      #|
      #|I couldn't decide which one to use. You have two options:
      #|
      #|1) Use a Cucumber Expression instead of a Regular Expression. Try one of these:
      #|   {name} and {name}
      #|   {name} and {person}
      #|   {person} and {name}
      #|   {person} and {person}
      #|
      #|2) Make one of the parameter types preferential and continue to use a Regular Expression.
      #|
    ),
  )
}

///|
test "expression factory: creates a regular expression (#17)" {
  let factory = ExpressionFactory::new(ParamTypeRegistry::default())
  inspect(factory.create_expression("^x$") is Regular(_), content="true")
  inspect(factory.create_expression("^x") is Regular(_), content="true")
  inspect(factory.create_expression("x$") is Regular(_), content="true")
  guard factory.create_expression("/(\\d+)/") is Regular(r) else {
    fail("expected a regular expression")
  }
  inspect(r.source(), content="(\\d+)")
}

///|
test "expression factory: creates a cucumber expression (#17)" {
  let factory = ExpressionFactory::new(ParamTypeRegistry::default())
  inspect(factory.create_expression("x") is Cucumber(_), content="true")
  inspect(factory.create_expression("") is Cucumber(_), content="true")
  let expr = factory.create_expression("I have {int} cukes")
  inspect(expr.source(), content="I have {int} cukes")
  guard expr.match_("I have 3 cukes") is Some(m) else { fail("no match") }
  debug_inspect(m.params[0].value, content="IntVal(3)")
}

///|
test "expression factory: anchors in a cucumber expression (#17)" {
  let factory = ExpressionFactory::new(ParamTypeRegistry::default())
  let err = try factory.create_expression("^I have {int} cukes$") catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    err,
    content="You cannot use anchors (^ or $) in Cucumber Expressions. Please remove them from ^I have {int} cukes$",
  )
}

///|
fn generator() -> (ParamTypeRegistry, CucumberExpressionGenerator) {
  let reg = ParamTypeRegistry::default()
  (reg, CucumberExpressionGenerator::new(reg))
}

///|
/// Check the first generated expression, its parameter infos, and that it
/// matches the text.
fn assert_generated(
  reg : ParamTypeRegistry,
  expected : String,
  infos : Array[(String, Int)],
  text : String,
) -> Unit raise {
  let generated = CucumberExpressionGenerator::new(reg).generate_expressions(
      text,
    )[0]
  assert_eq(generated.source(), expected)
  assert_eq(generated.parameter_infos().map(i => (i.name, i.count)), infos)
  let expr = Expression::parse_with_registry(generated.source(), reg)
  guard expr.match_(text) is Some(m) else {
    fail("'\{text}' does not match '\{generated.source()}'")
  }
  assert_eq(m.params.length(), infos.length())
}

///|
test "generator: documents expression generation (#18)" {
  let (_, gen) = generator()
  let generated = gen.generate_expressions("I have 2 cucumbers and 1.5 tomato")[0]
  inspect(
    generated.source(),
    content="I have {int} cucumbers and {float} tomato",
  )
  inspect(generated.parameter_names()[0], content="int")
  inspect(generated.parameter_types[1].name, content="float")
}

///|
test "generator: simple expressions (#18)" {
  let (reg, _) = generator()
  assert_generated(reg, "hello", [], "hello")
  assert_generated(reg, "\\(iii)", [], "(iii)")
  assert_generated(reg, "\\{iii}", [], "{iii}")
  assert_generated(
    reg,
    "The {int}\\/{int}\\/{int} hey",
    [("int", 1), ("int", 2), ("int", 3)],
    "The 1814/05/17 hey",
  )
  assert_generated(
    reg,
    "I have {int} cukes and {float} euro",
    [("int", 1), ("float", 1)],
    "I have 2 cukes and 1.5 euro",
  )
  assert_generated(
    reg,
    "I like {string} and {string}",
    [("string", 1), ("string", 2)],
    "I like \"bangers\" and 'mash'",
  )
  assert_generated(reg, "I am {int}%% foobar", [("int", 1)], "I am 20%% foobar")
  assert_generated(reg, "{int}", [("int", 1)], "99999")
  assert_generated(
    reg,
    "I have {float} cukes and {float} euro",
    [("float", 1), ("float", 2)],
    "I have 2.5 cukes and 1.5 euro",
  )
}

///|
test "generator: custom type (#18)" {
  let (reg, _) = generator()
  reg.register("currency", Custom("currency"), [RegexPattern("[A-Z]{3}")])
  assert_generated(
    reg,
    "I have a {currency} account",
    [("currency", 1)],
    "I have a EUR account",
  )
}

///|
test "generator: prefers leftmost match when there is overlap (#18)" {
  let (reg, _) = generator()
  reg.register("currency", Custom("currency"), [RegexPattern("c d")])
  reg.register("date", Custom("date"), [RegexPattern("b c")])
  assert_generated(reg, "a {date} d e f g", [("date", 1)], "a b c d e f g")
}

///|
test "generator: all combinations when several parameter types match (#18)" {
  let (reg, gen) = generator()
  reg.register("currency", Custom("currency"), [RegexPattern("x")])
  reg.register("date", Custom("date"), [RegexPattern("x")])
  let sources = gen
    .generate_expressions("I have x and x and another x")
    .map(e => e.source())
  inspect(
    sources.join("\n"),
    content=(
      #|I have {currency} and {currency} and another {currency}
      #|I have {currency} and {currency} and another {date}
      #|I have {currency} and {date} and another {currency}
      #|I have {currency} and {date} and another {date}
      #|I have {date} and {currency} and another {currency}
      #|I have {date} and {currency} and another {date}
      #|I have {date} and {date} and another {currency}
      #|I have {date} and {date} and another {date}
    ),
  )
}

///|
test "generator: exposes parameter type names (#18)" {
  let (_, gen) = generator()
  let generated = gen.generate_expressions("I have 2 cukes and 1.5 euro")[0]
  debug_inspect(
    generated.parameter_types.map(t => t.name),
    content="[\"int\", \"float\"]",
  )
}

///|
test "generator: parameter types with optional capture groups (#18)" {
  let (reg, gen) = generator()
  reg.register("optional-flight", Custom("f"), [RegexPattern("(1st flight)?")])
  reg.register("optional-hotel", Custom("h"), [RegexPattern("(1 hotel)?")])
  let generated = gen.generate_expressions(
      "I reach Stage 4: 1st flight -1 hotel",
    )[0]
  inspect(
    generated.source(),
    content="I reach Stage {int}: {optional-flight} {int} hotel",
  )
}

///|
test "generator: at most 256 expressions (#18)" {
  let (reg, gen) = generator()
  for i in 0..<4 {
    reg.register("my-type-\{i}", Custom("t"), [RegexPattern("([a-z] )*?[a-z]")])
  }
  inspect(
    gen.generate_expressions("a s i m p l e s t e p").length(),
    content="256",
  )
}

///|
test "generator: prefers expression with longest non empty match (#18)" {
  let (reg, gen) = generator()
  reg.register("zero-or-more", Custom("z"), [RegexPattern("[a-z]*")])
  reg.register("exactly-one", Custom("e"), [RegexPattern("[a-z]")])
  let sources = gen.generate_expressions("a simple step").map(e => e.source())
  debug_inspect(
    sources,
    content=(
      #|[
      #|  "{exactly-one} {zero-or-more} {zero-or-more}",
      #|  "{zero-or-more} {zero-or-more} {zero-or-more}",
      #|]
    ),
  )
}

///|
test "generator: suggests a parameter only for a full word (#18)" {
  let (reg, gen) = generator()
  reg.register("direction", Custom("d"), [RegexPattern("(up|down)")])
  let first = (text : String) => gen.generate_expressions(text)[0].source()
  inspect(first("I download a picture"), content="I download a picture")
  inspect(first("I watch the muppet show"), content="I watch the muppet show")
  inspect(first("I create a group"), content="I create a group")
  inspect(
    first("When I go down the road"),
    content="When I go {direction} the road",
  )
  inspect(
    first("When I walk up the hill"),
    content="When I walk {direction} the hill",
  )
  inspect(
    first("up the hill, the road goes down"),
    content="{direction} the hill, the road goes {direction}",
  )
  inspect(first("direction is:down"), content="direction is:{direction}")
  inspect(first("direction is down."), content="direction is {direction}.")
}

///|
test "generator: does not use types with use_for_snippets false (#15, #18)" {
  let (reg, gen) = generator()
  reg.register(
    "direction",
    Custom("d"),
    [RegexPattern("(up|down)")],
    use_for_snippets=false,
  )
  inspect(
    gen.generate_expressions("When I go down the road")[0].source(),
    content="When I go down the road",
  )
}
