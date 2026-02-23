///|
test "ParamType::Int Show" {
  inspect(ParamType::Int, content="Int")
}

///|
test "ParamType::Float Show" {
  inspect(ParamType::Float, content="Float")
}

///|
test "ParamType::String_ Show" {
  inspect(ParamType::String_, content="String_")
}

///|
test "ParamType::Word Show" {
  inspect(ParamType::Word, content="Word")
}

///|
test "ParamType::Anonymous Show" {
  inspect(ParamType::Anonymous, content="Anonymous")
}

///|
test "ParamType::Custom Show" {
  inspect(
    ParamType::Custom("color"),
    content=(
      #|Custom("color")
    ),
  )
}

///|
test "ParamType equality" {
  assert_true(ParamType::Int == ParamType::Int)
  assert_true(ParamType::Float == ParamType::Float)
  assert_true(ParamType::String_ == ParamType::String_)
  assert_true(ParamType::Word == ParamType::Word)
  assert_true(ParamType::Anonymous == ParamType::Anonymous)
  assert_true(ParamType::Custom("x") == ParamType::Custom("x"))
  assert_true(ParamType::Int != ParamType::Float)
  assert_true(ParamType::Custom("a") != ParamType::Custom("b"))
}

///|
test "ParamTypeRegistry::default has 5 built-in types" {
  let reg = ParamTypeRegistry::default()
  inspect(reg.entries.length(), content="5")
}

///|
test "Registry get int returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("int") {
    Some((type_, patterns)) => {
      assert_true(type_ == ParamType::Int)
      inspect(patterns.length(), content="2")
      inspect(patterns[0], content="(?:-?\\d+)")
      inspect(patterns[1], content="(?:\\d+)")
    }
    None => abort("expected int to be registered")
  }
}

///|
test "Registry get float returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("float") {
    Some((type_, patterns)) => {
      assert_true(type_ == ParamType::Float)
      inspect(patterns.length(), content="1")
    }
    None => abort("expected float to be registered")
  }
}

///|
test "Registry get string returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("string") {
    Some((type_, patterns)) => {
      assert_true(type_ == ParamType::String_)
      inspect(patterns.length(), content="2")
    }
    None => abort("expected string to be registered")
  }
}

///|
test "Registry get word returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("word") {
    Some((type_, patterns)) => {
      assert_true(type_ == ParamType::Word)
      inspect(patterns.length(), content="1")
      inspect(patterns[0], content="[^\\s]+")
    }
    None => abort("expected word to be registered")
  }
}

///|
test "Registry get anonymous returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("") {
    Some((type_, patterns)) => {
      assert_true(type_ == ParamType::Anonymous)
      inspect(patterns.length(), content="1")
      inspect(patterns[0], content=".*")
    }
    None => abort("expected anonymous to be registered")
  }
}

///|
test "Registry get unknown returns None" {
  let reg = ParamTypeRegistry::default()
  inspect(reg.get("unknown"), content="None")
}

///|
test "Custom type registration works" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), ["red|green|blue"])
  match reg.get("color") {
    Some((type_, patterns)) => {
      assert_true(type_ == ParamType::Custom("color"))
      inspect(patterns.length(), content="1")
      inspect(patterns[0], content="red|green|blue")
    }
    None => abort("expected color to be registered")
  }
}

///|
test "RegexPattern round-trip" {
  let rp = RegexPattern("\\d+")
  assert_eq(rp.to_string(), "\\d+")
}

///|
test "RegexPattern equality" {
  let a = RegexPattern("abc")
  let b = RegexPattern("abc")
  let c = RegexPattern("xyz")
  assert_eq(a, b)
  assert_true(a != c)
}
