///|
/// Validate a parsed cucumber expression AST.
/// Raises ValidationError for invalid expression structures.
pub fn validate(node : Node) -> Unit!ExpressionError {
  validate_node!(node, inside_optional=false)
}

///|
/// Recursively validate a node. `inside_optional` tracks whether we are
/// currently inside an OptionalNode (to detect nested optionals and
/// parameters inside optionals).
fn validate_node(
  node : Node,
  inside_optional~ : Bool
) -> Unit!ExpressionError {
  match node {
    ExpressionNode(children) =>
      for child in children {
        validate_node!(child, inside_optional~)
      }
    OptionalNode(children) => {
      if inside_optional {
        raise ExpressionError::ValidationError(
          position=0,
          message="An optional may not contain another optional",
        )
      }
      if children.length() == 0 {
        raise ExpressionError::ValidationError(
          position=0,
          message="An optional must contain at least one node",
        )
      }
      for child in children {
        validate_node!(child, inside_optional=true)
      }
    }
    ParameterNode(_) =>
      if inside_optional {
        raise ExpressionError::ValidationError(
          position=0,
          message="An optional may not contain a parameter",
        )
      }
    AlternationNode(alternatives) => {
      for arm in alternatives {
        // Each arm must have at least one TextNode
        let mut has_text = false
        for child in arm {
          match child {
            TextNode(_) => has_text = true
            _ => ()
          }
        }
        if not(has_text) {
          raise ExpressionError::ValidationError(
            position=0,
            message="Each alternation arm must contain at least one text node",
          )
        }
        // Recursively validate children of each arm
        for child in arm {
          validate_node!(child, inside_optional~)
        }
      }
    }
    TextNode(_) => ()
  }
}
