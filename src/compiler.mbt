///|
/// Escape regex metacharacters in a string.
fn escape_regex(s : String) -> String {
  let buf = StringBuilder::new()
  for ch in s {
    if "^$[]()\\{}.|?*+".contains(ch.to_string()) {
      buf.write_char('\\')
    }
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
/// Compile a cucumber expression AST to a regex pattern string.
pub fn compile(
  node : Node,
  registry : ParamTypeRegistry,
) -> String raise ExpressionError {
  match node {
    ExpressionNode(children) => {
      let buf = StringBuilder::new()
      buf.write_char('^')
      for child in children {
        buf.write_string(compile(child, registry))
      }
      buf.write_char('$')
      buf.to_string()
    }
    TextNode(text) => escape_regex(text)
    ParameterNode(name) =>
      match registry.get(name) {
        Some(entry) => {
          let buf = StringBuilder::new()
          buf.write_char('(')
          for i, pat in entry.patterns {
            if i > 0 {
              buf.write_char('|')
            }
            buf.write_string("(?:")
            buf.write_string(pat.to_string())
            buf.write_char(')')
          }
          buf.write_char(')')
          buf.to_string()
        }
        None =>
          raise ExpressionError::UnknownParameterType(
            name~,
            message="Unknown parameter type: {" + name + "}",
          )
      }
    OptionalNode(children) => {
      let buf = StringBuilder::new()
      buf.write_string("(?:")
      for child in children {
        buf.write_string(compile(child, registry))
      }
      buf.write_string(")?")
      buf.to_string()
    }
    AlternationNode(alternatives) => {
      let buf = StringBuilder::new()
      buf.write_string("(?:")
      for i, arm in alternatives {
        if i > 0 {
          buf.write_char('|')
        }
        for node in arm {
          buf.write_string(compile(node, registry))
        }
      }
      buf.write_char(')')
      buf.to_string()
    }
  }
}

///|
/// Parse a cucumber expression and compile it to a regex pattern string.
pub fn compile_expression(
  expression : String,
  registry? : ParamTypeRegistry = ParamTypeRegistry::default(),
) -> String raise ExpressionError {
  let ast = parse_expression(expression)
  compile(ast, registry)
}
