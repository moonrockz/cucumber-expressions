///|
test "tokenize plain text with spaces" {
  let tokens = tokenize("three blind mice")
  inspect(
    tokens,
    content="[Text(\"three\"), WhiteSpace(\" \"), Text(\"blind\"), WhiteSpace(\" \"), Text(\"mice\")]",
  )
}

///|
test "tokenize parameter" {
  let tokens = tokenize("{int}")
  inspect(tokens, content="[BeginParameter, Text(\"int\"), EndParameter]")
}

///|
test "tokenize optional" {
  let tokens = tokenize("(blind)")
  inspect(tokens, content="[BeginOptional, Text(\"blind\"), EndOptional]")
}

///|
test "tokenize alternation" {
  let tokens = tokenize("cat/dog")
  inspect(tokens, content="[Text(\"cat\"), Alternation, Text(\"dog\")]")
}

///|
test "tokenize escaped parens become literal text" {
  let tokens = tokenize("\\(blind\\)")
  inspect(tokens, content="[Text(\"(blind)\")]")
}

///|
test "tokenize empty expression" {
  let tokens = tokenize("")
  inspect(tokens, content="[]")
}

///|
test "tokenize full expression with parameter and optional" {
  let tokens = tokenize("I have {int} cucumber(s)")
  inspect(
    tokens,
    content="[Text(\"I\"), WhiteSpace(\" \"), Text(\"have\"), WhiteSpace(\" \"), BeginParameter, Text(\"int\"), EndParameter, WhiteSpace(\" \"), Text(\"cucumber\"), BeginOptional, Text(\"s\"), EndOptional]",
  )
}

///|
test "tokenize alternation groups separated by whitespace" {
  let tokens = tokenize("a/b c/d")
  inspect(
    tokens,
    content="[Text(\"a\"), Alternation, Text(\"b\"), WhiteSpace(\" \"), Text(\"c\"), Alternation, Text(\"d\")]",
  )
}

///|
test "tokenize escaped backslash" {
  let tokens = tokenize("\\\\")
  inspect(tokens, content="[Text(\"\\\\\")]")
}

///|
test "tokenize escaped space" {
  let tokens = tokenize("\\ ")
  inspect(tokens, content="[Text(\" \")]")
}

///|
test "tokenize error: escape at end of expression" {
  let result : Result[Array[Token], Error] = Ok(tokenize("hello\\")) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}

///|
test "tokenize error: cannot escape non-escapable character" {
  let result : Result[Array[Token], Error] = Ok(tokenize("\\x")) catch {
    e => Err(e)
  }
  inspect(result is Err(_), content="true")
}
