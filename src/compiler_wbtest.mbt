///|
test "compile: empty" {
  let result = compile_expression("")
  inspect(result, content="^$")
}

///|
test "compile: text" {
  let result = compile_expression("a")
  inspect(result, content="^a$")
}

///|
test "compile: optional" {
  let result = compile_expression("(a)")
  inspect(result, content="^(?:a)?$")
}

///|
test "compile: alternation" {
  let result = compile_expression("a/b c/d/e")
  inspect(result, content="^(?:a|b) (?:c|d|e)$")
}

///|
test "compile: alternation with optional" {
  let result = compile_expression("a/b(c)")
  inspect(result, content="^(?:a|b(?:c)?)$")
}

///|
test "compile: parameter int" {
  let result = compile_expression("{int}")
  inspect(result, content="^((?:(?:-?\\d+))|(?:(?:\\d+)))$")
}

///|
test "compile: parameter word" {
  let result = compile_expression("{word}")
  inspect(result, content="^((?:[^\\s]+))$")
}

///|
test "compile: parameter string" {
  let result = compile_expression("{string}")
  inspect(
    result,
    content=(
      #|^((?:"([^"\\]*(\\.[^"\\]*)*)")|(?:'([^'\\]*(\\.[^'\\]*)*)'))$
    ),
  )
}

///|
test "compile: parameter anonymous" {
  let result = compile_expression("{}")
  inspect(result, content="^((?:.*))$")
}

///|
test "compile: unicode" {
  let result = compile_expression("Привет, Мир(ы)!")
  inspect(result, content="^Привет, Мир(?:ы)?!$")
}

///|
test "compile: escape regex metacharacters in text" {
  let result = compile_expression("amount is $5.00")
  inspect(result, content="^amount is \\$5\\.00$")
}

///|
test "compile: unknown parameter" {
  let mut caught = false
  try compile_expression("I have {unknown}") |> ignore catch {
    ExpressionError::UnknownParameterType(name="unknown", ..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "compile: multiple parameters" {
  let result = compile_expression("from {string} to {string}")
  inspect(
    result,
    content=(
      #|^from ((?:"([^"\\]*(\\.[^"\\]*)*)")|(?:'([^'\\]*(\\.[^'\\]*)*)')) to ((?:"([^"\\]*(\\.[^"\\]*)*)")|(?:'([^'\\]*(\\.[^'\\]*)*)'))$
    ),
  )
}
