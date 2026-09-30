///|
test "captures: each part decodes one group" {
  inspect(Captures::string().run("t", [Some("x")]), content="x")
  inspect(Captures::int().run("t", [Some("-3")]), content="-3")
  inspect(
    Captures::long().run("t", [Some("9007199254740993")]),
    content="9007199254740993",
  )
  inspect(Captures::float().run("t", [Some("1.5")]), content="1.5")
  inspect(Captures::double().run("t", [Some("2.5")]), content="2.5")
  inspect(
    Captures::custom(s => s.length()).run("t", [Some("abc")]),
    content="3",
  )
}

///|
test "captures: map changes the value" {
  let doubled = Captures::int().map(n => n * 2)
  inspect(doubled.count, content="1")
  inspect(doubled.run("t", [Some("21")]), content="42")
}

///|
test "captures: a group that did not match raises with its index" {
  let message = try Captures::int().run("age", [None]) catch {
    e => e.to_string()
  } noraise {
    _ => fail("expected an error")
  }
  inspect(
    message,
    content="Capture group 1 of the parameter type {age} did not match",
  )
}

///|
test "captures: a parse error goes to the caller" {
  let raised = try Captures::int().run("t", [Some("x")]) catch {
    _ => true
  } noraise {
    _ => false
  }
  inspect(raised, content="true")
}

///|
test "captures: optional gives None when the group did not match" {
  let part = Captures::optional(Captures::int())
  debug_inspect(part.run("t", [None]), content="None")
  debug_inspect(part.run("t", [Some("7")]), content="Some(7)")
}
