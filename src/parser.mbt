///|
/// Parse a cucumber expression string into an AST.
pub fn parse_expression(expression : String) -> Node raise ExpressionError {
  let tokens = tokenize(expression)
  let nodes = parse_tokens(tokens)
  let nodes = split_alternations(nodes)
  let nodes = merge_text_nodes(nodes)
  let ast = ExpressionNode(nodes)
  validate(ast)
  ast
}

///|
/// First pass: convert token stream into AST nodes, handling parameters and
/// optionals (which require matching delimiters).
fn parse_tokens(tokens : Array[Token]) -> Array[Node] raise ExpressionError {
  let result : Array[Node] = []
  let len = tokens.length()
  let mut i = 0
  while i < len {
    match tokens[i] {
      BeginParameter => {
        // Collect text inside { ... } into a parameter name
        i = i + 1
        let name = StringBuilder::new()
        let mut found_end = false
        while i < len {
          match tokens[i] {
            EndParameter => {
              found_end = true
              i = i + 1
              break
            }
            Text(s) => {
              name.write_string(s)
              i = i + 1
            }
            WhiteSpace(s) => {
              name.write_string(s)
              i = i + 1
            }
            _ => {
              name.write_string(to_text(tokens[i]))
              i = i + 1
            }
          }
        }
        if not(found_end) {
          raise ExpressionError::UnmatchedBrace(
            position=0,
            message="Missing closing brace '}'",
          )
        }
        result.push(ParameterNode(name.to_string()))
      }
      EndParameter => {
        // Stray end parameter — treat as text
        result.push(TextNode("}"))
        i = i + 1
      }
      BeginOptional => {
        // Collect tokens inside ( ... ) and parse them recursively
        i = i + 1
        let inner_tokens : Array[Token] = []
        let mut depth = 1
        let mut found_end = false
        while i < len {
          match tokens[i] {
            BeginOptional => {
              depth = depth + 1
              inner_tokens.push(tokens[i])
              i = i + 1
            }
            EndOptional => {
              depth = depth - 1
              if depth == 0 {
                found_end = true
                i = i + 1
                break
              }
              inner_tokens.push(tokens[i])
              i = i + 1
            }
            _ => {
              inner_tokens.push(tokens[i])
              i = i + 1
            }
          }
        }
        if not(found_end) {
          raise ExpressionError::UnmatchedParen(
            position=0,
            message="Missing closing parenthesis ')'",
          )
        }
        let children = parse_tokens(inner_tokens)
        result.push(OptionalNode(children))
      }
      EndOptional => {
        // Stray end optional — treat as text
        result.push(TextNode(")"))
        i = i + 1
      }
      Alternation => {
        // Keep alternation as a sentinel node for second pass
        result.push(TextNode("/"))
        // Mark the position — we use a special approach: store as a temporary
        // We need a way to distinguish real text "/" from alternation.
        // Let's use a different strategy: store alternation markers directly.
        // Replace the TextNode we just pushed with nothing, and use a different approach.
        ignore(result.pop())
        result.push(AlternationNode([]))
        i = i + 1
      }
      Text(s) => {
        result.push(TextNode(s))
        i = i + 1
      }
      WhiteSpace(s) => {
        result.push(TextNode(s))
        i = i + 1
      }
    }
  }
  result
}

///|
/// Second pass: detect alternation groups. Alternation markers (empty
/// AlternationNode) separate alternatives. A group of non-whitespace nodes
/// separated by alternation markers is gathered into a single AlternationNode.
fn split_alternations(nodes : Array[Node]) -> Array[Node] {
  let result : Array[Node] = []
  let len = nodes.length()
  let mut i = 0
  while i < len {
    // Check if this position starts an alternation group.
    // An alternation group is a sequence: node+ (AltMarker node+)+
    // bounded by start/end of expression or whitespace TextNodes.
    match nodes[i] {
      AlternationNode([]) => {
        // Sentinel at current position — this IS an alternation marker.
        // Start an alternation group with an empty first arm.
        let alternatives : Array[Array[Node]] = []
        let mut current_arm : Array[Node] = []
        alternatives.push(current_arm) // empty left arm
        current_arm = []
        i = i + 1
        while i < len {
          match nodes[i] {
            AlternationNode([]) => {
              alternatives.push(current_arm)
              current_arm = []
              i = i + 1
            }
            TextNode(s) =>
              if is_whitespace_text(s) {
                break
              } else {
                current_arm.push(nodes[i])
                i = i + 1
              }
            ParameterNode(_) => break
            _ => {
              current_arm.push(nodes[i])
              i = i + 1
            }
          }
        }
        alternatives.push(current_arm)
        result.push(AlternationNode(alternatives))
      }
      _ =>
        if has_alternation_ahead(nodes, i) {
          // Collect the alternation group
          let alternatives : Array[Array[Node]] = []
          let mut current_arm : Array[Node] = []
          while i < len {
            match nodes[i] {
              AlternationNode([]) => {
                // alternation marker
                alternatives.push(current_arm)
                current_arm = []
                i = i + 1
              }
              TextNode(s) =>
                if is_whitespace_text(s) {
                  // Whitespace ends the alternation group
                  break
                } else {
                  current_arm.push(nodes[i])
                  i = i + 1
                }
              ParameterNode(_) =>
                // Parameter node acts as alternation boundary per spec
                // (bounded by `{` / `}`)
                break
              _ => {
                current_arm.push(nodes[i])
                i = i + 1
              }
            }
          }
          alternatives.push(current_arm)
          result.push(AlternationNode(alternatives))
        } else {
          result.push(nodes[i])
          i = i + 1
        }
    }
  }
  result
}

///|
/// Check if from position `start` there is an alternation marker before the
/// next whitespace boundary (or end of array). Only returns true if the node
/// at `start` is NOT whitespace and there IS an alternation marker in the group.
fn has_alternation_ahead(nodes : Array[Node], start : Int) -> Bool {
  // Don't start an alternation group on whitespace, sentinel, or parameter
  match nodes[start] {
    TextNode(s) => if is_whitespace_text(s) { return false }
    AlternationNode([]) => return false
    ParameterNode(_) => return false
    _ => ()
  }
  let len = nodes.length()
  let mut i = start
  while i < len {
    match nodes[i] {
      AlternationNode([]) => return true
      TextNode(s) => if is_whitespace_text(s) { return false }
      ParameterNode(_) => return false
      _ => ()
    }
    i = i + 1
  }
  false
}

///|
/// Check if a text string is purely whitespace.
fn is_whitespace_text(s : String) -> Bool {
  let chars = s.to_array()
  let mut j = 0
  while j < chars.length() {
    let ch = chars[j]
    if ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r' {
      return false
    }
    j = j + 1
  }
  true
}

///|
/// Merge adjacent TextNodes into a single TextNode. Also recurse into
/// OptionalNode children and AlternationNode arms.
fn merge_text_nodes(nodes : Array[Node]) -> Array[Node] {
  let result : Array[Node] = []
  let buf = StringBuilder::new()
  for node in nodes {
    match node {
      TextNode(s) => buf.write_string(s)
      _ => {
        let text = buf.to_string()
        if text.length() > 0 {
          result.push(TextNode(text))
          buf.reset()
        }
        match node {
          OptionalNode(children) =>
            result.push(OptionalNode(merge_text_nodes(children)))
          AlternationNode(alternatives) => {
            let merged_alts : Array[Array[Node]] = []
            for alt in alternatives {
              merged_alts.push(merge_text_nodes(alt))
            }
            result.push(AlternationNode(merged_alts))
          }
          _ => result.push(node)
        }
      }
    }
  }
  let text = buf.to_string()
  if text.length() > 0 {
    result.push(TextNode(text))
  }
  result
}

///|
/// Get a textual representation of a token (for fallback cases).
fn to_text(token : Token) -> String {
  match token {
    Text(s) => s
    WhiteSpace(s) => s
    BeginParameter => "{"
    EndParameter => "}"
    BeginOptional => "("
    EndOptional => ")"
    Alternation => "/"
  }
}
