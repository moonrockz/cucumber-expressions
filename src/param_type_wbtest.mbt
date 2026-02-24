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
test "ParamType::Double_ Show" {
  inspect(ParamType::Double_, content="Double_")
}

///|
test "ParamType::Long Show" {
  inspect(ParamType::Long, content="Long")
}

///|
test "ParamType::Byte Show" {
  inspect(ParamType::Byte, content="Byte")
}

///|
test "ParamType::Short Show" {
  inspect(ParamType::Short, content="Short")
}

///|
test "ParamType::BigDecimal Show" {
  inspect(ParamType::BigDecimal, content="BigDecimal")
}

///|
test "ParamType::BigInteger Show" {
  inspect(ParamType::BigInteger, content="BigInteger")
}

///|
test "ParamType equality" {
  assert_true(ParamType::Int == ParamType::Int)
  assert_true(ParamType::Float == ParamType::Float)
  assert_true(ParamType::String_ == ParamType::String_)
  assert_true(ParamType::Word == ParamType::Word)
  assert_true(ParamType::Anonymous == ParamType::Anonymous)
  assert_true(ParamType::Double_ == ParamType::Double_)
  assert_true(ParamType::Long == ParamType::Long)
  assert_true(ParamType::Byte == ParamType::Byte)
  assert_true(ParamType::Short == ParamType::Short)
  assert_true(ParamType::BigDecimal == ParamType::BigDecimal)
  assert_true(ParamType::BigInteger == ParamType::BigInteger)
  assert_true(ParamType::Custom("x") == ParamType::Custom("x"))
  assert_true(ParamType::Int != ParamType::Float)
  assert_true(ParamType::Double_ != ParamType::Float)
  assert_true(ParamType::Long != ParamType::Int)
  assert_true(ParamType::Custom("a") != ParamType::Custom("b"))
}

///|
test "ParamTypeRegistry::default has 5 built-in types" {
  let reg = ParamTypeRegistry::default()
  inspect(reg.entries_view().length(), content="5")
}

///|
test "Registry get int returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("int") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Int)
      inspect(entry.patterns.length(), content="2")
      inspect(entry.patterns[0].to_string(), content="(?:-?\\d+)")
      inspect(entry.patterns[1].to_string(), content="(?:\\d+)")
    }
    None => abort("expected int to be registered")
  }
}

///|
test "Registry get float returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("float") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Float)
      inspect(entry.patterns.length(), content="1")
    }
    None => abort("expected float to be registered")
  }
}

///|
test "Registry get string returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("string") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::String_)
      inspect(entry.patterns.length(), content="2")
    }
    None => abort("expected string to be registered")
  }
}

///|
test "Registry get word returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("word") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Word)
      inspect(entry.patterns.length(), content="1")
      inspect(entry.patterns[0].to_string(), content="[^\\s]+")
    }
    None => abort("expected word to be registered")
  }
}

///|
test "Registry get anonymous returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Anonymous)
      inspect(entry.patterns.length(), content="1")
      inspect(entry.patterns[0].to_string(), content=".*")
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
  reg.register("color", ParamType::Custom("color"), [
    RegexPattern("red|green|blue"),
  ])
  match reg.get("color") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Custom("color"))
      inspect(entry.patterns.length(), content="1")
      inspect(entry.patterns[0].to_string(), content="red|green|blue")
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

///|
test "ParamTypeEntry fields are accessible" {
  let entry : ParamTypeEntry = {
    name: "color",
    type_: ParamType::Custom("color"),
    patterns: [RegexPattern("red|blue|green")],
  }
  assert_eq(entry.name, "color")
  assert_eq(entry.type_, ParamType::Custom("color"))
  assert_eq(entry.patterns[0].to_string(), "red|blue|green")
}

///|
test "entries_view returns all registered types" {
  let reg = ParamTypeRegistry::default()
  let view = reg.entries_view()
  assert_eq(view.length(), 5)
  assert_eq(view[0].name, "int")
  assert_eq(view[0].type_, ParamType::Int)
}

///|
test "get returns ParamTypeEntry" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("int")
  guard entry is Some(e)
  assert_eq(e.name, "int")
  assert_eq(e.type_, ParamType::Int)
  assert_true(e.patterns.length() > 0)
}
