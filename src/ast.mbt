///|
/// A single node in a cucumber expression AST.
pub(all) enum Node {
  /// Literal text.
  TextNode(String)
  /// A parameter reference like `{int}` or `{string}`.
  ParameterNode(String)
  /// Optional text like `(blind)`. Contains child nodes.
  OptionalNode(Array[Node])
  /// Alternation like `cat/dog`. Each alternative is an array of nodes.
  AlternationNode(Array[Array[Node]])
  /// Top-level expression node containing all children.
  ExpressionNode(Array[Node])
} derive(Show, Eq, ToJson, FromJson)
