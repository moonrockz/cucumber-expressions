///|
priv struct Coord {
  x : Int
  y : Int
} derive(Debug)

///|
fn match_one(
  reg : ParamTypeRegistry,
  expression : String,
  text : String,
) -> Match raise {
  guard Expression::parse_with_registry(expression, reg).match_(text) is Some(m) else {
    fail("expected a match")
  }
  m
}

///|
test "define_with: typed value from a decoder" {
  let reg = ParamTypeRegistry::default()
  let coord = reg.define_with(
    "coord",
    [RegexPattern("(\\d+),(\\d+)")],
    Captures::int().zip(Captures::int()).map((x, y) => Coord::{ x, y, }),
  )
  let m = match_one(reg, "at {coord}", "at 3,4")
  debug_inspect(coord.get(m.params[0]), content="{ x: 3, y: 4 }")
  debug_inspect(m.params[0].type_, content="Custom(\"coord\")")
  inspect(m.params[0].raw, content="3,4")
}

///|
test "define1: no capture group gives the whole match" {
  let reg = ParamTypeRegistry::default()
  let word = reg.define1("shout", [RegexPattern("[a-z]+")], s => s.to_upper())
  let m = match_one(reg, "say {shout}", "say hi")
  inspect(word.get(m.params[0]), content="HI")
}

///|
test "define1: one capture group gives the group" {
  let reg = ParamTypeRegistry::default()
  let amount = reg.define1("amount", [RegexPattern("\\$(\\d+)")], s => {
    @string.parse_int(s)
  })
  let m = match_one(reg, "pay {amount}", "pay $12")
  inspect(amount.get(m.params[0]), content="12")
}

///|
test "define2 to define8: one argument per capture group" {
  let reg = ParamTypeRegistry::default()
  let two = reg.define2("two", [RegexPattern("(a)(b)")], (a, b) => a + b)
  let eight = reg.define8("eight", [RegexPattern("(1)(2)(3)(4)(5)(6)(7)(8)")], (
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
  ) => [a, b, c, d, e, f, g, h].join(""))
  let m = match_one(reg, "{two} {eight}", "ab 12345678")
  inspect(two.get(m.params[0]), content="ab")
  inspect(eight.get(m.params[1]), content="12345678")
}

///|
test "define_with: arity mismatch is raised and nothing is registered" {
  let reg = ParamTypeRegistry::default()
  let message = try
    reg.define3("coord", [RegexPattern("(\\d+),(\\d+)")], (a, b, c) => a + b + c)
  catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="The parameter type {coord} decodes 3 capture groups, but its regexps have 2 capture groups",
  )
  inspect(reg.get("coord") is None, content="true")
}

///|
test "define_with: one value with more than one group is a mismatch" {
  let reg = ParamTypeRegistry::default()
  let raised = try reg.define1("pair", [RegexPattern("(a)(b)")], s => s) catch {
    ArityMismatch(expected=1, groups=2, ..) => true
    _ => false
  } noraise {
    _ => false
  }
  inspect(raised, content="true")
}

///|
test "define_with: the arity message uses the singular for 1" {
  let reg = ParamTypeRegistry::default()
  let message = try
    reg.define2("pair", [RegexPattern("(a)")], (a, b) => a + b)
  catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="The parameter type {pair} decodes 2 capture groups, but its regexps have 1 capture group",
  )
}

///|
test "define_with: groups count only at the top level, not in classes" {
  let reg = ParamTypeRegistry::default()
  let t = reg.define2("nested", [RegexPattern("((x)y)[(]((?:z))")], (a, b) => {
    "\{a}|\{b}"
  })
  let m = match_one(reg, "{nested}", "xy(z")
  inspect(t.get(m.params[0]), content="xy|z")
}

///|
test "define_with: a named group counts" {
  let reg = ParamTypeRegistry::default()
  let t = reg.define2("named", [RegexPattern("(?<a>x)(y)")], (a, b) => a + b)
  let m = match_one(reg, "{named}", "xy")
  inspect(t.get(m.params[0]), content="xy")
}

///|
test "define_with: groups of all regexps count" {
  let reg = ParamTypeRegistry::default()
  let either = reg.define_with(
    "either",
    [RegexPattern("(\\d+)"), RegexPattern("([a-z]+)")],
    Captures::optional(Captures::int())
    .zip(Captures::optional(Captures::string()))
    .map((n, s) => (n, s)),
  )
  let m = match_one(reg, "{either}", "abc")
  debug_inspect(either.get(m.params[0]), content="(None, Some(\"abc\"))")
  let strict = reg.define2(
    "strict",
    [RegexPattern("(\\d+)"), RegexPattern("([A-Z]+)")],
    (a, b) => a + b,
  )
  let message = try
    Expression::parse_with_registry("{strict}", reg).match_("ABC")
  catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="Capture group 1 of the parameter type {strict} did not match",
  )
  ignore(strict)
}

///|
test "define_with: unbalanced parentheses raise InvalidRegexp" {
  let reg = ParamTypeRegistry::default()
  let message = try reg.define1("bad", [RegexPattern("a)")], s => s) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="The regexp /a)/ of the parameter type {bad} has parentheses that do not balance",
  )
}

///|
test "define_with: the checks of register apply" {
  let reg = ParamTypeRegistry::default()
  let duplicate = try reg.define1("int", [RegexPattern("\\d+")], s => s) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(duplicate, content="There is already a parameter type with name int")
  let empty = try reg.define1("empty", [], s => s) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    empty,
    content="The parameter type {empty} must have at least one regexp",
  )
}

///|
test "define_with: a parse error in a part goes to the caller of match_" {
  let reg = ParamTypeRegistry::default()
  let _ = reg.define_with("num", [RegexPattern("\\w+")], Captures::int())
  let raised = try
    Expression::parse_with_registry("{num}", reg).match_("abc")
  catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(raised, content="true")
}

///|
test "define_with: an error from map goes to the caller unchanged" {
  let reg = ParamTypeRegistry::default()
  let _ = reg.define1("picky", [RegexPattern("\\w+")], s => {
    if s == "no" {
      fail("picky says no")
    }
    s
  })
  let message = try
    Expression::parse_with_registry("{picky}", reg).match_("no")
  catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(message.contains("picky says no"), content="true")
}
