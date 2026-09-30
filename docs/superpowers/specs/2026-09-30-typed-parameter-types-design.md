# Typed Parameter Types: Design

- Date: 2026-09-30
- Issue: [#31](https://github.com/moonrockz/cucumber-expressions/issues/31)
- Also fixes: [#29](https://github.com/moonrockz/cucumber-expressions/issues/29) (`@any` does not work on js and wasm-gc)
- Related: [#30](https://github.com/moonrockz/cucumber-expressions/issues/30) (tests on all targets), [#32](https://github.com/moonrockz/cucumber-expressions/issues/32) (codegen CLI, out of scope)
- Target release: 0.6.0

## Goal

Give custom parameter types the same features as the Java `ParameterType` API
([Cucumber docs](https://cucumber.io/docs/cucumber/cucumber-expressions/?lang=java#custom-parameter-types)):

- The transformer returns the user's own type, and the caller gets that type back without casts.
- The transformer's arity is checked against the capture groups of the regexps when the type is registered.

The untyped API (`register`, `Transformer`) stays. `CustomVal` and the `tonyfettes/any` dependency are removed (see "Removing `@any`").

## Background

- Today a custom type gives `CustomVal(@any.Any)`. The caller must cast with `@any`. A spike showed that `@any` casts are wrong on js and do not compile on wasm-gc (#29).
- MoonBit has no runtime reflection and cannot find the arity of a function value. The arity must come from the static type of the transformer.
- MoonBit traits have no associated types, so a ZIO-style `Zippable` (where the compiler computes the flat tuple type) is not possible. One builder type for each arity gives the same flat result.
- `and` is a MoonBit keyword, and `define` is reserved for future use. The names below avoid them.

## Scope

In scope:

1. A typed handle `ParameterType[T]`, and typed lookup on a match.
2. A flat "zipper" decoder `Captures1` to `Captures8`, with `define_with`.
3. `define1` to `define8`, which take a transformer with 1 to 8 `String` arguments.
4. Traits `ParameterTypeDef` and `FromGroups1` to `FromGroups8`, with `define_type1` to `define_type8`.
5. Remove `tonyfettes/any` and `ParamValue::CustomVal` (#29).
6. A `test:all` task that runs the tests on js, wasm-gc and native, and a CI job for it (#30).

Out of scope:

- The codegen CLI for `#cucumber.parameter_type` attributes (#32).
- Changes to moonspec ([moonrockz/moonspec#41](https://github.com/moonrockz/moonspec/issues/41)).

## Public API

### Typed handle

```moonbit
pub struct ParameterType[T] { /* private: name, typed slot */ }

pub fn[T] ParameterType::name(self : ParameterType[T]) -> String
pub fn[T] ParameterType::get(self : ParameterType[T], param : Param) -> T raise ParameterTypeError

pub fn[T] Match::get(self : Match, handle : ParameterType[T]) -> T raise ParameterTypeError
pub fn[T] Match::get_all(self : Match, handle : ParameterType[T]) -> Array[T]
```

### Captures (flat zipper)

`Captures` is an empty type. It only groups the functions that make parts, so that calls read `Captures::int()`.

```moonbit
pub enum Captures {}

// Parts: each decodes one capture group.
pub fn Captures::string() -> Captures1[String]
pub fn Captures::int() -> Captures1[Int]
pub fn Captures::long() -> Captures1[Int64]
pub fn Captures::float() -> Captures1[Double]
pub fn Captures::double() -> Captures1[Double]
pub fn[T] Captures::custom(f : (String) -> T raise) -> Captures1[T]
pub fn[T] Captures::optional(part : Captures1[T]) -> Captures1[T?]

// Zip and map, for each arity N in 1..8:
pub fn[A, B] Captures1::zip(self : Captures1[A], next : Captures1[B]) -> Captures2[A, B]
// ... CapturesN::zip(self, next : Captures1[X]) -> CapturesN+1[..., X]
pub fn[A, B, T] Captures2::map(self : Captures2[A, B], f : (A, B) -> T raise) -> Captures1[T]
// ... CapturesN::map(self, f : (A1, ..., AN) -> T raise) -> Captures1[T]

// Fold after 8:
pub fn[A, B, C, D, E, F, G, H, X] Captures8::zip(
  self : Captures8[A, B, C, D, E, F, G, H],
  next : Captures1[X],
) -> Captures2[(A, B, C, D, E, F, G, H), X]

// Registration with a decoder that gives one value:
pub fn[T] ParamTypeRegistry::define_with(
  self : ParamTypeRegistry,
  name : String,
  regexps : Array[RegexPattern],
  captures : Captures1[T],
  use_for_snippets? : Bool = true,
  prefer_for_regexp_match? : Bool = false,
) -> ParameterType[T] raise ParameterTypeError
```

`map` returns a `Captures1[T]` that keeps its group count. So mapped parts can be zipped into bigger decoders:

```moonbit
let person = Captures::string().zip(Captures::string()).zip(Captures::int())
  .map((first, last, age) => Person::new(first, last, age))       // 3 groups
let customer = person.zip(address).zip(contact)
  .map((p, a, c) => Customer::new(p, a, c))                       // 3 + 4 + 15 = 22 groups
```

### Fixed arity

```moonbit
pub fn[T] ParamTypeRegistry::define1(
  self : ParamTypeRegistry,
  name : String,
  regexps : Array[RegexPattern],
  transformer : (String) -> T raise,
  use_for_snippets? : Bool = true,
  prefer_for_regexp_match? : Bool = false,
) -> ParameterType[T] raise ParameterTypeError
// define2 ... define8: transformer : (String, ..., String) -> T raise
```

`defineN(name, regexps, f)` is the same as
`define_with(name, regexps, string().zip(...).zip(string()).map(f))` with N parts.

### Traits

```moonbit
pub(open) trait ParameterTypeDef {
  name() -> String
  regexps() -> Array[RegexPattern]
  use_for_snippets() -> Bool = _          // default: true
  prefer_for_regexp_match() -> Bool = _   // default: false
}

pub(open) trait FromGroups1 { from_groups(String) -> Self raise }
// ... FromGroups8 { from_groups(String, ..., String) -> Self raise }

pub fn[T : ParameterTypeDef + FromGroups1] ParamTypeRegistry::define_type1(
  self : ParamTypeRegistry,
) -> ParameterType[T] raise ParameterTypeError
// ... define_type8, bound FromGroupsN
```

The caller selects `T` with a type annotation:
`let color : ParameterType[Color] = registry.define_type1()`.
Trait methods are called as `ParameterTypeDef::name()` in the implementation, because `T::name()` is deprecated for a type parameter with more than one bound.

### New values and errors

```moonbit
pub enum ParamValue {
  ...
  TypedVal(TypedValue)   // new
}

pub struct TypedValue { /* private: type name, closure */ }
pub fn TypedValue::type_name(self : TypedValue) -> String

pub suberror ParameterTypeError {
  ...
  ArityMismatch(name~ : String, expected~ : Int, groups~ : Int)          // new
  InvalidRegexp(name~ : String, regexp~ : String)                        // new
  WrongParameterType(expected~ : String, actual~ : String)               // new
  MissingParameter(name~ : String)                                       // new
  AmbiguousParameter(name~ : String, count~ : Int)                       // new
  GroupDidNotMatch(name~ : String, index~ : Int)                         // new
}
```

## Removing `@any`

`tonyfettes/any` 0.1.5 does not work on js (wrong downcasts) or wasm-gc (even `Any::of` on a `String` fails WebAssembly validation). The default transformer of `register` calls `Any::of`, so every wasm-gc program that links this library fails today (#29).

`Yoorkin/any` works on all targets, but each custom type needs an `Anyable` implementation with an `extenum` payload. The typed handles in this spec give custom types with no such code, so the library drops dynamic values instead.

- Remove the `tonyfettes/any` import from `moon.mod` and `src/moon.pkg`.
- Remove `ParamValue::CustomVal`.
- `register` without a `transformer` gives `StringVal` of the first value (the first capture group, or the whole match). `Param.type_` is still `Custom(name)`.
- A `Transformer` that returned `CustomVal(@any.of(x))` must change to `define1` to `define8`, `define_with` or `define_type1` to `define_type8`, which give `TypedVal`.
- Tests that cast `CustomVal` are rewritten for `StringVal` or for typed handles.

## Behavior

### Counting capture groups

The group count of a type is the number of top-level capture groups of each regexp, added over all its regexps. It uses the same group tree as matching (`create_group_builder`), so `(` in a character class does not count and a named group `(?<n>...)` counts.

### Arity check

`n` is the number of values that the decoder takes (the sum of its parts).

- `n = 1`: the regexps may have 0 groups (the value is the whole match) or 1 group.
- `n > 1`: the group count must equal `n`. Groups of all regexps count, the same as the reference. For example, two regexps with one group each need `n = 2`.

A mismatch raises `ArityMismatch`, with the message
`The parameter type {coord} decodes 3 capture groups, but its regexps have 2`.
A regexp whose parentheses do not balance raises `InvalidRegexp`.
The checks of `register` (duplicate name, illegal name, no regexps, two preferential types with one regexp) also apply.

### Decoding

- Each part decodes one group value, in order.
- A group that did not match raises `GroupDidNotMatch`. `index` is the 1-based position of the group among the groups of the type.
- `optional(part)` gives `None` when none of the groups of `part` matched. When all of them matched, it gives `Some` of the decoded value. When only some matched, the part decodes as usual, so the first missing group raises `GroupDidNotMatch`.
- An error from a part (for example `int()` on `"x"`), from `custom`, or from `map` goes to the caller of `match_`.

### Storage

- A typed type gives `ParamValue::TypedVal(TypedValue)`, with `Param.type_ = Custom(name)`.
- `TypedValue` holds the value in a closure. The closure writes the value into the slot of the handle that created it. No casts are used, so this works on every target.
- `Show` for `TypedVal` prints `TypedVal(<name>)`.

### Reading

- `handle.get(param)` raises `WrongParameterType` when the param did not come from this handle. This includes a type with the same name in another registry.
- `match.get(handle)` raises `MissingParameter` when no param came from the handle, and `AmbiguousParameter` when more than one did.
- `match.get_all(handle)` gives all values from the handle, in order. The result can be empty.

### Other features

Typed types are ordinary registry entries:

- `use_for_snippets` and `prefer_for_regexp_match` apply, so `CucumberExpressionGenerator` and `RegularExpression` use them.
- A `RegularExpression` group that resolves to a typed type also gives a `TypedVal`.
- A `RegularExpression` group that did not match still gives `NullVal`.

## Structure

| File | Contents |
|---|---|
| `src/typed_value.mbt` | `TypedValue`, `ParameterType[T]`, `get` |
| `src/captures.mbt` | the parts, `optional`, group count |
| `src/captures_arity.mbt` | `Captures1` to `Captures8`, `zip`, `map`, fold (generated) |
| `src/typed_registry.mbt` | `define_with`, `define1` to `define8`, arity check |
| `src/parameter_type_def.mbt` | `ParameterTypeDef`, `FromGroups1` to `FromGroups8`, `define_type1` to `define_type8` (generated) |
| `src/expression.mbt` | `Match::get`, `Match::get_all` |
| `mise-tasks/codegen/captures` | generator for the two generated files |
| `mise-tasks/test/all` | tests on js, wasm-gc and native |
| `src/param_value.mbt` | remove `CustomVal`, add `TypedVal` |
| `src/param_type.mbt` | default transformer gives `StringVal` |

The generated files start with a "DO NOT EDIT" header. The generator follows the pattern of `mise-tasks/conformance/generate`.

## Compatibility

Breaking changes (0.6.0):

- New `ParamValue::TypedVal` variant.
- `ParamValue::CustomVal` and the `tonyfettes/any` dependency are removed.
- `register` without a transformer gives `StringVal`, not `CustomVal`.
- New `ParameterTypeError` cases.

Exhaustive `match` statements on these types need changes. The signatures of `register` and `Transformer` do not change. moonspec must also stop using `tonyfettes/any` ([moonrockz/moonspec#41](https://github.com/moonrockz/moonspec/issues/41)).

## Testing

Tests are written before the code. They cover:

- the arity check: 0 groups and 1 group with `n = 1`; `n` groups; several regexps; character classes; named groups; unbalanced parentheses;
- each part, `optional`, `custom`, `zip`, `map`, the fold at 9, 16 and 22 groups, and composition of mapped parts;
- `get`, `Match::get` and `Match::get_all`, with each error;
- a handle from one registry on a param from another registry;
- `define1` to `define8` and `define_type1` to `define_type8`;
- snippets and `RegularExpression` with typed types.

`mise run test:all` runs all tests on js, wasm-gc and native, and a CI job runs it. This is possible only after `@any` is removed, because any use of `tonyfettes/any` stops the wasm-gc test module from compiling.

## Documentation

- README: a section "Typed parameter types" with `define1`, the traits, `Captures` with composition, and `Match::get`. Remove `CustomVal` and `@any` from the custom parameter type examples.
- AGENTS.md: the new files.
