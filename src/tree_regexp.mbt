// A port of TreeRegexp and GroupBuilder from the reference implementation.
// It finds the capture groups of a regex as a tree, so that each parameter
// gets its own group and the groups inside it.

///|
/// A capture group of a match, with the capture groups inside it.
///
/// `value`, `start` and `end` are `None` when the group did not match.
/// `start` and `end` are UTF-16 offsets into the matched text.
pub(all) struct Group {
  value : String?
  start : Int?
  end : Int?
  children : Array[Group]
} derive(Debug, Eq)

///|
/// The values that a transformer gets: the values of the child groups, or
/// the value of this group when it has no children.
pub fn Group::values(self : Group) -> Array[String?] {
  if self.children.is_empty() {
    [self.value]
  } else {
    self.children.map(g => g.value)
  }
}

///|
priv struct GroupBuilder {
  mut capturing : Bool
  mut source : String
  children : Array[GroupBuilder]
}

///|
fn GroupBuilder::new() -> GroupBuilder {
  { capturing: true, source: "", children: [], }
}

///|
fn GroupBuilder::build(
  self : GroupBuilder,
  results : Array[StringView?],
  next_index : Ref[Int],
) -> Group {
  let index = next_index.val
  next_index.val = index + 1
  let children = self.children.map(child => child.build(results, next_index))
  match results[index] {
    Some(view) => {
      let start = view.start_offset()
      {
        value: Some(view.to_owned()),
        start: Some(start),
        end: Some(start + view.length()),
        children,
      }
    }
    None => { value: None, start: None, end: None, children, }
  }
}

///|
/// True when the group that starts at `i` does not capture: `(?:X)`,
/// `(?=X)`, `(?!X)`, `(?<=X)` and `(?<!X)`. A named group `(?<name>X)`
/// captures.
fn is_non_capturing(source : Array[Char], i : Int) -> Bool {
  if i + 1 >= source.length() || source[i + 1] != '?' {
    return false
  }
  if i + 2 >= source.length() || source[i + 2] != '<' {
    return true
  }
  i + 3 < source.length() && (source[i + 3] == '=' || source[i + 3] == '!')
}

///|
fn create_group_builder(source : String) -> GroupBuilder {
  let chars = source.to_array()
  let stack : Array[GroupBuilder] = [GroupBuilder::new()]
  let starts : Array[Int] = []
  let mut escaping = false
  let mut char_class = false
  for i, c in chars {
    if c == '[' && !escaping {
      char_class = true
    } else if c == ']' && !escaping {
      char_class = false
    } else if c == '(' && !escaping && !char_class {
      let builder = GroupBuilder::new()
      if is_non_capturing(chars, i) {
        builder.capturing = false
      }
      starts.push(i)
      stack.push(builder)
    } else if c == ')' && !escaping && !char_class {
      guard stack.pop() is Some(builder) else {
        abort("unbalanced parentheses")
      }
      let parent = stack[stack.length() - 1]
      let start = starts.pop().unwrap_or(0)
      if builder.capturing {
        builder.source = String::from_array(chars[start + 1:i])
        parent.children.push(builder)
      } else {
        parent.children.push_iter(builder.children.iter())
      }
    }
    escaping = c == '\\' && !escaping
  }
  stack[0]
}

///|
/// A compiled regex that gives its capture groups as a tree.
priv struct TreeRegexp {
  source : String
  regexp : @regexp.Regexp
  group_builder : GroupBuilder
}

///|
fn TreeRegexp::new(source : String) -> TreeRegexp raise @regexp.RegexpError {
  {
    source,
    regexp: @regexp.compile(source.view()),
    group_builder: create_group_builder(source),
  }
}

///|
/// Match the text. The result is the group of the whole match.
fn TreeRegexp::match_(self : TreeRegexp, text : String) -> Group? {
  guard self.regexp.match_(text.view()) is Some(result) else { return None }
  Some(self.group_builder.build(result.results(), { val: 0, }))
}

///|
#deprecated
pub extend Group with Eq::{not_equal, equal}

///|
#deprecated
pub extend Group with @debug.Debug::{to_repr}
