// A port of the reference CucumberExpressionParser.
//
// Grammar:
//   cucumber-expression := ( alternation | optional | parameter | text )*
//   alternation := (?<=left-boundary) + alternative* + ( '/' + alternative* )+ + (?=right-boundary)
//   left-boundary := whitespace | } | ^
//   right-boundary := whitespace | { | $
//   alternative := optional | parameter | text
//   optional := '(' + option* + ')'
//   option := optional | parameter | text
//   parameter := '{' + name* + '}'
//   name := whitespace | .
//   text := whitespace | ')' | '}' | .

///|
/// The kinds of sub-parser. Each one maps to a rule of the grammar.
priv enum Rule {
  TextRule
  NameRule
  ParameterRule
  OptionalRule
  AlternativeSeparatorRule
  AlternationRule
}

///|
priv struct ParseResult {
  consumed : Int
  ast : Array[Node]
}

///|
priv struct Parser {
  expression : String
  tokens : Array[Token]
}

///|
/// Parse a cucumber expression into an AST.
///
/// This checks only the syntax. `compile_expression` and `Expression::parse`
/// also check the structure, for example that an optional is not empty.
pub fn parse_expression(expression : String) -> Node raise ExpressionError {
  let tokens = tokenize(expression)
  let parser = { expression, tokens, }
  let result = parser.parse_between(
    ExpressionNode,
    StartOfLine,
    EndOfLine,
    [AlternationRule, OptionalRule, ParameterRule, TextRule],
    0,
  )
  result.ast[0]
}

///|
fn Parser::looking_at(self : Parser, at : Int, type_ : TokenType) -> Bool {
  if at < 0 {
    return type_ == StartOfLine
  }
  if at >= self.tokens.length() {
    return type_ == EndOfLine
  }
  self.tokens[at].type_ == type_
}

///|
fn Parser::looking_at_any(
  self : Parser,
  at : Int,
  types : Array[TokenType],
) -> Bool {
  types.iter().any(t => self.looking_at(at, t))
}

///|
fn nothing() -> ParseResult {
  { consumed: 0, ast: [], }
}

///|
fn Parser::parse_rule(
  self : Parser,
  rule : Rule,
  current : Int,
) -> ParseResult raise ExpressionError {
  match rule {
    TextRule => self.parse_text(current)
    NameRule => self.parse_name(current)
    ParameterRule =>
      self.parse_between(
        ParameterNode,
        BeginParameter,
        EndParameter,
        [NameRule],
        current,
      )
    OptionalRule =>
      self.parse_between(
        OptionalNode,
        BeginOptional,
        EndOptional,
        [OptionalRule, ParameterRule, TextRule],
        current,
      )
    AlternativeSeparatorRule => self.parse_alternative_separator(current)
    AlternationRule => self.parse_alternation(current)
  }
}

///|
fn text_node(token : Token) -> Node {
  {
    type_: TextNode,
    nodes: [],
    token: token.text,
    start: token.start,
    end: token.end,
  }
}

///|
fn Parser::parse_text(
  self : Parser,
  current : Int,
) -> ParseResult raise ExpressionError {
  let token = self.tokens[current]
  match token.type_ {
    WhiteSpace | Text | EndParameter | EndOptional =>
      { consumed: 1, ast: [text_node(token)], }
    Alternation => raise alternation_in_optional_error(self.expression, token)
    _ => nothing()
  }
}

///|
fn Parser::parse_name(
  self : Parser,
  current : Int,
) -> ParseResult raise ExpressionError {
  let token = self.tokens[current]
  match token.type_ {
    WhiteSpace | Text => { consumed: 1, ast: [text_node(token)], }
    BeginOptional | EndOptional | BeginParameter | EndParameter | Alternation =>
      raise invalid_parameter_name_in_node_error(self.expression, token)
    _ => nothing()
  }
}

///|
fn Parser::parse_alternative_separator(
  self : Parser,
  current : Int,
) -> ParseResult {
  if !self.looking_at(current, Alternation) {
    return nothing()
  }
  let token = self.tokens[current]
  {
    consumed: 1,
    ast: [
      {
        type_: AlternativeNode,
        nodes: [],
        token: token.text,
        start: token.start,
        end: token.end,
      },
    ],
  }
}

///|
fn Parser::parse_alternation(
  self : Parser,
  current : Int,
) -> ParseResult raise ExpressionError {
  if !self.looking_at_any(current - 1, [StartOfLine, WhiteSpace, EndParameter]) {
    return nothing()
  }
  let result = self.parse_tokens_until(
    [AlternativeSeparatorRule, OptionalRule, ParameterRule, TextRule],
    current,
    [WhiteSpace, EndOfLine, BeginParameter],
  )
  let sub_current = current + result.consumed
  if !result.ast.iter().any(n => n.type_ == AlternativeNode) {
    return nothing()
  }
  let start = self.tokens[current].start
  let end = self.tokens[sub_current].start
  // The right boundary token is not consumed.
  {
    consumed: result.consumed,
    ast: [
      {
        type_: AlternationNode,
        nodes: split_alternatives(start, end, result.ast),
        token: "",
        start,
        end,
      },
    ],
  }
}

///|
fn Parser::parse_between(
  self : Parser,
  type_ : NodeType,
  begin : TokenType,
  end : TokenType,
  rules : Array[Rule],
  current : Int,
) -> ParseResult raise ExpressionError {
  if !self.looking_at(current, begin) {
    return nothing()
  }
  let mut sub_current = current + 1
  let result = self.parse_tokens_until(rules, sub_current, [end, EndOfLine])
  sub_current = sub_current + result.consumed
  if !self.looking_at(sub_current, end) {
    raise missing_end_token_error(
      self.expression,
      begin,
      end,
      self.tokens[current],
    )
  }
  {
    consumed: sub_current + 1 - current,
    ast: [
      {
        type_,
        nodes: result.ast,
        token: "",
        start: self.tokens[current].start,
        end: self.tokens[sub_current].end,
      },
    ],
  }
}

///|
fn Parser::parse_token(
  self : Parser,
  rules : Array[Rule],
  start_at : Int,
) -> ParseResult raise ExpressionError {
  for rule in rules {
    let result = self.parse_rule(rule, start_at)
    if result.consumed != 0 {
      return result
    }
  }
  // The rules always include a rule that consumes the token.
  abort("No eligible parsers at token \{start_at}")
}

///|
fn Parser::parse_tokens_until(
  self : Parser,
  rules : Array[Rule],
  start_at : Int,
  end_types : Array[TokenType],
) -> ParseResult raise ExpressionError {
  let mut current = start_at
  let ast : Array[Node] = []
  while current < self.tokens.length() {
    if self.looking_at_any(current, end_types) {
      break
    }
    let result = self.parse_token(rules, current)
    current = current + result.consumed
    ast.push_iter(result.ast.iter())
  }
  { consumed: current - start_at, ast, }
}

///|
/// Split the nodes of an alternation at the separators into alternative
/// nodes.
fn split_alternatives(
  start : Int,
  end : Int,
  alternation : Array[Node],
) -> Array[Node] {
  let separators : Array[Node] = []
  let alternatives : Array[Array[Node]] = []
  let mut alternative : Array[Node] = []
  for node in alternation {
    if node.type_ == AlternativeNode {
      separators.push(node)
      alternatives.push(alternative)
      alternative = []
    } else {
      alternative.push(node)
    }
  }
  alternatives.push(alternative)
  let last = alternatives.length() - 1
  alternatives.mapi((i, nodes) => {
    let left = if i == 0 { start } else { separators[i - 1].end }
    let right = if i == last { end } else { separators[i].start }
    { type_: AlternativeNode, nodes, token: "", start: left, end: right, }
  })
}
