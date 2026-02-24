///|
test "custom param: register and match color" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), [
    RegexPattern("red|blue|green"),
  ])
  let expr = Expression::parse_with_registry("I select {color}", reg)
  let result = expr.match_("I select blue")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params.length(), content="1")
  inspect(m.params[0].raw, content="blue")
  inspect(
    m.params[0].type_,
    content=(
      #|Custom("color")
    ),
  )
}

///|
test "custom param: register and match direction" {
  let reg = ParamTypeRegistry::default()
  reg.register("direction", ParamType::Custom("direction"), [
    RegexPattern("north|south|east|west"),
  ])
  let expr = Expression::parse_with_registry("go {direction}", reg)
  let result = expr.match_("go north")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params.length(), content="1")
  inspect(m.params[0].raw, content="north")
  inspect(
    m.params[0].type_,
    content=(
      #|Custom("direction")
    ),
  )
}

///|
test "custom param: unknown type without custom registry" {
  let result : Result[Expression, Error] = Ok(
    Expression::parse("I select {color}"),
  ) catch {
    e => Err(e)
  }
  guard result is Err(e) else { fail("expected error for unknown type") }
  inspect(e.to_string().contains("Unknown parameter type"), content="true")
}

///|
test "custom param: mixed built-in and custom" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), [
    RegexPattern("red|blue|green"),
  ])
  let expr = Expression::parse_with_registry(
    "I have {int} {color} cucumbers", reg,
  )
  let result = expr.match_("I have 5 red cucumbers")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params.length(), content="2")
  inspect(m.params[0].raw, content="5")
  inspect(m.params[0].type_, content="Int")
  inspect(m.params[1].raw, content="red")
  inspect(
    m.params[1].type_,
    content=(
      #|Custom("color")
    ),
  )
}

///|
test "custom param: no match with custom type" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), [
    RegexPattern("red|blue|green"),
  ])
  let expr = Expression::parse_with_registry("I select {color}", reg)
  let result = expr.match_("I select purple")
  inspect(result, content="None")
}

///|
test "Custom type with transformer returns CustomVal with typed Any" {
  let reg = ParamTypeRegistry::default()
  reg.register(
    "color",
    ParamType::Custom("color"),
    [RegexPattern("red|green|blue")],
    transformer=Transformer::new(
      fn(groups) raise {
        CustomVal(@any.of(groups[0][:].to_upper().to_string()))
      },
    ),
  )
  let expr = Expression::parse_with_registry("I select {color}", reg)
  let result = expr.match_("I select red")
  guard result is Some(m) else { fail("expected match") }
  match m.params[0].value {
    CustomVal(any) => {
      let s : String = any.to()
      assert_eq(s, "RED")
    }
    _ => fail("expected CustomVal")
  }
  assert_eq(m.params[0].raw, "red")
}

///|
test "Custom type without transformer defaults to CustomVal with raw string" {
  let reg = ParamTypeRegistry::default()
  reg.register("direction", ParamType::Custom("direction"), [
    RegexPattern("north|south|east|west"),
  ])
  let expr = Expression::parse_with_registry("go {direction}", reg)
  let result = expr.match_("go north")
  guard result is Some(m) else { fail("expected match") }
  match m.params[0].value {
    CustomVal(any) => {
      let s : String = any.to()
      assert_eq(s, "north")
    }
    _ => fail("expected CustomVal")
  }
  assert_eq(m.params[0].raw, "north")
}
