// =============================================================================
// Official Cucumber Expressions Test Suite Port
//
// Tests ported from the official cucumber-expressions specification to verify
// compliance. Organised into categories: Tokenizer, Parser, Transformation
// (AST to Regex), End-to-End Matching, and Error handling.
// =============================================================================

// ---------------------------------------------------------------------------
// 1. Tokenizer — additional coverage
// ---------------------------------------------------------------------------

test "spec/tokenizer: unicode text" {
  let tokens = tokenize!("Привет мир")
  inspect(
    tokens,
    content="[Text(\"Привет\"), WhiteSpace(\" \"), Text(\"мир\")]",
  )
}

test "spec/tokenizer: multiple consecutive escaped characters" {
  // \( \) in sequence
  let tokens = tokenize!("\\(\\)")
  inspect(tokens, content="[Text(\"()\")]")
}

test "spec/tokenizer: escaped slash becomes literal text" {
  let tokens = tokenize!("mice\\/rats")
  inspect(tokens, content="[Text(\"mice/rats\")]")
}

test "spec/tokenizer: escaped brace becomes literal text" {
  let tokens = tokenize!("\\{int\\}")
  inspect(tokens, content="[Text(\"{int}\")]")
}

// ---------------------------------------------------------------------------
// 2. Parser — additional coverage
// ---------------------------------------------------------------------------

test "spec/parser: alternation with parameter boundary" {
  let ast = parse_expression!("{int}st/nd/rd/th")
  inspect(
    ast,
    content="ExpressionNode([ParameterNode(\"int\"), AlternationNode([[TextNode(\"st\")], [TextNode(\"nd\")], [TextNode(\"rd\")], [TextNode(\"th\")]])])",
  )
}

test "spec/parser: escaped alternation becomes literal slash" {
  let ast = parse_expression!("mice\\/rats")
  inspect(ast, content="ExpressionNode([TextNode(\"mice/rats\")])")
}

test "spec/parser: multiple optionals" {
  let ast = parse_expression!("three (very) (blind) mice")
  inspect(
    ast,
    content=(
      #|ExpressionNode([TextNode("three "), OptionalNode([TextNode("very")]), TextNode(" "), OptionalNode([TextNode("blind")]), TextNode(" mice")])

    ),
  )
}

// ---------------------------------------------------------------------------
// 3. Transformation (AST to Regex)
// ---------------------------------------------------------------------------

test "spec/compile: empty expression" {
  inspect!(compile_expression!(""), content="^$")
}

test "spec/compile: single char" {
  inspect!(compile_expression!("a"), content="^a$")
}

test "spec/compile: optional" {
  inspect!(compile_expression!("(a)"), content="^(?:a)?$")
}

test "spec/compile: alternation with spaces" {
  inspect!(compile_expression!("a/b c/d/e"), content="^(?:a|b) (?:c|d|e)$")
}

test "spec/compile: alternation with optional" {
  inspect!(compile_expression!("a/b(c)"), content="^(?:a|b(?:c)?)$")
}

test "spec/compile: unicode with optional" {
  inspect!(
    compile_expression!("Привет, Мир(ы)!"),
    content="^Привет, Мир(?:ы)?!$",
  )
}

test "spec/compile: escaped slash becomes literal" {
  inspect!(compile_expression!("mice\\/rats"), content="^mice/rats$")
}

test "spec/compile: multiple optionals" {
  inspect!(
    compile_expression!("three (very) (blind) mice"),
    content="^three (?:very)? (?:blind)? mice$",
  )
}

test "spec/compile: dollar sign is escaped" {
  inspect!(compile_expression!("I have $100"), content="^I have \\$100$")
}

test "spec/compile: dot is escaped" {
  inspect!(compile_expression!("file.txt"), content="^file\\.txt$")
}

test "spec/compile: parentheses escaped" {
  inspect!(compile_expression!("\\(text\\)"), content="^\\(text\\)$")
}

// ---------------------------------------------------------------------------
// 4. End-to-End Matching (MOST IMPORTANT)
// ---------------------------------------------------------------------------

// --- Basic parameter types ---

test "spec/match: int" {
  let expr = Expression::parse!("I have {int} cucumbers")
  let result = expr.match_("I have 42 cucumbers")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="42")
  inspect!(m.params[0].type_, content="Int")
}

test "spec/match: negative int" {
  let expr = Expression::parse!("I have {int} cucumbers")
  let result = expr.match_("I have -5 cucumbers")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params[0].value, content="-5")
  inspect!(m.params[0].type_, content="Int")
}

test "spec/match: float" {
  let expr = Expression::parse!("I have {float} cucumbers")
  let result = expr.match_("I have 3.14 cucumbers")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params[0].value, content="3.14")
  inspect!(m.params[0].type_, content="Float")
}

test "spec/match: word" {
  let expr = Expression::parse!("a {word} step")
  let result = expr.match_("a good step")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params[0].value, content="good")
  inspect!(m.params[0].type_, content="Word")
}

test "spec/match: double-quoted string" {
  let expr = Expression::parse!("I select {string}")
  let result = expr.match_("I select \"blue\"")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params[0].value, content="blue")
  inspect!(m.params[0].type_, content="String_")
}

test "spec/match: single-quoted string" {
  let expr = Expression::parse!("I select {string}")
  let result = expr.match_("I select 'red'")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params[0].value, content="red")
  inspect!(m.params[0].type_, content="String_")
}

test "spec/match: anonymous" {
  let expr = Expression::parse!("{}")
  let result = expr.match_("anything")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params[0].value, content="anything")
  inspect!(m.params[0].type_, content="Anonymous")
}

// --- Optional text ---

test "spec/match: optional present" {
  let expr = Expression::parse!("{int} cucumber(s)")
  let result = expr.match_("5 cucumbers")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params[0].value, content="5")
  inspect!(m.params[0].type_, content="Int")
}

test "spec/match: optional absent" {
  let expr = Expression::parse!("{int} cucumber(s)")
  let result = expr.match_("1 cucumber")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params[0].value, content="1")
  inspect!(m.params[0].type_, content="Int")
}

test "spec/match: multiple optionals both present" {
  let expr = Expression::parse!("three (very) (blind) mice")
  let result = expr.match_("three very blind mice")
  inspect!(result is Some(_), content="true")
}

test "spec/match: multiple optionals both absent" {
  let expr = Expression::parse!("three (very) (blind) mice")
  let result = expr.match_("three   mice")
  inspect!(result is Some(_), content="true")
}

test "spec/match: multiple optionals first present" {
  let expr = Expression::parse!("three (very) (blind) mice")
  let result = expr.match_("three very  mice")
  inspect!(result is Some(_), content="true")
}

test "spec/match: multiple optionals second present" {
  let expr = Expression::parse!("three  (blind) mice")
  let result = expr.match_("three  blind mice")
  inspect!(result is Some(_), content="true")
}

// --- Alternation ---

test "spec/match: alternation first" {
  let expr = Expression::parse!("I have a cat/dog")
  let result = expr.match_("I have a cat")
  inspect!(result is Some(_), content="true")
}

test "spec/match: alternation second" {
  let expr = Expression::parse!("I have a cat/dog")
  let result = expr.match_("I have a dog")
  inspect!(result is Some(_), content="true")
}

test "spec/match: alternation no match" {
  let expr = Expression::parse!("I have a cat/dog")
  let result = expr.match_("I have a fish")
  inspect!(result, content="None")
}

test "spec/match: three-way alternation" {
  let expr = Expression::parse!("red/green/blue")
  inspect!(expr.match_("red") is Some(_), content="true")
  inspect!(expr.match_("green") is Some(_), content="true")
  inspect!(expr.match_("blue") is Some(_), content="true")
  inspect!(expr.match_("yellow"), content="None")
}

test "spec/match: alternation with optional" {
  let expr = Expression::parse!("a/b(c)")
  inspect!(expr.match_("a") is Some(_), content="true")
  inspect!(expr.match_("b") is Some(_), content="true")
  inspect!(expr.match_("bc") is Some(_), content="true")
  inspect!(expr.match_("ac"), content="None")
}

// --- Multiple parameters ---

test "spec/match: two int params" {
  let expr = Expression::parse!("{int} + {int}")
  let result = expr.match_("3 + 5")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="2")
  inspect!(m.params[0].value, content="3")
  inspect!(m.params[0].type_, content="Int")
  inspect!(m.params[1].value, content="5")
  inspect!(m.params[1].type_, content="Int")
}

test "spec/match: mixed param types" {
  let expr = Expression::parse!("{word} costs {float}")
  let result = expr.match_("apple costs 1.50")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="2")
  inspect!(m.params[0].value, content="apple")
  inspect!(m.params[0].type_, content="Word")
  inspect!(m.params[1].value, content="1.50")
  inspect!(m.params[1].type_, content="Float")
}

test "spec/match: int and string params" {
  let expr = Expression::parse!("{int} {string}")
  let result = expr.match_("42 \"hello\"")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="2")
  inspect!(m.params[0].value, content="42")
  inspect!(m.params[0].type_, content="Int")
  inspect!(m.params[1].value, content="hello")
  inspect!(m.params[1].type_, content="String_")
}

// --- Edge cases ---

test "spec/match: empty expression matches empty string" {
  let expr = Expression::parse!("")
  let result = expr.match_("")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="0")
}

test "spec/match: empty expression does not match non-empty" {
  let expr = Expression::parse!("")
  let result = expr.match_("something")
  inspect!(result, content="None")
}

test "spec/match: special regex chars dollar" {
  let expr = Expression::parse!("I have $100")
  let result = expr.match_("I have $100")
  inspect!(result is Some(_), content="true")
}

test "spec/match: special regex chars dot" {
  let expr = Expression::parse!("file.txt")
  let result = expr.match_("file.txt")
  inspect!(result is Some(_), content="true")
}

test "spec/match: dot is not regex wildcard" {
  let expr = Expression::parse!("file.txt")
  let result = expr.match_("filextxt")
  inspect!(result, content="None")
}

test "spec/match: escaped slash literal" {
  let expr = Expression::parse!("mice\\/rats")
  let result = expr.match_("mice/rats")
  inspect!(result is Some(_), content="true")
}

test "spec/match: escaped slash does not alternate" {
  let expr = Expression::parse!("mice\\/rats")
  // Should NOT match just "mice" since the slash is escaped (literal)
  let result = expr.match_("mice")
  inspect!(result, content="None")
}

test "spec/match: escaped parens literal" {
  let expr = Expression::parse!("\\(text\\)")
  let result = expr.match_("(text)")
  inspect!(result is Some(_), content="true")
}

test "spec/match: escaped braces literal" {
  let expr = Expression::parse!("\\{int\\}")
  let result = expr.match_("{int}")
  inspect!(result is Some(_), content="true")
}

test "spec/match: unicode expression" {
  let expr = Expression::parse!("Привет, Мир(ы)!")
  inspect!(expr.match_("Привет, Мир!") is Some(_), content="true")
  inspect!(expr.match_("Привет, Миры!") is Some(_), content="true")
  inspect!(expr.match_("Hello, World!"), content="None")
}

test "spec/match: only whitespace text" {
  let expr = Expression::parse!("a b")
  inspect!(expr.match_("a b") is Some(_), content="true")
  inspect!(expr.match_("ab"), content="None")
}

// ---------------------------------------------------------------------------
// 5. Error Tests
// ---------------------------------------------------------------------------

test "spec/error: unmatched brace" {
  let mut caught = false
  try {
    Expression::parse!("{int") |> ignore
  } catch {
    ExpressionError::UnmatchedBrace(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}

test "spec/error: unmatched paren" {
  let mut caught = false
  try {
    Expression::parse!("(blind") |> ignore
  } catch {
    ExpressionError::UnmatchedParen(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}

test "spec/error: unknown parameter type" {
  let mut caught = false
  try {
    Expression::parse!("{unknown}") |> ignore
  } catch {
    ExpressionError::UnknownParameterType(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}

test "spec/error: backslash at end" {
  let mut caught = false
  try {
    Expression::parse!("hello\\") |> ignore
  } catch {
    ExpressionError::UnexpectedEscapeEnd(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}

test "spec/error: cannot escape arbitrary character" {
  let mut caught = false
  try {
    Expression::parse!("\\x") |> ignore
  } catch {
    ExpressionError::CannotEscape(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}

test "spec/error: empty alternation arm (trailing slash)" {
  let mut caught = false
  try {
    Expression::parse!("cats/") |> ignore
  } catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}

test "spec/error: empty alternation arm (leading slash)" {
  let mut caught = false
  try {
    Expression::parse!("/cats") |> ignore
  } catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}

test "spec/error: nested optionals" {
  let mut caught = false
  try {
    Expression::parse!("((very) blind)") |> ignore
  } catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}

test "spec/error: parameter inside optional" {
  let mut caught = false
  try {
    Expression::parse!("({int})") |> ignore
  } catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect!(caught, content="true")
}
