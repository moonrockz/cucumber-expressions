// Basic cases

test "parse: simple text" {
  let ast = parse_expression!("three blind mice")
  inspect(ast, content=(
    #|ExpressionNode([TextNode("three blind mice")])

  ))
}

test "parse: parameter" {
  let ast = parse_expression!("{string}")
  inspect(ast, content="ExpressionNode([ParameterNode(\"string\")])")
}

test "parse: optional" {
  let ast = parse_expression!("(blind)")
  inspect(ast, content="ExpressionNode([OptionalNode([TextNode(\"blind\")])])")
}

test "parse: empty expression" {
  let ast = parse_expression!("")
  inspect(ast, content="ExpressionNode([])")
}

test "parse: anonymous parameter" {
  let ast = parse_expression!("{}")
  inspect(ast, content="ExpressionNode([ParameterNode(\"\")])")
}

// Alternation

test "parse: alternation" {
  let ast = parse_expression!("mice/rats")
  inspect(
    ast,
    content="ExpressionNode([AlternationNode([[TextNode(\"mice\")], [TextNode(\"rats\")]])])",
  )
}

test "parse: alternation in phrase" {
  let ast = parse_expression!("three hungry/blind mice")
  inspect(
    ast,
    content=(
      #|ExpressionNode([TextNode("three "), AlternationNode([[TextNode("hungry")], [TextNode("blind")]]), TextNode(" mice")])

    ),
  )
}

// Combined

test "parse: optional in phrase" {
  let ast = parse_expression!("three (blind) mice")
  inspect(
    ast,
    content=(
      #|ExpressionNode([TextNode("three "), OptionalNode([TextNode("blind")]), TextNode(" mice")])

    ),
  )
}

test "parse: parameter with optional" {
  let ast = parse_expression!("I have {int} cucumber(s)")
  inspect(
    ast,
    content=(
      #|ExpressionNode([TextNode("I have "), ParameterNode("int"), TextNode(" cucumber"), OptionalNode([TextNode("s")])])

    ),
  )
}

test "parse: alternation with optional" {
  let ast = parse_expression!("a/b(c)")
  inspect(
    ast,
    content="ExpressionNode([AlternationNode([[TextNode(\"a\")], [TextNode(\"b\"), OptionalNode([TextNode(\"c\")])]])])",
  )
}

// Errors

test "parse: unmatched brace" {
  let result : Result[Node, Error] = try {
    Ok(parse_expression!("{int"))
  } catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

test "parse: unmatched paren" {
  let result : Result[Node, Error] = try {
    Ok(parse_expression!("(blind"))
  } catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}
