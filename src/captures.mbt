///|
/// Makes the parts of a `Captures` decoder. Each part decodes one capture
/// group. Join parts with `zip` and make a value with `map`:
///
/// ```moonbit nocheck
/// Captures::int().zip(Captures::string()).map((n, s) => Item::new(n, s))
/// ```
pub enum Captures {}

///|
/// A capture group that did not match, with its 1-based index.
priv suberror MissingGroup {
  MissingGroup(Int)
}

///|
/// A decoder of capture group values into one value of type `T`.
///
/// `count` is the number of capture groups it decodes. `decode` gets the
/// values of those groups and the 1-based index of the first one.
pub struct Captures1[T] {
  priv count : Int
  priv decode : (ArrayView[String?], Int) -> T raise
}

///|
/// A part that decodes one capture group with `parse`.
fn[T] Captures1::part(parse : (String) -> T raise) -> Captures1[T] {
  {
    count: 1,
    decode: (values, first) => {
      match values[0] {
        Some(text) => parse(text)
        None => raise MissingGroup(first)
      }
    },
  }
}

///|
/// The text of the capture group.
pub fn Captures::string() -> Captures1[String] {
  Captures1::part(text => text)
}

///|
/// The capture group as an `Int`.
pub fn Captures::int() -> Captures1[Int] {
  Captures1::part(text => @string.parse_int(text))
}

///|
/// The capture group as an `Int64`.
pub fn Captures::long() -> Captures1[Int64] {
  Captures1::part(text => @string.parse_int64(text))
}

///|
/// The capture group as a `Double`.
pub fn Captures::float() -> Captures1[Double] {
  Captures1::part(text => @string.parse_double(text))
}

///|
/// The capture group as a `Double`.
pub fn Captures::double() -> Captures1[Double] {
  Captures1::part(text => @string.parse_double(text))
}

///|
/// The capture group, converted by `f`.
pub fn[T] Captures::custom(f : (String) -> T raise) -> Captures1[T] {
  Captures1::part(f)
}

///|
/// `None` when none of the groups of `part` matched. Otherwise `part`
/// decodes as usual, so a group that did not match raises
/// `GroupDidNotMatch`.
pub fn[T] Captures::optional(part : Captures1[T]) -> Captures1[T?] {
  {
    count: part.count,
    decode: (values, first) => {
      if values.iter().all(v => v is None) {
        None
      } else {
        Some((part.decode)(values, first))
      }
    },
  }
}

///|
/// Change the value with `f`. The result decodes the same capture groups.
pub fn[A, T] Captures1::map(
  self : Captures1[A],
  f : (A) -> T raise,
) -> Captures1[T] {
  {
    count: self.count,
    decode: (values, first) => f((self.decode)(values, first)),
  }
}

///|
/// Decode the values of the capture groups of the parameter type `name`.
/// Raises `WrongGroupCount` when the number of values is not `count`.
fn[T] Captures1::run(
  self : Captures1[T],
  name : String,
  values : Array[String?],
) -> T raise {
  if values.length() != self.count {
    raise WrongGroupCount(name~, expected=self.count, actual=values.length())
  }
  (self.decode)(values[:], 1) catch {
    MissingGroup(index) => raise GroupDidNotMatch(name~, index~)
    e => raise e
  }
}
