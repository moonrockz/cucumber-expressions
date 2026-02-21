test "Expression: match int parameter" {
  let expr = Expression::parse!("I have {int} cucumbers")
  let result = expr.match_("I have 42 cucumbers")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="42")
  inspect!(m.params[0].type_, content="Int")
}

test "Expression: match float parameter" {
  let expr = Expression::parse!("I have {float} cucumbers")
  let result = expr.match_("I have 3.14 cucumbers")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="3.14")
  inspect!(m.params[0].type_, content="Float")
}

test "Expression: match word parameter" {
  let expr = Expression::parse!("a {word} step")
  let result = expr.match_("a good step")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="good")
  inspect!(m.params[0].type_, content="Word")
}

test "Expression: match string parameter (double quotes)" {
  let expr = Expression::parse!("I select {string}")
  let result = expr.match_("I select \"blue\"")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="blue")
  inspect!(m.params[0].type_, content="String_")
}

test "Expression: match string parameter (single quotes)" {
  let expr = Expression::parse!("I select {string}")
  let result = expr.match_("I select 'red'")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="red")
  inspect!(m.params[0].type_, content="String_")
}

test "Expression: match anonymous parameter" {
  let expr = Expression::parse!("{}")
  let result = expr.match_("anything goes")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="1")
  inspect!(m.params[0].value, content="anything goes")
  inspect!(m.params[0].type_, content="Anonymous")
}

test "Expression: no match returns None" {
  let expr = Expression::parse!("I have {int} cucumbers")
  let result = expr.match_("I have many cucumbers")
  inspect!(result, content="None")
}

test "Expression: optional text matches both forms" {
  let expr = Expression::parse!("I have {int} cucumber(s)")
  let result1 = expr.match_("I have 1 cucumber")
  guard result1 is Some(m1) else { fail!("expected match for singular") }
  inspect!(m1.params[0].value, content="1")
  let result2 = expr.match_("I have 5 cucumbers")
  guard result2 is Some(m2) else { fail!("expected match for plural") }
  inspect!(m2.params[0].value, content="5")
}

test "Expression: alternation" {
  let expr = Expression::parse!("I have a cat/dog")
  let result1 = expr.match_("I have a cat")
  inspect!(result1 is Some(_), content="true")
  let result2 = expr.match_("I have a dog")
  inspect!(result2 is Some(_), content="true")
  let result3 = expr.match_("I have a fish")
  inspect!(result3, content="None")
}

test "Expression: multiple parameters" {
  let expr = Expression::parse!("from {string} to {string}")
  let result = expr.match_("from \"London\" to \"Paris\"")
  guard result is Some(m) else { fail!("expected match") }
  inspect!(m.params.length(), content="2")
  inspect!(m.params[0].value, content="London")
  inspect!(m.params[0].type_, content="String_")
  inspect!(m.params[1].value, content="Paris")
  inspect!(m.params[1].type_, content="String_")
}

test "Expression: source accessor" {
  let expr = Expression::parse!("I have {int}")
  inspect!(expr.source(), content="I have {int}")
}
