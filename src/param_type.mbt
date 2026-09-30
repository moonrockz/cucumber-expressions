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
///
/// `use_for_snippets` is true when `CucumberExpressionGenerator` can use the
/// type. `prefer_for_regexp_match` is true when a `RegularExpression` uses
/// this type before other types with the same regexp.
pub(all) struct ParamTypeEntry {
  name : String
  type_ : ParamType
  patterns : Array[RegexPattern]
  transformer : Transformer
  use_for_snippets : Bool
  prefer_for_regexp_match : Bool
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
    use_for_snippets=true,
    prefer_for_regexp_match=true,
  )
  reg.add_entry(
    "long",
    ParamType::Long,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      LongVal(@string.parse_int64(groups[0]))
    }),
    use_for_snippets=false,
    prefer_for_regexp_match=false,
  )
  reg.add_entry(
    "byte",
    ParamType::Byte,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      ByteVal(parse_int_in_range(groups[0], "byte", -128, 127).to_byte())
    }),
    use_for_snippets=false,
    prefer_for_regexp_match=false,
  )
  reg.add_entry(
    "short",
    ParamType::Short,
    int_patterns,
    transformer=Transformer::new(fn(groups) raise {
      ShortVal(parse_int_in_range(groups[0], "short", -32768, 32767))
    }),
    use_for_snippets=false,
    prefer_for_regexp_match=false,
  )
  reg.add_entry(
    "biginteger",
    ParamType::BigInteger,
    int_patterns,
    transformer=Transformer::new(fn(groups) {
      BigIntegerVal(BigInt::from_string(groups[0]))
    }),
    use_for_snippets=false,
    prefer_for_regexp_match=false,
  )
  // Float types (all share the same regex pattern)
  let float_patterns = [
    RegexPattern("[-+]?(?:\\d+(?:\\.\\d+)?|\\.\\d+)(?:[eE][+-]?\\d+)?"),
  ]
  reg.add_entry(
    "float",
    ParamType::Float,
    float_patterns,
    transformer=Transformer::new(fn(groups) raise {
      FloatVal(@string.parse_double(groups[0]))
    }),
    use_for_snippets=true,
    prefer_for_regexp_match=false,
  )
  reg.add_entry(
    "double",
    ParamType::Double_,
    float_patterns,
    transformer=Transformer::new(fn(groups) raise {
      DoubleVal(@string.parse_double(groups[0]))
    }),
    use_for_snippets=false,
    prefer_for_regexp_match=false,
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
    use_for_snippets=false,
    prefer_for_regexp_match=false,
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
    use_for_snippets=true,
    prefer_for_regexp_match=false,
  )
  // Word (identity transformer)
  reg.add_entry(
    "word",
    ParamType::Word,
    [RegexPattern("[^\\s]+")],
    transformer=Transformer::new(fn(groups) { WordVal(groups[0]) }),
    use_for_snippets=false,
    prefer_for_regexp_match=false,
  )
  reg.add_entry(
    "",
    ParamType::Anonymous,
    [RegexPattern(".*")],
    transformer=Transformer::new(fn(groups) { AnonymousVal(groups[0]) }),
    use_for_snippets=false,
    prefer_for_regexp_match=true,
  )
  reg
}

///|
/// Register a parameter type.
///
/// Raises an error when the name is already registered, when the name has
/// one of the characters `{`, `}`, `(`, `)`, `\` or `/`, when there are no
/// regexps, or when a preferential type already has one of the regexps.
///
/// `use_for_snippets` (default `true`) lets `CucumberExpressionGenerator`
/// use the type. `prefer_for_regexp_match` (default `false`) makes a
/// `RegularExpression` use this type before other types with the same
/// regexp.
pub fn ParamTypeRegistry::register(
  self : ParamTypeRegistry,
  name : String,
  type_ : ParamType,
  patterns : Array[RegexPattern],
  transformer? : Transformer = Transformer::new(fn(groups) {
    ParamValue::CustomVal(@any.of(groups[0]))
  }),
  use_for_snippets? : Bool = true,
  prefer_for_regexp_match? : Bool = false,
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
  if prefer_for_regexp_match {
    for pattern in patterns {
      let regexp = pattern.to_string()
      if self.entries_with_regexp(regexp) is [first, ..] &&
        first.prefer_for_regexp_match {
        raise DuplicatePreferentialParameterType(
          regexp~,
          first=first.name,
          second=name,
        )
      }
    }
  }
  self.add_entry(
    name,
    type_,
    patterns,
    transformer~,
    use_for_snippets~,
    prefer_for_regexp_match~,
  )
}

///|
fn ParamTypeRegistry::add_entry(
  self : ParamTypeRegistry,
  name : String,
  type_ : ParamType,
  patterns : Array[RegexPattern],
  transformer~ : Transformer,
  use_for_snippets? : Bool = true,
  prefer_for_regexp_match? : Bool = false,
) -> Unit {
  self.entries.push({
    name,
    type_,
    patterns,
    transformer,
    use_for_snippets,
    prefer_for_regexp_match,
  })
}

///|
/// Order parameter types: preferential types first, then by name.
fn compare_parameter_types(a : ParamTypeEntry, b : ParamTypeEntry) -> Int {
  if a.prefer_for_regexp_match && !b.prefer_for_regexp_match {
    return -1
  }
  if b.prefer_for_regexp_match && !a.prefer_for_regexp_match {
    return 1
  }
  compare_text(a.name, b.name)
}

///|
/// Compare strings character by character. `String::compare` compares the
/// length first, which is not the order that the reference uses.
fn compare_text(a : String, b : String) -> Int {
  let length = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<length {
    let c = a.code_unit_at(i).to_int() - b.code_unit_at(i).to_int()
    if c != 0 {
      return c
    }
  }
  a.length() - b.length()
}

///|
/// The parameter types that have the regexp, in the order of
/// `compare_parameter_types`.
fn ParamTypeRegistry::entries_with_regexp(
  self : ParamTypeRegistry,
  regexp : String,
) -> Array[ParamTypeEntry] {
  let found = self.entries.filter(e => {
    e.patterns.iter().any(p => p.to_string() == regexp)
  })
  found.sort_by(compare_parameter_types)
  found
}

///|
/// Find the parameter type for a capture group of a regular expression.
///
/// `regexp` is the source of the capture group. `expression_regexp` and
/// `text` are used for the error message. Returns `None` when no type has
/// the regexp. Raises an error when more than one type has the regexp and
/// none of them is preferential.
pub fn ParamTypeRegistry::lookup_by_regexp(
  self : ParamTypeRegistry,
  regexp : String,
  expression_regexp : String,
  text : String,
) -> ParamTypeEntry? raise AmbiguousParameterTypeError {
  let found = self.entries_with_regexp(regexp)
  if found.is_empty() {
    return None
  }
  if found.length() > 1 && !found[0].prefer_for_regexp_match {
    let generated = CucumberExpressionGenerator::new(self).generate_expressions(
      text,
    )
    raise AmbiguousParameterType(
      regexp~,
      expression_regexp~,
      names=found.map(e => e.name),
      generated=generated.map(g => g.source()),
    )
  }
  Some(found[0])
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
    raise Failure::Failure(
      "\{text} is out of range for {\{type_name}}: \{min}..\{max}",
    )
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
