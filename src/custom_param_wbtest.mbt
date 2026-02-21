///|
test "custom param: register and match color" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), ["red|blue|green"])
  let expr = Expression::parse_with_registry!("I select {color}", reg)
  let result = expr.match_("I select blue")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="blue")
  inspect!(m.params[0].type_, content=
    #|Custom("color")
  )
}

///|
test "custom param: register and match direction" {
  let reg = ParamTypeRegistry::default()
  reg.register(
    "direction",
    ParamType::Custom("direction"),
    ["north|south|east|west"],
  )
  let expr = Expression::parse_with_registry!("go {direction}", reg)
  let result = expr.match_("go north")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="north")
  inspect!(m.params[0].type_, content=
    #|Custom("direction")
  )
}

///|
test "custom param: unknown type without custom registry" {
  let result : Result[Expression, Error] = try {
    Ok(Expression::parse!("I select {color}"))
  } catch {
    e => Err(e)
  }
  guard result is Err(e) else { fail!("expected error for unknown type") }
  inspect!(
    e.to_string().contains("Unknown parameter type"),
    content="true",
  )
}

///|
test "custom param: mixed built-in and custom" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), ["red|blue|green"])
  let expr = Expression::parse_with_registry!(
    "I have {int} {color} cucumbers",
    reg,
  )
  let result = expr.match_("I have 5 red cucumbers")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="2")
  inspect!(m.params[0].value, content="5")
  inspect!(m.params[0].type_, content="Int")
  inspect!(m.params[1].value, content="red")
  inspect!(m.params[1].type_, content=
    #|Custom("color")
  )
}

///|
test "custom param: no match with custom type" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), ["red|blue|green"])
  let expr = Expression::parse_with_registry!("I select {color}", reg)
  let result = expr.match_("I select purple")
  inspect!(result, content="None")
}
