///|
/// The kind of a node in a cucumber expression AST.
pub(all) enum NodeType {
  /// Literal text. The text is in `Node::token`.
  TextNode
  /// Optional text like `(s)`.
  OptionalNode
  /// Alternation like `cat/dog`. Its children are `AlternativeNode`s.
  AlternationNode
  /// One alternative of an alternation.
  AlternativeNode
  /// A parameter like `{int}`. Its children are the text of the name.
  ParameterNode
  /// The root node of an expression.
  ExpressionNode
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A node in a cucumber expression AST.
///
/// `start` and `end` are code point offsets into the expression. A
/// `TextNode` has a `token` and no `nodes`. All other nodes have `nodes`
/// and an empty `token`.
pub(all) struct Node {
  type_ : NodeType
  nodes : Array[Node]
  token : String
  start : Int
  end : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
/// The text of this node: the token of a text node, or the joined text of
/// the child nodes.
pub fn Node::text(self : Node) -> String {
  if self.nodes.is_empty() {
    return self.token
  }
  let buf = StringBuilder()
  for node in self.nodes {
    buf.write_string(node.text())
  }
  buf.to_string()
}

///|
pub extend NodeType with ToJson::{to_json}

///|
pub extend NodeType with @json.FromJson::{from_json}

///|
#deprecated
pub extend NodeType with Eq::{not_equal, equal}

///|
#deprecated
pub extend NodeType with @debug.Debug::{to_repr}

///|
pub extend Node with ToJson::{to_json}

///|
pub extend Node with @json.FromJson::{from_json}

///|
#deprecated
pub extend Node with Eq::{not_equal, equal}

///|
#deprecated
pub extend Node with @debug.Debug::{to_repr}
