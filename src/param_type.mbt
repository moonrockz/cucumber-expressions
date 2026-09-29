///|
/// A regex pattern used for matching parameter types in cucumber expressions.
pub(all) struct RegexPattern {
  priv value : String
} derive(Debug, Eq)

///|
pub fn RegexPattern::RegexPattern(value : String) -> RegexPattern {
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
} derive(Debug, Eq, ToJson, FromJson)

///|
/// A registered parameter type entry with name, type, regex patterns, and transformer.
pub(all) struct ParamTypeEntry {
  name : String
  type_ : ParamType
  patterns : Array[RegexPattern]
  transformer : Transformer
} derive(Debug)

///|
pub impl Eq for ParamTypeEntry with fn equal(self, other) -> Bool {
  self.name == other.name &&
  self.type_ == other.type_ &&
  self.patterns == other.patterns
}

///|
/// Registry mapping parameter type names to their regex patterns.
pub(all) struct ParamTypeRegistry {
  priv entries : Array[ParamTypeEntry]
}

///|
pub fn ParamTypeRegistry::new() -> ParamTypeRegistry {
  { entries: [], }
}

///|
/// Create a registry with the 11 built-in parameter types pre-registered.
pub fn ParamTypeRegistry::default() -> ParamTypeRegistry {
  let reg = ParamTypeRegistry::new()
  // Integer types (all share the same regex patterns)
  let int_patterns = [RegexPattern("-?\\d+"), RegexPattern("\\d+")]
  reg.register(
    "int",
    ParamType::Int,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      IntVal(@string.parse_int(groups[0]))
    }),
  )
  reg.register(
    "long",
    ParamType::Long,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      LongVal(@string.parse_int64(groups[0]))
    }),
  )
  reg.register(
    "byte",
    ParamType::Byte,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      ByteVal(@string.parse_int(groups[0]).to_byte())
    }),
  )
  reg.register(
    "short",
    ParamType::Short,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      ShortVal(@string.parse_int(groups[0]))
    }),
  )
  reg.register(
    "biginteger",
    ParamType::BigInteger,
    int_patterns,
    transformer=Transformer::new(fn(groups) {
      BigIntegerVal(BigInt::from_string(groups[0]))
    }),
  )
  // Float types (all share the same regex pattern)
  let float_patterns = [
    RegexPattern("[+-]?(?:\\d+|\\d+\\.\\d*|\\d*\\.\\d+)(?:[eE][+-]?\\d+)?"),
  ]
  reg.register(
    "float",
    ParamType::Float,
    float_patterns,
    transformer=Transformer::new(fn(groups) raise {
      FloatVal(@string.parse_double(groups[0]))
    }),
  )
  reg.register(
    "double",
    ParamType::Double_,
    float_patterns,
    transformer=Transformer::new(fn(groups) raise {
      DoubleVal(@string.parse_double(groups[0]))
    }),
  )
  reg.register(
    "bigdecimal",
    ParamType::BigDecimal,
    float_patterns,
    transformer=Transformer::new(fn(groups) raise {
      match @decimal.Decimal::from_string(groups[0]) {
        Some(d) => BigDecimalVal(d)
        None => raise Failure::Failure("Invalid bigdecimal: " + groups[0])
      }
    }),
  )
  // String: unescape \" and \' like the reference implementation.
  // Other backslash sequences stay unchanged.
  reg.register(
    "string",
    ParamType::String_,
    [
      RegexPattern("\"([^\"\\\\]*(\\\\.[^\"\\\\]*)*)\""),
      RegexPattern("'([^'\\\\]*(\\\\.[^'\\\\]*)*)'"),
    ],
    transformer=Transformer::new(fn(groups) {
      StringVal(
        groups[0]
        .replace_all(old="\\\"", new="\"")
        .replace_all(old="\\'", new="'"),
      )
    }),
  )
  // Word (identity transformer)
  reg.register(
    "word",
    ParamType::Word,
    [RegexPattern("[^\\s]+")],
    transformer=Transformer::new(fn(groups) { WordVal(groups[0]) }),
  )
  reg.register(
    "",
    ParamType::Anonymous,
    [RegexPattern(".*")],
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
  transformer? : Transformer = Transformer::new(fn(groups) {
    ParamValue::CustomVal(@any.of(groups[0]))
  }),
) -> Unit {
  self.entries.push({ name, type_, patterns, transformer, })
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

///|
#deprecated
pub extend RegexPattern with Eq::{not_equal, equal}

///|
#deprecated
pub extend RegexPattern with @debug.Debug::{to_repr}

///|
pub extend ParamType with ToJson::{to_json}

///|
pub extend ParamType with @json.FromJson::{from_json}

///|
#deprecated
pub extend ParamType with Eq::{not_equal, equal}

///|
#deprecated
pub extend ParamType with @debug.Debug::{to_repr}

///|
#deprecated
pub extend ParamTypeEntry with Eq::{not_equal, equal}

///|
#deprecated
pub extend ParamTypeEntry with @debug.Debug::{to_repr}
