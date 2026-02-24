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
/// A registered parameter type entry with name, type, and regex patterns.
pub(all) struct ParamTypeEntry {
  name : String
  type_ : ParamType
  patterns : Array[RegexPattern]
} derive(Show, Eq)

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
) -> Unit {
  self.entries.push({ name, type_, patterns })
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
