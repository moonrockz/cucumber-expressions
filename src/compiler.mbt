// A port of CucumberExpression.rewriteToRegex from the reference
// implementation. It also checks the structure of the AST.

///|
/// Escape regex metacharacters in a string.
fn escape_regex(s : String) -> String {
  let buf = StringBuilder()
  for ch in s {
    if "\\^[({$.|?*+})]".contains_char(ch) {
      buf.write_char('\\')
    }
    buf.write_char(ch)
  }
  buf.to_string()
}

///|
/// The result of compiling an AST: the regex and the parameter type of
/// each parameter, in order.
priv struct Compiled {
  regex : String
  parameter_types : Array[ParamTypeEntry]
}

///|
priv struct Compiler {
  expression : String
  registry : ParamTypeRegistry
  parameter_types : Array[ParamTypeEntry]
}

///|
fn compile_ast(
  expression : String,
  ast : Node,
  registry : ParamTypeRegistry,
) -> Compiled raise ExpressionError {
  let compiler = { expression, registry, parameter_types: [], }
  let regex = compiler.rewrite(ast)
  { regex, parameter_types: compiler.parameter_types, }
}

///|
fn Compiler::rewrite(
  self : Compiler,
  node : Node,
) -> String raise ExpressionError {
  match node.type_ {
    TextNode => escape_regex(node.token)
    OptionalNode => self.rewrite_optional(node)
    AlternationNode => self.rewrite_alternation(node)
    AlternativeNode => self.rewrite_all(node.nodes, "")
    ParameterNode => self.rewrite_parameter(node)
    ExpressionNode => "^" + self.rewrite_all(node.nodes, "") + "$"
  }
}

///|
fn Compiler::rewrite_all(
  self : Compiler,
  nodes : Array[Node],
  separator : String,
) -> String raise ExpressionError {
  let buf = StringBuilder()
  for i, node in nodes {
    if i > 0 {
      buf.write_string(separator)
    }
    buf.write_string(self.rewrite(node))
  }
  buf.to_string()
}

///|
fn Compiler::rewrite_optional(
  self : Compiler,
  node : Node,
) -> String raise ExpressionError {
  if node.nodes.search_by(n => n.type_ == ParameterNode) is Some(i) {
    raise node_error(
      self.expression,
      node.nodes[i],
      "An optional may not contain a parameter type",
      "If you did not mean to use an parameter type you can use '\\{' to escape the '{'",
    )
  }
  if node.nodes.search_by(n => n.type_ == OptionalNode) is Some(i) {
    raise node_error(
      self.expression,
      node.nodes[i],
      "An optional may not contain an other optional",
      "If you did not mean to use an optional type you can use '\\(' to escape the '('. For more complicated expressions consider using a regular expression instead.",
    )
  }
  if !has_text(node) {
    raise node_error(
      self.expression,
      node,
      "An optional must contain some text",
      "If you did not mean to use an optional you can use '\\(' to escape the '('",
    )
  }
  "(?:" + self.rewrite_all(node.nodes, "") + ")?"
}

///|
fn Compiler::rewrite_alternation(
  self : Compiler,
  node : Node,
) -> String raise ExpressionError {
  for alternative in node.nodes {
    if alternative.nodes.is_empty() {
      raise node_error(
        self.expression,
        alternative,
        "Alternative may not be empty",
        "If you did not mean to use an alternative you can use '\\/' to escape the '/'",
      )
    }
    if !has_text(alternative) {
      raise node_error(
        self.expression,
        alternative,
        "An alternative may not exclusively contain optionals",
        "If you did not mean to use an optional you can use '\\(' to escape the '('",
      )
    }
  }
  "(?:" + self.rewrite_all(node.nodes, "|") + ")"
}

///|
fn Compiler::rewrite_parameter(
  self : Compiler,
  node : Node,
) -> String raise ExpressionError {
  let name = node.text()
  guard self.registry.get(name) is Some(entry) else {
    raise undefined_parameter_type_error(self.expression, node, name)
  }
  self.parameter_types.push(entry)
  let regexps = entry.patterns.map(p => p.to_string())
  if regexps.length() == 1 {
    "(" + regexps[0] + ")"
  } else {
    "((?:" + regexps.join(")|(?:") + "))"
  }
}

///|
fn has_text(node : Node) -> Bool {
  node.nodes.iter().any(n => n.type_ == TextNode)
}

///|
/// Parse a cucumber expression and compile it to a regex pattern string.
pub fn compile_expression(
  expression : String,
  registry? : ParamTypeRegistry = ParamTypeRegistry::default(),
) -> String raise ExpressionError {
  let ast = parse_expression(expression)
  compile_ast(expression, ast, registry).regex
}
