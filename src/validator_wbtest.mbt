// Validator tests

///|
test "validate: nested optionals rejected" {
  let mut caught = false
  // "((very) blind)" — outer optional contains inner optional
  try parse_expression("((very) blind)") |> ignore catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "validate: alternation of only optionals rejected" {
  let mut caught = false
  // "(a)/(b)" — each arm has only optionals, no text
  try parse_expression("(a)/(b)") |> ignore catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "validate: empty optional rejected" {
  // Construct OptionalNode([]) directly and validate
  let mut caught = false
  validate(ExpressionNode([OptionalNode([])])) catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "validate: parameter inside optional rejected" {
  let mut caught = false
  validate(ExpressionNode([OptionalNode([ParameterNode("int")])])) catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "validate: valid expression passes" {
  // "I have {int} cucumber(s)" — should not error
  // parse_expression now calls validate internally
  parse_expression("I have {int} cucumber(s)") |> ignore
}

///|
test "validate: simple alternation passes" {
  // "cat/dog" — valid alternation
  parse_expression("cat/dog") |> ignore
}

///|
test "validate: alternation with optional passes" {
  // "a/b(c)" — arm has text + optional, not only optional
  parse_expression("a/b(c)") |> ignore
}
