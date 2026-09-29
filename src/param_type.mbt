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
  reg.add_entry(
    "int",
    ParamType::Int,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      IntVal(@string.parse_int(groups[0]))
    }),
  )
  reg.add_entry(
    "long",
    ParamType::Long,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      LongVal(@string.parse_int64(groups[0]))
    }),
  )
  reg.add_entry(
    "byte",
    ParamType::Byte,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      ByteVal(parse_int_in_range(groups[0], "byte", -128, 127).to_byte())
    }),
  )
  reg.add_entry(
    "short",
    ParamType::Short,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      ShortVal(parse_int_in_range(groups[0], "short", -32768, 32767))
    }),
  )
  reg.add_entry(
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
  reg.add_entry(
    "float",
    ParamType::Float,
    float_patterns,
    transformer=Transformer::new(fn(groups) raise {
      FloatVal(@string.parse_double(groups[0]))
    }),
  )
  reg.add_entry(
    "double",
    ParamType::Double_,
    float_patterns,
    transformer=Transformer::new(fn(groups) raise {
      DoubleVal(@string.parse_double(groups[0]))
    }),
  )
  reg.add_entry(
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
  // String: the transformer gets the double-quoted and the single-quoted
  // group. It unescapes \" and \' like the reference implementation.
  // Other backslash sequences stay unchanged.
  reg.add_entry(
    "string",
    ParamType::String_,
    [
      RegexPattern("\"([^\"\\\\]*(\\\\.[^\"\\\\]*)*)\""),
      RegexPattern("'([^'\\\\]*(\\\\.[^'\\\\]*)*)'"),
    ],
    transformer=Transformer::new(fn(groups) {
      let s = if groups[0] != "" {
        groups[0]
      } else {
        groups.get(1).unwrap_or("")
      }
      StringVal(
        s.replace_all(old="\\\"", new="\"").replace_all(old="\\'", new="'"),
      )
    }),
  )
  // Word (identity transformer)
  reg.add_entry(
    "word",
    ParamType::Word,
    [RegexPattern("[^\\s]+")],
    transformer=Transformer::new(fn(groups) { WordVal(groups[0]) }),
  )
  reg.add_entry(
    "",
    ParamType::Anonymous,
    [RegexPattern(".*")],
    transformer=Transformer::new(fn(groups) { AnonymousVal(groups[0]) }),
  )
  reg
}

///|
/// Register a parameter type.
///
/// Raises an error when the name is already registered, when the name has
/// one of the characters `{`, `}`, `(`, `)`, `\` or `/`, or when there
/// are no regexps.
pub fn ParamTypeRegistry::register(
  self : ParamTypeRegistry,
  name : String,
  type_ : ParamType,
  patterns : Array[RegexPattern],
  transformer? : Transformer = Transformer::new(fn(groups) {
    ParamValue::CustomVal(@any.of(groups[0]))
  }),
) -> Unit raise ParameterTypeError {
  if !is_valid_parameter_type_name(name) {
    raise IllegalParameterName(name~)
  }
  if patterns.is_empty() {
    raise NoRegexps(name~)
  }
  if self.get(name) is Some(_) {
    raise DuplicateParameterType(name~)
  }
  self.add_entry(name, type_, patterns, transformer~)
}

///|
fn ParamTypeRegistry::add_entry(
  self : ParamTypeRegistry,
  name : String,
  type_ : ParamType,
  patterns : Array[RegexPattern],
  transformer~ : Transformer,
) -> Unit {
  self.entries.push({ name, type_, patterns, transformer, })
}

///|
/// A name is valid when it has none of `{`, `}`, `(`, `)`, `\` and `/`,
/// after `\` is removed before the regex characters `[`, `]`, `$`, `.`,
/// `|`, `?`, `*` and `+`.
fn is_valid_parameter_type_name(name : String) -> Bool {
  let chars = name.to_array()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '\\' &&
      i + 1 < chars.length() &&
      "[]$.|?*+".contains_char(chars[i + 1]) {
      i = i + 2
      continue
    }
    if "{}()\\/".contains_char(c) {
      return false
    }
    i = i + 1
  }
  true
}

///|
fn parse_int_in_range(
  text : String,
  type_name : String,
  min : Int,
  max : Int,
) -> Int raise {
  let n = @string.parse_int(text)
  if n < min || n > max {
    fail("\{text} is out of range for {\{type_name}}: \{min}..\{max}")
  }
  n
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
