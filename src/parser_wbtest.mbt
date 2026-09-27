// Basic cases

///|
test "parse: simple text" {
  let ast = parse_expression("three blind mice")
  debug_inspect(
    ast,
    content=(
      #|ExpressionNode([TextNode("three blind mice")])
    ),
  )
}

///|
test "parse: parameter" {
  let ast = parse_expression("{string}")
  debug_inspect(ast, content="ExpressionNode([ParameterNode(\"string\")])")
}

///|
test "parse: optional" {
  let ast = parse_expression("(blind)")
  debug_inspect(
    ast,
    content="ExpressionNode([OptionalNode([TextNode(\"blind\")])])",
  )
}

///|
test "parse: empty expression" {
  let ast = parse_expression("")
  debug_inspect(ast, content="ExpressionNode([])")
}

///|
test "parse: anonymous parameter" {
  let ast = parse_expression("{}")
  debug_inspect(ast, content="ExpressionNode([ParameterNode(\"\")])")
}

// Alternation

///|
test "parse: alternation" {
  let ast = parse_expression("mice/rats")
  debug_inspect(
    ast,
    content="ExpressionNode([AlternationNode([[TextNode(\"mice\")], [TextNode(\"rats\")]])])",
  )
}

///|
test "parse: alternation in phrase" {
  let ast = parse_expression("three hungry/blind mice")
  debug_inspect(
    ast,
    content=(
      #|ExpressionNode(
      #|  [
      #|    TextNode("three "),
      #|    AlternationNode([[TextNode("hungry")], [TextNode("blind")]]),
      #|    TextNode(" mice"),
      #|  ],
      #|)
    ),
  )
}

// Combined

///|
test "parse: optional in phrase" {
  let ast = parse_expression("three (blind) mice")
  debug_inspect(
    ast,
    content=(
      #|ExpressionNode(
      #|  [
      #|    TextNode("three "),
      #|    OptionalNode([TextNode("blind")]),
      #|    TextNode(" mice"),
      #|  ],
      #|)
    ),
  )
}

///|
test "parse: parameter with optional" {
  let ast = parse_expression("I have {int} cucumber(s)")
  debug_inspect(
    ast,
    content=(
      #|ExpressionNode(
      #|  [
      #|    TextNode("I have "),
      #|    ParameterNode("int"),
      #|    TextNode(" cucumber"),
      #|    OptionalNode([TextNode("s")]),
      #|  ],
      #|)
    ),
  )
}

///|
test "parse: alternation with optional" {
  let ast = parse_expression("a/b(c)")
  debug_inspect(
    ast,
    content="ExpressionNode([AlternationNode([[TextNode(\"a\")], [TextNode(\"b\"), OptionalNode([TextNode(\"c\")])]])])",
  )
}

// Errors

///|
test "parse: unmatched brace" {
  let mut caught = false
  try parse_expression("{int") |> ignore catch {
    ExpressionError::UnmatchedBrace(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "parse: unmatched paren" {
  let mut caught = false
  try parse_expression("(blind") |> ignore catch {
    ExpressionError::UnmatchedParen(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

// Multi-way alternation

///|
test "parse: multi-way alternation" {
  let ast = parse_expression("a/b/c")
  debug_inspect(
    ast,
    content="ExpressionNode([AlternationNode([[TextNode(\"a\")], [TextNode(\"b\")], [TextNode(\"c\")]])])",
  )
}

// Trailing slash — now rejected by validator (empty arm has no text)

///|
test "parse: trailing slash rejected" {
  let mut caught = false
  try parse_expression("cats/") |> ignore catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

// Leading slash — now rejected by validator (empty arm has no text)

///|
test "parse: leading slash rejected" {
  let mut caught = false
  try parse_expression("/cats") |> ignore catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

// Parameter as alternation boundary

///|
test "parse: parameter as left boundary for alternation" {
  let ast = parse_expression("{int}st/nd/rd/th")
  debug_inspect(
    ast,
    content=(
      #|ExpressionNode(
      #|  [
      #|    ParameterNode("int"),
      #|    AlternationNode(
      #|      [
      #|        [TextNode("st")],
      #|        [TextNode("nd")],
      #|        [TextNode("rd")],
      #|        [TextNode("th")],
      #|      ],
      #|    ),
      #|  ],
      #|)
    ),
  )
}
