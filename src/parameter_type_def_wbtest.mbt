///|
priv struct Colour {
  name : String
} derive(Debug)

///|
impl ParameterTypeDef for Colour with fn name() {
  "colour"
}

///|
impl ParameterTypeDef for Colour with fn regexps() {
  [RegexPattern("red|green|blue")]
}

///|
impl FromGroups1 for Colour with fn from_groups(name) {
  { name, }
}

///|
priv struct Point {
  x : Int
  y : Int
} derive(Debug)

///|
impl ParameterTypeDef for Point with fn name() {
  "point"
}

///|
impl ParameterTypeDef for Point with fn regexps() {
  [RegexPattern("\\((\\d+),(\\d+)\\)")]
}

///|
impl ParameterTypeDef for Point with fn use_for_snippets() {
  false
}

///|
impl FromGroups2 for Point with fn from_groups(x, y) {
  { x: @string.parse_int(x), y: @string.parse_int(y), }
}

///|
test "define_type1: registers the type from its trait" {
  let reg = ParamTypeRegistry::default()
  let colour : ParameterType[Colour] = reg.define_type1()
  inspect(colour.name(), content="colour")
  let expr = Expression::parse_with_registry("a {colour} car", reg)
  guard expr.match_("a green car") is Some(m) else { fail("expected a match") }
  debug_inspect(m.get(colour), content="{ name: \"green\" }")
  guard reg.get("colour") is Some(entry) else { fail("expected an entry") }
  inspect(entry.use_for_snippets, content="true")
  inspect(entry.prefer_for_regexp_match, content="false")
}

///|
test "define_type2: two groups and an overridden default" {
  let reg = ParamTypeRegistry::default()
  let point : ParameterType[Point] = reg.define_type2()
  let expr = Expression::parse_with_registry("go to {point}", reg)
  guard expr.match_("go to (3,4)") is Some(m) else { fail("expected a match") }
  debug_inspect(m.get(point), content="{ x: 3, y: 4 }")
  guard reg.get("point") is Some(entry) else { fail("expected an entry") }
  inspect(entry.use_for_snippets, content="false")
}

///|
/// A type whose regexp has 2 groups but whose trait takes 1.
priv enum Pair {
  Pair
}

///|
impl ParameterTypeDef for Pair with fn name() {
  "pair"
}

///|
impl ParameterTypeDef for Pair with fn regexps() {
  [RegexPattern("(a)(b)")]
}

///|
impl FromGroups1 for Pair with fn from_groups(_) {
  Pair
}

///|
test "define_type1: the arity check applies" {
  let reg = ParamTypeRegistry::default()
  let message = try (reg.define_type1() : ParameterType[Pair]) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="The parameter type {pair} decodes 1 capture group, but its regexps have 2 capture groups",
  )
}
