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
/// Create a registry with the 5 built-in parameter types pre-registered.
pub fn ParamTypeRegistry::default() -> ParamTypeRegistry {
  let reg = ParamTypeRegistry::new()
  reg.register("int", ParamType::Int, [
    RegexPattern("(?:-?\\d+)"),
    RegexPattern("(?:\\d+)"),
  ])
  reg.register("float", ParamType::Float, [
    RegexPattern("(?:[+-]?(?:\\d+|\\d+\\.\\d*|\\d*\\.\\d+)(?:[eE][+-]?\\d+)?)"),
  ])
  reg.register("string", ParamType::String_, [
    RegexPattern("\"([^\"\\\\]*(\\\\.[^\"\\\\]*)*)\""),
    RegexPattern("'([^'\\\\]*(\\\\.[^'\\\\]*)*)'"),
  ])
  reg.register("word", ParamType::Word, [RegexPattern("[^\\s]+")])
  reg.register("", ParamType::Anonymous, [RegexPattern(".*")])
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
