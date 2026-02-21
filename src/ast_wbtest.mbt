///|
test "TextNode construction and Show" {
  let node = TextNode("hello")
  inspect(node, content="TextNode(\"hello\")")
}

///|
test "ParameterNode construction and Show" {
  let node = ParameterNode("int")
  inspect(node, content="ParameterNode(\"int\")")
}

///|
test "OptionalNode construction and Show" {
  let node = OptionalNode([TextNode("blind")])
  inspect(node, content="OptionalNode([TextNode(\"blind\")])")
}

///|
test "AlternationNode construction and Show" {
  let node = AlternationNode([[TextNode("cat")], [TextNode("dog")]])
  inspect(
    node,
    content="AlternationNode([[TextNode(\"cat\")], [TextNode(\"dog\")]])",
  )
}

///|
test "ExpressionNode construction and Show" {
  let node = ExpressionNode(
    [TextNode("I have "), ParameterNode("int"), TextNode(" cukes")],
  )
  inspect(
    node,
    content="ExpressionNode([TextNode(\"I have \"), ParameterNode(\"int\"), TextNode(\" cukes\")])",
  )
}

///|
test "Node equality" {
  let a = TextNode("hello")
  let b = TextNode("hello")
  let c = TextNode("world")
  inspect(a == b, content="true")
  inspect(a == c, content="false")
}
