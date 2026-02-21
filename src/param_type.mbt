///|
/// Parameter types supported by cucumber expressions.
pub(all) enum ParamType {
  Int
  Float
  String_
  Word
  Anonymous
  Custom(String)
} derive(Show, Eq, ToJson, FromJson)

///|
/// Registry mapping parameter type names to their regex patterns.
pub(all) struct ParamTypeRegistry {
  mut entries : Array[(String, ParamType, Array[String])]
}

///|
pub fn ParamTypeRegistry::new() -> ParamTypeRegistry {
  { entries: [] }
}

///|
/// Create a registry with the 5 built-in parameter types pre-registered.
pub fn ParamTypeRegistry::default() -> ParamTypeRegistry {
  let reg = ParamTypeRegistry::new()
  reg.register("int", ParamType::Int, ["(?:-?\\d+)", "(?:\\d+)"])
  reg.register(
    "float",
    ParamType::Float,
    [
      "(?:[+-]?(?:\\d+|\\d+\\.\\d*|\\d*\\.\\d+)(?:[eE][+-]?\\d+)?)",
    ],
  )
  reg.register(
    "string",
    ParamType::String_,
    [
      "\"([^\"\\\\]*(\\\\.[^\"\\\\]*)*)\"",
      "'([^'\\\\]*(\\\\.[^'\\\\]*)*)'",
    ],
  )
  reg.register("word", ParamType::Word, ["[^\\s]+"])
  reg.register("", ParamType::Anonymous, [".*"])
  reg
}

///|
pub fn ParamTypeRegistry::register(
  self : ParamTypeRegistry,
  name : String,
  type_ : ParamType,
  patterns : Array[String],
) -> Unit {
  self.entries.push((name, type_, patterns))
}

///|
pub fn ParamTypeRegistry::get(
  self : ParamTypeRegistry,
  name : String,
) -> (ParamType, Array[String])? {
  for entry in self.entries {
    if entry.0 == name {
      return Some((entry.1, entry.2))
    }
  }
  None
}
