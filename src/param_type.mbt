///|
/// A regex pattern used for matching parameter types in cucumber expressions.
pub(all) struct RegexPattern {
  priv value : String

  fn new(value : String) -> RegexPattern
} derive(Show, Eq)

///|
fn RegexPattern::new(value : String) -> RegexPattern {
  { value, }
}

///|
pub fn RegexPattern::to_string(self : RegexPattern) -> String {
  self.value
}

///|
/// Parameter types supported by cucumber expressions.
pub(all) enum ParamType {
  Int
  Float
  String_
  Word
  Anonymous
  Double_
  Long
  Byte
  Short
  BigDecimal
  BigInteger
  Custom(String)
} derive(Show, Eq, ToJson, FromJson)

///|
/// A registered parameter type entry with name, type, regex patterns, and transformer.
pub(all) struct ParamTypeEntry {
  name : String
  type_ : ParamType
  patterns : Array[RegexPattern]
  transformer : Transformer
}

///|
impl Show for ParamTypeEntry with output(self, logger) {
  logger.write_string("ParamTypeEntry { name: \{self.name}, type_: \{self.type_}, patterns: \{self.patterns} }")
}

///|
impl Eq for ParamTypeEntry with equal(self, other) -> Bool {
  self.name == other.name && self.type_ == other.type_ && self.patterns == other.patterns
}

///|
/// Registry mapping parameter type names to their regex patterns.
pub(all) struct ParamTypeRegistry {
  priv entries : Array[ParamTypeEntry]
}

///|
pub fn ParamTypeRegistry::new() -> ParamTypeRegistry {
  { entries: [] }
}

///|
/// Create a registry with the 11 built-in parameter types pre-registered.
pub fn ParamTypeRegistry::default() -> ParamTypeRegistry {
  let reg = ParamTypeRegistry::new()
  // Integer types (all share the same regex patterns)
  let int_patterns = [
    RegexPattern("(?:-?\\d+)"),
    RegexPattern("(?:\\d+)"),
  ]
  reg.register("int", ParamType::Int, int_patterns,
    transformer=Transformer::new(fn(groups) raise { IntVal(@strconv.parse_int(groups[0])) }),
  )
  reg.register("long", ParamType::Long, int_patterns,
    transformer=Transformer::new(fn(groups) raise { LongVal(@strconv.parse_int64(groups[0])) }),
  )
  reg.register("byte", ParamType::Byte, int_patterns,
    transformer=Transformer::new(fn(groups) raise { ByteVal(@strconv.parse_int(groups[0]).to_byte()) }),
  )
  reg.register("short", ParamType::Short, int_patterns,
    transformer=Transformer::new(fn(groups) raise { ShortVal(@strconv.parse_int(groups[0])) }),
  )
  reg.register("biginteger", ParamType::BigInteger, int_patterns,
    transformer=Transformer::new(fn(groups) { BigIntegerVal(BigInt::from_string(groups[0])) }),
  )
  // Float types (all share the same regex pattern)
  let float_patterns = [
    RegexPattern("(?:[+-]?(?:\\d+|\\d+\\.\\d*|\\d*\\.\\d+)(?:[eE][+-]?\\d+)?)"),
  ]
  reg.register("float", ParamType::Float, float_patterns,
    transformer=Transformer::new(fn(groups) raise { FloatVal(@strconv.parse_double(groups[0])) }),
  )
  reg.register("double", ParamType::Double_, float_patterns,
    transformer=Transformer::new(fn(groups) raise { DoubleVal(@strconv.parse_double(groups[0])) }),
  )
  reg.register("bigdecimal", ParamType::BigDecimal, float_patterns,
    transformer=Transformer::new(fn(groups) raise {
      match @decimal.Decimal::from_string(groups[0]) {
        Some(d) => BigDecimalVal(d)
        None => raise Failure("Invalid bigdecimal: " + groups[0])
      }
    }),
  )
  // String and word (identity transformers)
  reg.register("string", ParamType::String_, [
    RegexPattern("\"([^\"\\\\]*(\\\\.[^\"\\\\]*)*)\""),
    RegexPattern("'([^'\\\\]*(\\\\.[^'\\\\]*)*)'"),
  ],
    transformer=Transformer::new(fn(groups) { StringVal(groups[0]) }),
  )
  reg.register("word", ParamType::Word, [RegexPattern("[^\\s]+")],
    transformer=Transformer::new(fn(groups) { WordVal(groups[0]) }),
  )
  reg.register("", ParamType::Anonymous, [RegexPattern(".*")],
    transformer=Transformer::new(fn(groups) { AnonymousVal(groups[0]) }),
  )
  reg
}

///|
pub fn ParamTypeRegistry::register(
  self : ParamTypeRegistry,
  name : String,
  type_ : ParamType,
  patterns : Array[RegexPattern],
  transformer~ : Transformer = Transformer::new(fn(groups) { ParamValue::CustomVal(@any.of(groups[0])) }),
) -> Unit {
  self.entries.push({ name, type_, patterns, transformer })
}

///|
pub fn ParamTypeRegistry::get(
  self : ParamTypeRegistry,
  name : String,
) -> ParamTypeEntry? {
  for entry in self.entries {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
/// Read-only view of all registered parameter type entries.
pub fn ParamTypeRegistry::entries_view(
  self : ParamTypeRegistry,
) -> ArrayView[ParamTypeEntry] {
  self.entries[:]
}
