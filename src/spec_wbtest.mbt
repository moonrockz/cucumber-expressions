// =============================================================================
// Official Cucumber Expressions Test Suite Port
//
// Tests ported from the official cucumber-expressions specification to verify
// compliance. Organised into categories: Tokenizer, Parser, Transformation
// (AST to Regex), End-to-End Matching, and Error handling.
// =============================================================================

// ---------------------------------------------------------------------------
// 4. End-to-End Matching (MOST IMPORTANT)
// ---------------------------------------------------------------------------

// --- Basic parameter types ---

///|
test "spec/match: int" {
  let expr = Expression::parse("I have {int} cucumbers")
  let result = expr.match_("I have 42 cucumbers")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params.length(), content="1")
  inspect(m.params[0].raw, content="42")
  debug_inspect(m.params[0].type_, content="Int")
}

///|
test "spec/match: negative int" {
  let expr = Expression::parse("I have {int} cucumbers")
  let result = expr.match_("I have -5 cucumbers")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params[0].raw, content="-5")
  debug_inspect(m.params[0].type_, content="Int")
}

///|
test "spec/match: float" {
  let expr = Expression::parse("I have {float} cucumbers")
  let result = expr.match_("I have 3.14 cucumbers")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params[0].raw, content="3.14")
  debug_inspect(m.params[0].type_, content="Float")
}

///|
test "spec/match: word" {
  let expr = Expression::parse("a {word} step")
  let result = expr.match_("a good step")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params[0].raw, content="good")
  debug_inspect(m.params[0].type_, content="Word")
}

///|
test "spec/match: double-quoted string" {
  let expr = Expression::parse("I select {string}")
  let result = expr.match_("I select \"blue\"")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params[0].raw, content="blue")
  debug_inspect(m.params[0].type_, content="String_")
}

///|
test "spec/match: single-quoted string" {
  let expr = Expression::parse("I select {string}")
  let result = expr.match_("I select 'red'")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params[0].raw, content="red")
  debug_inspect(m.params[0].type_, content="String_")
}

///|
test "spec/match: anonymous" {
  let expr = Expression::parse("{}")
  let result = expr.match_("anything")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params[0].raw, content="anything")
  debug_inspect(m.params[0].type_, content="Anonymous")
}

///|
test "spec/match: double" {
  let expr = Expression::parse("the value is {double}")
  let result = expr.match_("the value is 3.14")
  guard result is Some(m) else { fail("expected match") }
  assert_eq(m.params[0].value, ParamValue::DoubleVal(3.14))
  assert_eq(m.params[0].raw, "3.14")
  assert_eq(m.params[0].type_, ParamType::Double_)
}

///|
test "spec/match: double scientific notation" {
  let expr = Expression::parse("the value is {double}")
  let result = expr.match_("the value is 1.5e10")
  guard result is Some(m) else { fail("expected match") }
  assert_eq(m.params[0].raw, "1.5e10")
}

///|
test "spec/match: long" {
  let expr = Expression::parse("I have {long} items")
  let result = expr.match_("I have 9223372036854775807 items")
  guard result is Some(m) else { fail("expected match") }
  assert_eq(m.params[0].value, ParamValue::LongVal(9223372036854775807L))
  assert_eq(m.params[0].raw, "9223372036854775807")
}

///|
test "spec/match: byte" {
  let expr = Expression::parse("value is {byte}")
  let result = expr.match_("value is 127")
  guard result is Some(m) else { fail("expected match") }
  assert_eq(m.params[0].value, ParamValue::ByteVal(b'\x7F'))
  assert_eq(m.params[0].raw, "127")
}

///|
test "spec/match: short" {
  let expr = Expression::parse("port is {short}")
  let result = expr.match_("port is 8080")
  guard result is Some(m) else { fail("expected match") }
  assert_eq(m.params[0].value, ParamValue::ShortVal(8080))
  assert_eq(m.params[0].raw, "8080")
}

///|
test "spec/match: bigdecimal" {
  let expr = Expression::parse("price is {bigdecimal}")
  let result = expr.match_("price is 99.99")
  guard result is Some(m) else { fail("expected match") }
  assert_eq(
    m.params[0].value,
    ParamValue::BigDecimalVal(@decimal.Decimal::from_string("99.99").unwrap()),
  )
  assert_eq(m.params[0].raw, "99.99")
}

///|
test "spec/match: biginteger" {
  let expr = Expression::parse("count is {biginteger}")
  let result = expr.match_("count is 123456789012345678901234567890")
  guard result is Some(m) else { fail("expected match") }
  assert_eq(
    m.params[0].value,
    ParamValue::BigIntegerVal(
      BigInt::from_string("123456789012345678901234567890"),
    ),
  )
  assert_eq(m.params[0].raw, "123456789012345678901234567890")
}

// --- Optional text ---

///|
test "spec/match: optional present" {
  let expr = Expression::parse("{int} cucumber(s)")
  let result = expr.match_("5 cucumbers")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params[0].raw, content="5")
  debug_inspect(m.params[0].type_, content="Int")
}

///|
test "spec/match: optional absent" {
  let expr = Expression::parse("{int} cucumber(s)")
  let result = expr.match_("1 cucumber")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params[0].raw, content="1")
  debug_inspect(m.params[0].type_, content="Int")
}

///|
test "spec/match: multiple optionals both present" {
  let expr = Expression::parse("three (very) (blind) mice")
  let result = expr.match_("three very blind mice")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: multiple optionals both absent" {
  let expr = Expression::parse("three (very) (blind) mice")
  let result = expr.match_("three   mice")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: multiple optionals first present" {
  let expr = Expression::parse("three (very) (blind) mice")
  let result = expr.match_("three very  mice")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: multiple optionals second present" {
  let expr = Expression::parse("three  (blind) mice")
  let result = expr.match_("three  blind mice")
  inspect(result is Some(_), content="true")
}

// --- Alternation ---

///|
test "spec/match: alternation first" {
  let expr = Expression::parse("I have a cat/dog")
  let result = expr.match_("I have a cat")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: alternation second" {
  let expr = Expression::parse("I have a cat/dog")
  let result = expr.match_("I have a dog")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: alternation no match" {
  let expr = Expression::parse("I have a cat/dog")
  let result = expr.match_("I have a fish")
  debug_inspect(result, content="None")
}

///|
test "spec/match: three-way alternation" {
  let expr = Expression::parse("red/green/blue")
  inspect(expr.match_("red") is Some(_), content="true")
  inspect(expr.match_("green") is Some(_), content="true")
  inspect(expr.match_("blue") is Some(_), content="true")
  debug_inspect(expr.match_("yellow"), content="None")
}

///|
test "spec/match: alternation with optional" {
  let expr = Expression::parse("a/b(c)")
  inspect(expr.match_("a") is Some(_), content="true")
  inspect(expr.match_("b") is Some(_), content="true")
  inspect(expr.match_("bc") is Some(_), content="true")
  debug_inspect(expr.match_("ac"), content="None")
}

// --- Multiple parameters ---

///|
test "spec/match: two int params" {
  let expr = Expression::parse("{int} + {int}")
  let result = expr.match_("3 + 5")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params.length(), content="2")
  inspect(m.params[0].raw, content="3")
  debug_inspect(m.params[0].type_, content="Int")
  inspect(m.params[1].raw, content="5")
  debug_inspect(m.params[1].type_, content="Int")
}

///|
test "spec/match: mixed param types" {
  let expr = Expression::parse("{word} costs {float}")
  let result = expr.match_("apple costs 1.50")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params.length(), content="2")
  inspect(m.params[0].raw, content="apple")
  debug_inspect(m.params[0].type_, content="Word")
  inspect(m.params[1].raw, content="1.50")
  debug_inspect(m.params[1].type_, content="Float")
}

///|
test "spec/match: int and string params" {
  let expr = Expression::parse("{int} {string}")
  let result = expr.match_("42 \"hello\"")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params.length(), content="2")
  inspect(m.params[0].raw, content="42")
  debug_inspect(m.params[0].type_, content="Int")
  inspect(m.params[1].raw, content="hello")
  debug_inspect(m.params[1].type_, content="String_")
}

// --- Edge cases ---

///|
test "spec/match: empty expression matches empty string" {
  let expr = Expression::parse("")
  let result = expr.match_("")
  guard result is Some(m) else { fail("expected match") }
  inspect(m.params.length(), content="0")
}

///|
test "spec/match: empty expression does not match non-empty" {
  let expr = Expression::parse("")
  let result = expr.match_("something")
  debug_inspect(result, content="None")
}

///|
test "spec/match: special regex chars dollar" {
  let expr = Expression::parse("I have $100")
  let result = expr.match_("I have $100")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: special regex chars dot" {
  let expr = Expression::parse("file.txt")
  let result = expr.match_("file.txt")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: dot is not regex wildcard" {
  let expr = Expression::parse("file.txt")
  let result = expr.match_("filextxt")
  debug_inspect(result, content="None")
}

///|
test "spec/match: escaped slash literal" {
  let expr = Expression::parse("mice\\/rats")
  let result = expr.match_("mice/rats")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: escaped slash does not alternate" {
  let expr = Expression::parse("mice\\/rats")
  // Should NOT match just "mice" since the slash is escaped (literal)
  let result = expr.match_("mice")
  debug_inspect(result, content="None")
}

///|
test "spec/match: escaped parens literal" {
  let expr = Expression::parse("\\(text\\)")
  let result = expr.match_("(text)")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: escaped braces literal" {
  let expr = Expression::parse("\\{int\\}")
  let result = expr.match_("{int}")
  inspect(result is Some(_), content="true")
}

///|
test "spec/match: unicode expression" {
  let expr = Expression::parse("Привет, Мир(ы)!")
  inspect(expr.match_("Привет, Мир!") is Some(_), content="true")
  inspect(expr.match_("Привет, Миры!") is Some(_), content="true")
  debug_inspect(expr.match_("Hello, World!"), content="None")
}

///|
test "spec/match: only whitespace text" {
  let expr = Expression::parse("a b")
  inspect(expr.match_("a b") is Some(_), content="true")
  debug_inspect(expr.match_("ab"), content="None")
}

// ---------------------------------------------------------------------------
// 5. Error Tests
// ---------------------------------------------------------------------------

///|
test "spec/error: unmatched brace" {
  let mut caught = false
  try Expression::parse("{int") |> ignore catch {
    ExpressionError::UnmatchedBrace(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "spec/error: unmatched paren" {
  let mut caught = false
  try Expression::parse("(blind") |> ignore catch {
    ExpressionError::UnmatchedParen(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "spec/error: unknown parameter type" {
  let mut caught = false
  try Expression::parse("{unknown}") |> ignore catch {
    ExpressionError::UnknownParameterType(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "spec/error: backslash at end" {
  let mut caught = false
  try Expression::parse("hello\\") |> ignore catch {
    ExpressionError::UnexpectedEscapeEnd(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "spec/error: cannot escape arbitrary character" {
  let mut caught = false
  try Expression::parse("\\x") |> ignore catch {
    ExpressionError::CannotEscape(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "spec/error: empty alternation arm (trailing slash)" {
  let mut caught = false
  try Expression::parse("cats/") |> ignore catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "spec/error: empty alternation arm (leading slash)" {
  let mut caught = false
  try Expression::parse("/cats") |> ignore catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "spec/error: nested optionals" {
  let mut caught = false
  try Expression::parse("((very) blind)") |> ignore catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

///|
test "spec/error: parameter inside optional" {
  let mut caught = false
  try Expression::parse("({int})") |> ignore catch {
    ExpressionError::ValidationError(..) => caught = true
    _ => ()
  }
  inspect(caught, content="true")
}

// ---------------------------------------------------------------------------
// 6. Behavior outside the reference testdata
// ---------------------------------------------------------------------------

///|
test "spec/tokenizer: only a space is white space" {
  let types = tokenize("a\tb c").map(t => t.type_)
  debug_inspect(
    types,
    content="[StartOfLine, Text, WhiteSpace, Text, EndOfLine]",
  )
}

///|
test "spec/compile: tab does not end an alternation" {
  inspect(compile_expression("a\tb/c"), content="^(?:a\tb|c)$")
}

///|
test "spec/parser: Node::text joins the text of child nodes" {
  let ast = parse_expression("{int} (s)")
  inspect(ast.nodes[0].text(), content="int")
  inspect(ast.nodes[2].text(), content="s")
}

///|
test "spec/error: position and message of a structure error" {
  let err = try compile_expression("(a(b))") catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  inspect(err.position(), content="2")
  inspect(err.to_string() == err.message(), content="true")
  inspect(
    err.message(),
    content=(
      #|This Cucumber Expression has a problem at column 3:
      #|
      #|(a(b))
      #|  ^-^
      #|An optional may not contain an other optional.
      #|If you did not mean to use an optional type you can use '\(' to escape the '('. For more complicated expressions consider using a regular expression instead.
    ),
  )
}

///|
test "spec/error: unknown parameter type has name and position" {
  let err = try Expression::parse("a {color}") catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  guard err is UnknownParameterType(name~, position~, ..) else {
    fail("wrong error")
  }
  inspect(name, content="color")
  inspect(position, content="2")
}

///|
test "spec/tokenizer: positions count code points, not UTF-16 units" {
  let tokens = tokenize("😀 {int}")
  debug_inspect(
    tokens.map(t => (t.type_, t.start, t.end)),
    content=(
      #|[
      #|  (StartOfLine, 0, 0),
      #|  (Text, 0, 1),
      #|  (WhiteSpace, 1, 2),
      #|  (BeginParameter, 2, 3),
      #|  (Text, 3, 6),
      #|  (EndParameter, 6, 7),
      #|  (EndOfLine, 7, 7),
      #|]
    ),
  )
}

///|
test "spec/error: column counts code points, not UTF-16 units" {
  let err = try compile_expression("😀 (a") catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  inspect(err.position(), content="2")
  inspect(
    err.message(),
    content=(
      #|This Cucumber Expression has a problem at column 3:
      #|
      #|😀 (a
      #|  ^
      #|The '(' does not have a matching ')'.
      #|If you did not intend to use optional text you can use '\(' to escape the optional text
    ),
  )
}

///|
test "spec/error: a parameter regexp that does not compile" {
  let reg = ParamTypeRegistry::default()
  reg.register("bad", Custom("bad"), [RegexPattern("a{2")])
  let err = try Expression::parse_with_registry("x {bad}", reg) catch {
    e => e
  } noraise {
    _ => fail("expected an error")
  }
  inspect(err.position(), content="0")
  inspect(
    err
    .message()
    .has_prefix(
      "The regex ^x (a{2)$ of this Cucumber Expression does not compile: ",
    ),
    content="true",
  )
}
