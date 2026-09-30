// A port of CucumberExpressionGenerator, ParameterTypeMatcher,
// CombinatorialGeneratedExpressionFactory and GeneratedExpression from the
// reference implementation.

///|
/// Makes Cucumber Expressions from step text, for example for the snippet
/// of an undefined step. It uses the parameter types with
/// `use_for_snippets`.
pub(all) struct CucumberExpressionGenerator {
  priv registry : ParamTypeRegistry
}

///|
pub fn CucumberExpressionGenerator::new(
  registry : ParamTypeRegistry,
) -> CucumberExpressionGenerator {
  { registry, }
}

///|
/// A Cucumber Expression made by `CucumberExpressionGenerator`.
pub(all) struct GeneratedExpression {
  /// The escaped text around the parameters: one more than the number of
  /// parameters.
  priv texts : Array[String]
  parameter_types : Array[ParamTypeEntry]
}

///|
/// The name and type of a parameter of a generated expression. `count` is
/// the number of times that the name is used up to and including this
/// parameter.
pub(all) struct ParameterInfo {
  type_ : ParamType
  name : String
  count : Int
} derive(Debug, Eq)

///|
/// The text of the generated expression.
pub fn GeneratedExpression::source(self : GeneratedExpression) -> String {
  let buf = StringBuilder()
  for i, text in self.texts {
    if i > 0 {
      buf.write_string("{\{self.parameter_types[i - 1].name}}")
    }
    buf.write_string(text)
  }
  buf.to_string()
}

///|
/// Parameter names for a generated function signature, for example
/// `["int", "int2"]`.
pub fn GeneratedExpression::parameter_names(
  self : GeneratedExpression,
) -> Array[String] {
  self
  .parameter_infos()
  .map(i => if i.count == 1 { i.name } else { i.name + i.count.to_string() })
}

///|
/// The name, type and count of each parameter.
pub fn GeneratedExpression::parameter_infos(
  self : GeneratedExpression,
) -> Array[ParameterInfo] {
  let usage : Map[String, Int] = Map([])
  self.parameter_types.map(t => {
    let count = usage.get(t.name).unwrap_or(0) + 1
    usage[t.name] = count
    { type_: t.type_, name: t.name, count, }
  })
}

///|
/// The generator makes at most this number of expressions.
let max_generated_expressions = 256

///|
/// Make the possible expressions for the text. The best expression is first.
pub fn CucumberExpressionGenerator::generate_expressions(
  self : CucumberExpressionGenerator,
  text : String,
) -> Array[GeneratedExpression] {
  let combinations : Array[Array[ParamTypeEntry]] = []
  let matchers = self.create_parameter_type_matchers(text)
  let texts : Array[String] = []
  let mut pos = 0
  while true {
    let matching = matchers.map(m => m.advance_to(pos)).filter(m => m.find())
    if matching.is_empty() {
      break
    }
    matching.sort_by(compare_matchers)
    let best = matching[0]
    let types : Array[ParamTypeEntry] = []
    for m in matching {
      if compare_matchers(m, best) == 0 &&
        !types.iter().any(t => t.name == m.entry.name) {
        types.push(m.entry)
      }
    }
    types.sort_by(compare_parameter_types)
    combinations.push(types)
    texts.push(escape_text(text.view(start_offset=pos, end_offset=best.start)))
    pos = best.start + best.length
    if pos >= text.length() {
      break
    }
  }
  texts.push(escape_text(text.view(start_offset=pos)))
  let expressions : Array[GeneratedExpression] = []
  fn permute(depth : Int, current : Array[ParamTypeEntry]) -> Unit {
    if expressions.length() >= max_generated_expressions {
      return
    }
    if depth == combinations.length() {
      expressions.push({ texts, parameter_types: current, })
      return
    }
    for entry in combinations[depth] {
      if expressions.length() >= max_generated_expressions {
        return
      }
      permute(depth + 1, [..current, entry])
    }
  }

  permute(0, [])
  expressions
}

///|
fn CucumberExpressionGenerator::create_parameter_type_matchers(
  self : CucumberExpressionGenerator,
  text : String,
) -> Array[ParameterTypeMatcher] {
  let matchers : Array[ParameterTypeMatcher] = []
  for entry in self.registry.entries {
    if !entry.use_for_snippets {
      continue
    }
    for pattern in entry.patterns {
      // A regexp that does not compile can not match.
      let regexp = @regexp.compile("(\{pattern.to_string()})") catch {
        _ => continue
      }
      matchers.push(ParameterTypeMatcher::new(entry, regexp, text, 0))
    }
  }
  matchers
}

///|
fn escape_text(s : StringView) -> String {
  s
  .to_owned()
  .replace_all(old="(", new="\\(")
  .replace_all(old="{", new="\\{")
  .replace_all(old="/", new="\\/")
}

///|
/// The first match of a parameter type regexp in the text, at or after a
/// position.
priv struct ParameterTypeMatcher {
  entry : ParamTypeEntry
  regexp : @regexp.Regexp
  text : String
  /// The start of the match, or -1 when there is no match.
  start : Int
  length : Int
}

///|
fn ParameterTypeMatcher::new(
  entry : ParamTypeEntry,
  regexp : @regexp.Regexp,
  text : String,
  position : Int,
) -> ParameterTypeMatcher {
  let result = regexp.execute(text.view(start_offset=position))
  match result.get(0) {
    Some(view) if result.matched() =>
      {
        entry,
        regexp,
        text,
        start: view.start_offset(),
        length: view.length(),
      }
    _ => { entry, regexp, text, start: -1, length: 0, }
  }
}

///|
fn ParameterTypeMatcher::advance_to(
  self : ParameterTypeMatcher,
  position : Int,
) -> ParameterTypeMatcher {
  for p in position..<self.text.length() {
    let matcher = ParameterTypeMatcher::new(
      self.entry,
      self.regexp,
      self.text,
      p,
    )
    if matcher.find() {
      return matcher
    }
  }
  ParameterTypeMatcher::new(
    self.entry,
    self.regexp,
    self.text,
    self.text.length(),
  )
}

///|
/// True when the match is not empty and is a full word.
fn ParameterTypeMatcher::find(self : ParameterTypeMatcher) -> Bool {
  if self.start < 0 || self.length == 0 {
    return false
  }
  let end = self.start + self.length
  (self.start == 0 || is_word_boundary(self.text.code_unit_at(self.start - 1))) &&
  (end == self.text.length() || is_word_boundary(self.text.code_unit_at(end)))
}

///|
/// Sort matchers by position, then longest match first.
fn compare_matchers(a : ParameterTypeMatcher, b : ParameterTypeMatcher) -> Int {
  if a.start != b.start {
    return a.start - b.start
  }
  b.length - a.length
}

///|
/// True for a separator, punctuation or symbol character (Unicode general
/// categories Z, P and S).
fn is_word_boundary(c : UInt16) -> Bool {
  let ch = c.to_int().unsafe_to_char()
  if ch.is_ascii() {
    // Z in ASCII is only the space; P and S are the ASCII punctuation.
    return ch == ' ' || ch.is_ascii_punctuation()
  }
  word_boundary_regexp.execute(ch.to_string()).matched()
}

///|
let word_boundary_regexp : @regexp.Regexp = @regexp.compile(
  "^[\\p{Z}\\p{P}\\p{S}]",
) catch {
  _ => abort("the word boundary regexp does not compile")
}

///|
#deprecated
pub extend ParameterInfo with Eq::{not_equal, equal}

///|
#deprecated
pub extend ParameterInfo with @debug.Debug::{to_repr}
