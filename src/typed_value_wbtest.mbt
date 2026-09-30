///|
priv struct Color {
  name : String
} derive(Debug)

///|
/// Register `name` so that each match gives `handle.wrap(Color)`.
fn register_color(
  reg : ParamTypeRegistry,
  handle : ParameterType[Color],
) -> Unit raise {
  reg.register(
    handle.name(),
    Custom(handle.name()),
    [RegexPattern("red|blue")],
    transformer=Transformer::with_missing(values => {
      handle.wrap({ name: values[0].unwrap_or("?"), })
    }),
  )
}

///|
test "typed value: get reads the value with its type" {
  let reg = ParamTypeRegistry::default()
  let color : ParameterType[Color] = ParameterType::new("color")
  register_color(reg, color)
  let expr = Expression::parse_with_registry("a {color} ball", reg)
  guard expr.match_("a red ball") is Some(m) else { fail("expected a match") }
  debug_inspect(color.get(m.params[0]), content="{ name: \"red\" }")
  inspect(m.params[0].value, content="TypedVal(<color>)")
}

///|
test "typed value: get raises for a parameter of another type" {
  let reg = ParamTypeRegistry::default()
  let color : ParameterType[Color] = ParameterType::new("color")
  register_color(reg, color)
  let expr = Expression::parse_with_registry("{int} {color}", reg)
  guard expr.match_("3 red") is Some(m) else { fail("expected a match") }
  let message = try color.get(m.params[0]) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="Expected a parameter of type {color}, but the parameter has type {int}",
  )
}

///|
test "typed value: a handle does not read a value from another registry" {
  let reg_a = ParamTypeRegistry::default()
  let color_a : ParameterType[Color] = ParameterType::new("color")
  register_color(reg_a, color_a)
  let reg_b = ParamTypeRegistry::default()
  let color_b : ParameterType[Color] = ParameterType::new("color")
  register_color(reg_b, color_b)
  let expr = Expression::parse_with_registry("{color}", reg_b)
  guard expr.match_("blue") is Some(m) else { fail("expected a match") }
  inspect(color_a.try_get(m.params[0]) is None, content="true")
  debug_inspect(color_b.get(m.params[0]), content="{ name: \"blue\" }")
}

///|
test "typed value: Match::get and Match::get_all" {
  let reg = ParamTypeRegistry::default()
  let color : ParameterType[Color] = ParameterType::new("color")
  register_color(reg, color)
  let one = Expression::parse_with_registry("{int} {color}", reg)
  guard one.match_("3 red") is Some(m1) else { fail("expected a match") }
  debug_inspect(m1.get(color), content="{ name: \"red\" }")
  let two = Expression::parse_with_registry("{color} and {color}", reg)
  guard two.match_("red and blue") is Some(m2) else { fail("expected a match") }
  debug_inspect(
    m2.get_all(color),
    content="[{ name: \"red\" }, { name: \"blue\" }]",
  )
  let ambiguous = try m2.get(color) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    ambiguous,
    content="The match has 2 parameters of type {color}; use get_all",
  )
  let none = Expression::parse_with_registry("{int}", reg)
  guard none.match_("3") is Some(m3) else { fail("expected a match") }
  inspect(m3.get_all(color).length(), content="0")
  let missing = try m3.get(color) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(missing, content="The match has no parameter of type {color}")
}

///|
test "typed value: a plain transformer still gets an empty string for a missing group" {
  let expr = RegularExpression::new("^a( b)?$")
  guard expr.match_("a") is Some(m) else { fail("expected a match") }
  debug_inspect(m.params[0].value, content="NullVal")
  let reg = ParamTypeRegistry::default()
  reg.register(
    "either",
    Custom("either"),
    [RegexPattern("(x)"), RegexPattern("(y)")],
    transformer=Transformer::new(groups => StringVal(groups.join("|"))),
  )
  let expr = Expression::parse_with_registry("{either}", reg)
  guard expr.match_("y") is Some(m) else { fail("expected a match") }
  debug_inspect(m.params[0].value, content="StringVal(\"|y\")")
}
