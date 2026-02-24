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
test "ParamTypeRegistry::default has 11 built-in types" {
  let reg = ParamTypeRegistry::default()
  inspect(reg.entries_view().length(), content="11")
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
    transformer: Transformer::new(fn(groups) {
      ParamValue::CustomVal(@any.of(groups[0]))
    }),
  }
  assert_eq(entry.name, "color")
  assert_eq(entry.type_, ParamType::Custom("color"))
  assert_eq(entry.patterns[0].to_string(), "red|blue|green")
}

///|
test "entries_view returns all registered types" {
  let reg = ParamTypeRegistry::default()
  let view = reg.entries_view()
  assert_eq(view.length(), 11)
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

///|
test "ParamValue::IntVal" {
  let v = ParamValue::IntVal(42)
  inspect(v, content="IntVal(42)")
}

///|
test "ParamValue::CustomVal wraps Any" {
  let v = ParamValue::CustomVal(@any.of("red"))
  match v {
    CustomVal(any) => {
      let s : String = any.to()
      assert_eq(s, "red")
    }
    _ => fail("expected CustomVal")
  }
}

///|
test "Registry get double returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("double") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Double_)
      inspect(entry.patterns.length(), content="1")
    }
    None => abort("expected double to be registered")
  }
}

///|
test "Registry get long returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("long") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Long)
      inspect(entry.patterns.length(), content="2")
    }
    None => abort("expected long to be registered")
  }
}

///|
test "Registry get byte returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("byte") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Byte)
      inspect(entry.patterns.length(), content="2")
    }
    None => abort("expected byte to be registered")
  }
}

///|
test "Registry get short returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("short") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::Short)
      inspect(entry.patterns.length(), content="2")
    }
    None => abort("expected short to be registered")
  }
}

///|
test "Registry get bigdecimal returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("bigdecimal") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::BigDecimal)
      inspect(entry.patterns.length(), content="1")
    }
    None => abort("expected bigdecimal to be registered")
  }
}

///|
test "Registry get biginteger returns correct type and patterns" {
  let reg = ParamTypeRegistry::default()
  match reg.get("biginteger") {
    Some(entry) => {
      assert_true(entry.type_ == ParamType::BigInteger)
      inspect(entry.patterns.length(), content="2")
    }
    None => abort("expected biginteger to be registered")
  }
}

///|
test "Registry int transformer produces IntVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("int").unwrap()
  let result = entry.transformer.call(["42"])
  assert_eq(result, ParamValue::IntVal(42))
}

///|
test "Registry float transformer produces FloatVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("float").unwrap()
  let result = entry.transformer.call(["3.14"])
  assert_eq(result, ParamValue::FloatVal(3.14))
}

///|
test "Registry double transformer produces DoubleVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("double").unwrap()
  let result = entry.transformer.call(["3.14"])
  assert_eq(result, ParamValue::DoubleVal(3.14))
}

///|
test "Registry long transformer produces LongVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("long").unwrap()
  let result = entry.transformer.call(["9223372036854775807"])
  assert_eq(result, ParamValue::LongVal(9223372036854775807L))
}

///|
test "Registry byte transformer produces ByteVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("byte").unwrap()
  let result = entry.transformer.call(["255"])
  assert_eq(result, ParamValue::ByteVal(b'\xFF'))
}

///|
test "Registry short transformer produces ShortVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("short").unwrap()
  let result = entry.transformer.call(["8080"])
  assert_eq(result, ParamValue::ShortVal(8080))
}

///|
test "Registry string transformer produces StringVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("string").unwrap()
  let result = entry.transformer.call(["hello"])
  assert_eq(result, ParamValue::StringVal("hello"))
}

///|
test "Registry word transformer produces WordVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("word").unwrap()
  let result = entry.transformer.call(["banana"])
  assert_eq(result, ParamValue::WordVal("banana"))
}

///|
test "Registry bigdecimal transformer produces BigDecimalVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("bigdecimal").unwrap()
  let result = entry.transformer.call(["99.99"])
  assert_eq(
    result,
    ParamValue::BigDecimalVal(@decimal.Decimal::from_string("99.99").unwrap()),
  )
}

///|
test "Registry biginteger transformer produces BigIntegerVal" {
  let reg = ParamTypeRegistry::default()
  let entry = reg.get("biginteger").unwrap()
  let result = entry.transformer.call(["123456789012345678901234567890"])
  assert_eq(
    result,
    ParamValue::BigIntegerVal(
      BigInt::from_string("123456789012345678901234567890"),
    ),
  )
}

///|
test "ParamTypeEntry with transformer" {
  let transformer = Transformer::new(fn(groups) raise {
    ParamValue::IntVal(@strconv.parse_int(groups[0]))
  })
  let entry : ParamTypeEntry = {
    name: "test",
    type_: ParamType::Int,
    patterns: [RegexPattern("\\d+")],
    transformer,
  }
  assert_eq(entry.name, "test")
  let result = entry.transformer.call(["42"])
  assert_eq(result, ParamValue::IntVal(42))
}
