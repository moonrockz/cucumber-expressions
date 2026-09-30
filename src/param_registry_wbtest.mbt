// Tests for parameter types, transformers and the registry that the
// reference testdata does not cover.

///|
fn values_transformer() -> Transformer {
  Transformer::new(fn(groups) { StringVal(groups.join("|")) })
}

///|
fn first_value(expr : Expression, text : String) -> ParamValue raise {
  guard expr.match_(text) is Some(m) else { fail("expected a match") }
  m.params[0].value
}

///|
test "group count: a paren in a character class is not a group (#8)" {
  let reg = ParamTypeRegistry::default()
  reg.register("paren", Custom("paren"), [RegexPattern("[(]x")])
  let expr = Expression::parse_with_registry("{paren} {int}", reg)
  guard expr.match_("(x 9") is Some(m) else { fail("expected a match") }
  debug_inspect(m.params[1].value, content="IntVal(9)")
}

///|
test "group count: a named group is a capture group (#8)" {
  let reg = ParamTypeRegistry::default()
  reg.register("named", Custom("named"), [RegexPattern("(?<a>x)y")])
  let expr = Expression::parse_with_registry("{named} {int}", reg)
  guard expr.match_("xy 9") is Some(m) else { fail("expected a match") }
  debug_inspect(m.params[1].value, content="IntVal(9)")
}

///|
test "group count: a non-capturing group is not a capture group (#8)" {
  let reg = ParamTypeRegistry::default()
  reg.register("plain", Custom("plain"), [RegexPattern("(?:x)y")])
  let expr = Expression::parse_with_registry("{plain} {int}", reg)
  guard expr.match_("xy 9") is Some(m) else { fail("expected a match") }
  debug_inspect(m.params[1].value, content="IntVal(9)")
}

///|
test "transformer gets the capture groups of the parameter (#9)" {
  let reg = ParamTypeRegistry::default()
  reg.register(
    "coord",
    Custom("coord"),
    [RegexPattern("(\\d+),(\\d+)")],
    transformer=values_transformer(),
  )
  let expr = Expression::parse_with_registry("at {coord}", reg)
  debug_inspect(first_value(expr, "at 3,4"), content="StringVal(\"3|4\")")
}

///|
test "transformer gets the whole match when there are no capture groups (#9)" {
  let reg = ParamTypeRegistry::default()
  reg.register(
    "pair",
    Custom("pair"),
    [RegexPattern("\\d+,\\d+")],
    transformer=values_transformer(),
  )
  let expr = Expression::parse_with_registry("at {pair}", reg)
  debug_inspect(first_value(expr, "at 3,4"), content="StringVal(\"3,4\")")
}

///|
test "transformer gets an empty string for a group that did not match (#9)" {
  let reg = ParamTypeRegistry::default()
  reg.register(
    "either",
    Custom("either"),
    [RegexPattern("([A-Z]+)"), RegexPattern("(\\d+)")],
    transformer=values_transformer(),
  )
  let expr = Expression::parse_with_registry("{either}", reg)
  debug_inspect(first_value(expr, "TLA"), content="StringVal(\"TLA|\")")
  debug_inspect(first_value(expr, "123"), content="StringVal(\"|123\")")
}

///|
test "transformer error goes to the caller (#10)" {
  let expr = Expression::parse("{int}")
  let raised = try expr.match_("2147483648") catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(raised, content="true")
}

///|
test "byte is in the range -128..127 (#11)" {
  let expr = Expression::parse("{byte}")
  debug_inspect(first_value(expr, "127"), content="ByteVal(0x7f)")
  debug_inspect(first_value(expr, "-128"), content="ByteVal(0x80)")
  let raised = try expr.match_("128") catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(raised, content="true")
  let raised = try expr.match_("-129") catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(raised, content="true")
}

///|
test "short is in the range -32768..32767 (#11)" {
  let expr = Expression::parse("{short}")
  debug_inspect(first_value(expr, "-32768"), content="ShortVal(-32768)")
  let raised = try expr.match_("32768") catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(raised, content="true")
}

///|
test "register raises for a name that is already registered (#12)" {
  let reg = ParamTypeRegistry::default()
  let err = try
    reg.register("int", Custom("int"), [RegexPattern("\\d+")])
  catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  inspect(err, content="There is already a parameter type with name int")
}

///|
test "register raises for a second anonymous parameter type (#12)" {
  let reg = ParamTypeRegistry::default()
  let err = try reg.register("", Anonymous, [RegexPattern(".*")]) catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  inspect(err, content="The anonymous parameter type has already been defined")
}

///|
test "register raises for an illegal name (#13)" {
  let reg = ParamTypeRegistry::new()
  for name in ["a{b", "a}b", "a(b", "a)b", "a\\b", "a/b"] {
    let err = try reg.register(name, Custom(name), [RegexPattern("x")]) catch {
      e => e
    } noraise {
      _ => fail("expected an error for \{name}")
    }
    inspect(
      err.to_string().has_prefix("Illegal character in parameter name {"),
      content="true",
    )
  }
  inspect(
    try reg.register("a{b", Custom("x"), [RegexPattern("x")]) catch {
      e => e.to_string()
    } noraise {
      _ => ""
    },
    content=(
      #|Illegal character in parameter name {a{b}. Parameter names may not contain '{', '}', '(', ')', '\' or '/'
    ),
  )
}

///|
test "register accepts regex characters in a name (#13)" {
  let reg = ParamTypeRegistry::new()
  reg.register("a.b", Custom("x"), [RegexPattern("x")])
  reg.register("c$d", Custom("y"), [RegexPattern("y")])
  inspect(reg.get("a.b") is Some(_), content="true")
}

///|
test "register raises when there are no regexps (#14)" {
  let reg = ParamTypeRegistry::new()
  let err = try reg.register("empty", Custom("e"), []) catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    err,
    content="The parameter type {empty} must have at least one regexp",
  )
}

///|
test "param has the group with its position (#19)" {
  let expr = Expression::parse("I have {int} cukes in {word}")
  guard expr.match_("I have 42 cukes in belly") is Some(m) else {
    fail("expected a match")
  }
  let g = m.params[0].group
  debug_inspect(
    (g.value, g.start, g.end),
    content="(Some(\"42\"), Some(7), Some(9))",
  )
  let g = m.params[1].group
  debug_inspect(
    (g.value, g.start, g.end),
    content="(Some(\"belly\"), Some(19), Some(24))",
  )
}

///|
test "param group has child groups (#19)" {
  let expr = Expression::parse("{string}")
  guard expr.match_("\"a\"") is Some(m) else { fail("expected a match") }
  let g = m.params[0].group
  debug_inspect(g.value, content="Some(\"\\\"a\\\"\")")
  inspect(g.children.length(), content="2")
  debug_inspect(g.children[0].value, content="Some(\"a\")")
  debug_inspect(g.children[1].value, content="None")
}

///|
test "expression gives the compiled regexp (#19)" {
  let expr = Expression::parse("I have {int} cuke(s)")
  inspect(
    expr.regexp(),
    content=(
      #|^I have ((?:-?\d+)|(?:\d+)) cuke(?:s)?$
    ),
  )
}

///|
test "raw keeps the text of a String_ type that has no quotes" {
  let reg = ParamTypeRegistry::new()
  reg.register("text", String_, [RegexPattern("\\w+")])
  let expr = Expression::parse_with_registry("{text}", reg)
  guard expr.match_("hello") is Some(m) else { fail("expected a match") }
  inspect(m.params[0].raw, content="hello")
}

///|
test "raw removes the quotes of a quoted string" {
  let expr = Expression::parse("{string}")
  guard expr.match_("'a b'") is Some(m) else { fail("expected a match") }
  inspect(m.params[0].raw, content="a b")
}

///|
test "group builder gives None for unbalanced parentheses" {
  inspect(create_group_builder("a)") is None, content="true")
  inspect(create_group_builder("(a") is None, content="true")
  inspect(create_group_builder("[)](a)") is Some(_), content="true")
}

///|
test "group builder does not panic when the match has fewer groups" {
  guard create_group_builder("(a)(b)") is Some(builder) else {
    fail("expected a builder")
  }
  let group = builder.build([Some("ab"[:]), Some("a"[:])], { val: 0, })
  debug_inspect(group.children[1].value, content="None")
}

///|
test "range error message has no source location (#11)" {
  let expr = Expression::parse("{byte}")
  let message = try expr.match_("128") catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content=(
      #|Failure(128 is out of range for {byte}: -128..127)
    ),
  )
}
