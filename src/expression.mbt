///|
/// A parsed and compiled cucumber expression, ready for matching.
pub(all) struct Expression {
  priv source : String
  priv regex : @regexp.Regexp
  priv param_types : Array[ParamType]
  priv transformers : Array[Transformer]
  /// For each parameter, the number of capture groups its regex pattern uses.
  /// This is needed because {string} uses multiple inner capture groups.
  priv group_counts : Array[Int]
}

///|
/// A successful match result with extracted parameters.
pub(all) struct Match {
  params : Array[Param]
} derive(Show, Eq)

///|
/// An extracted parameter value.
pub(all) struct Param {
  value : ParamValue
  type_ : ParamType
  raw : String
} derive(Show, Eq)

///|
/// Parse a cucumber expression with the default parameter type registry.
pub fn Expression::parse(
  expression : String,
) -> Expression raise ExpressionError {
  Expression::parse_with_registry(expression, ParamTypeRegistry::default())
}

///|
/// Parse a cucumber expression with a custom parameter type registry.
pub fn Expression::parse_with_registry(
  expression : String,
  registry : ParamTypeRegistry,
) -> Expression raise ExpressionError {
  let ast = parse_expression(expression)
  let param_types = collect_param_types(ast, registry)
  let transformers = collect_transformers(ast, registry)
  let group_counts = collect_group_counts(ast, registry)
  let regex_str = compile(ast, registry)
  let regex = @regexp.compile(regex_str.view()) catch {
    _ =>
      raise ExpressionError::ValidationError(
        position=0,
        message="Failed to compile regex: " + regex_str,
      )
  }
  { source: expression, regex, param_types, transformers, group_counts }
}

///|
/// Get the original expression source string.
pub fn Expression::source(self : Expression) -> String {
  self.source
}

///|
/// Match this expression against a text string.
/// Returns Some(Match) with extracted parameters, or None if no match.
pub fn Expression::match_(self : Expression, text : String) -> Match? {
  let result = self.regex.match_(text.view())
  guard result is Some(mr) else { return None }
  let params : Array[Param] = []
  let mut group_idx = 1 // group 0 is full match
  for i, type_ in self.param_types {
    let num_groups = self.group_counts[i]
    let raw_value = match type_ {
      ParamType::String_ => {
        // {string} has multiple capture groups. The outer group (group_idx)
        // captures the full match including quotes. Inner groups capture content.
        // We use the outer group and strip quotes.
        let outer = mr.get(group_idx)
        match outer {
          Some(sv) => {
            let s = sv.to_string()
            if (s.has_prefix("\"") && s.has_suffix("\"")) ||
              (s.has_prefix("'") && s.has_suffix("'")) {
              s.view(start_offset=1, end_offset=s.length() - 1).to_string()
            } else {
              s
            }
          }
          None => ""
        }
      }
      _ =>
        match mr.get(group_idx) {
          Some(sv) => sv.to_string()
          None => ""
        }
    }
    // Apply transformer to get typed value
    let transformed = try {
      self.transformers[i].call([raw_value])
    } catch {
      _ => ParamValue::AnonymousVal(raw_value)
    }
    params.push({ value: transformed, type_, raw: raw_value })
    group_idx = group_idx + num_groups
  }
  Some({ params, })
}

///|
/// Collect parameter types from AST nodes in order.
fn collect_param_types(
  node : Node,
  registry : ParamTypeRegistry,
) -> Array[ParamType] {
  let types : Array[ParamType] = []
  fn walk(n : Node) {
    match n {
      ParameterNode(name) =>
        match registry.get(name) {
          Some(entry) => types.push(entry.type_)
          None => () // error already caught during compile
        }
      ExpressionNode(children) | OptionalNode(children) =>
        for child in children {
          walk(child)
        }
      AlternationNode(arms) =>
        for arm in arms {
          for node in arm {
            walk(node)
          }
        }
      TextNode(_) => ()
    }
  }
  walk(node)
  types
}

///|
/// Collect transformers from AST nodes in order.
fn collect_transformers(
  node : Node,
  registry : ParamTypeRegistry,
) -> Array[Transformer] {
  let transformers : Array[Transformer] = []
  fn walk(n : Node) {
    match n {
      ParameterNode(name) =>
        match registry.get(name) {
          Some(entry) => transformers.push(entry.transformer)
          None => ()
        }
      ExpressionNode(children) | OptionalNode(children) =>
        for child in children {
          walk(child)
        }
      AlternationNode(arms) =>
        for arm in arms {
          for node in arm {
            walk(node)
          }
        }
      TextNode(_) => ()
    }
  }
  walk(node)
  transformers
}

///|
/// Count the number of capture groups each parameter's regex pattern produces.
fn collect_group_counts(
  node : Node,
  registry : ParamTypeRegistry,
) -> Array[Int] {
  let counts : Array[Int] = []
  fn walk(n : Node) {
    match n {
      ParameterNode(name) =>
        match registry.get(name) {
          Some(entry) => counts.push(count_capture_groups(entry.patterns))
          None => counts.push(1)
        }
      ExpressionNode(children) | OptionalNode(children) =>
        for child in children {
          walk(child)
        }
      AlternationNode(arms) =>
        for arm in arms {
          for node in arm {
            walk(node)
          }
        }
      TextNode(_) => ()
    }
  }
  walk(node)
  counts
}

///|
/// Count the total number of capture groups produced by the compiled form
/// of a parameter's patterns. The compiler wraps patterns in one outer
/// capturing group: `((?:pat1)|(?:pat2))`, so we start with 1 for the outer
/// group, then add any inner capturing groups from the patterns themselves.
fn count_capture_groups(patterns : Array[RegexPattern]) -> Int {
  let mut count = 1 // the outer capturing group added by the compiler
  for pat in patterns {
    count = count + count_groups_in_pattern(pat.to_string())
  }
  count
}

///|
/// Count capturing groups in a single regex pattern string.
/// A capturing group is `(` not followed by `?`.
fn count_groups_in_pattern(pattern : String) -> Int {
  let chars = pattern.to_array()
  let len = chars.length()
  let mut count = 0
  let mut i = 0
  while i < len {
    if chars[i] == '\\' {
      // skip escaped character
      i = i + 2
    } else if chars[i] == '(' {
      if i + 1 < len && chars[i + 1] == '?' {
        // non-capturing group (?:...) — don't count
        ()
      } else {
        count = count + 1
      }
      i = i + 1
    } else {
      i = i + 1
    }
  }
  count
}
