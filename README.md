# cucumber-expressions

[![CI](https://github.com/moonrockz/cucumber-expressions/actions/workflows/ci.yml/badge.svg)](https://github.com/moonrockz/cucumber-expressions/actions/workflows/ci.yml)

A [Cucumber Expressions](https://github.com/cucumber/cucumber-expressions) parser and matcher for [MoonBit](https://www.moonbitlang.com/). The simpler alternative to regular expressions used in BDD step definitions.

## Installation

```bash
moon add moonrockz/cucumber-expressions
```

## Quick Start

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("I have {int} cucumber(s) in my {word}")
let m = expr.match_("I have 42 cucumbers in my basket").unwrap()
// m.params[0].value => IntVal(42), m.params[0].raw => "42"
// m.params[1].value => WordVal("basket"), m.params[1].raw => "basket"
```

Each matched parameter is a `Param` with four fields:
- `value` — a typed `ParamValue` (e.g. `IntVal(42)`, `FloatVal(3.14)`)
- `type_` — the `ParamType` that matched (e.g. `Int`, `Float`)
- `raw` — the original matched text as a `String`
- `group` — the capture `Group` of the parameter, with `start` and `end` (UTF-16 offsets) and the groups inside it

`match_` raises the error of a transformer, for example when `{int}` matches a number that is too large. `Expression::regexp()` gives the compiled regex.

## Features

### Built-in Parameter Types

All 11 types from the Cucumber Expressions specification:

| Parameter        | Description                      | Example match       | Value type           |
| ---------------- | -------------------------------- | ------------------- | -------------------- |
| `{int}`          | Integers, optionally negative    | `42`, `-1`          | `IntVal(Int)`        |
| `{float}`        | Decimal and scientific notation  | `3.14`, `-1.5e10`   | `FloatVal(Double)`   |
| `{double}`       | Same as float                    | `3.14`, `1.5e10`    | `DoubleVal(Double)`  |
| `{long}`         | 64-bit integers                  | `9223372036854775807` | `LongVal(Int64)`   |
| `{byte}`         | Integers from -128 to 127        | `127`, `-128`       | `ByteVal(Byte)` (two's complement) |
| `{short}`        | Integers from -32768 to 32767    | `8080`              | `ShortVal(Int)`      |
| `{bigdecimal}`   | Arbitrary-precision decimals     | `99.99`             | `BigDecimalVal(Decimal)` |
| `{biginteger}`   | Arbitrary-precision integers     | `12345678901234567890` | `BigIntegerVal(BigInt)` |
| `{string}`       | Single- or double-quoted strings | `"hello"`, `'hi'`   | `StringVal(String)`  |
| `{word}`         | A single word (no whitespace)    | `banana`            | `WordVal(String)`    |
| `{}`             | Anonymous — matches anything     | `whatever you want` | `AnonymousVal(String)` |

### Optional Text

Parentheses mark text as optional, useful for plurals:

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("I have {int} cucumber(s)")
expr.match_("I have 1 cucumber")   // matches
expr.match_("I have 5 cucumbers")  // matches
```

### Alternation

Use `/` to match one of several alternatives:

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("I have a cat/dog")
expr.match_("I have a cat") // matches
expr.match_("I have a dog") // matches
```

### Custom Parameter Types

Register your own named parameter types with an optional transformer. The transformer gets the values of the capture groups of the regexp, or the whole match when the regexp has no capture groups. A group that did not match gives an empty string. Without a transformer, the value is `StringVal` of the first of these values.

`register` raises `ParameterTypeError` when the name is already registered, when the name has one of `{`, `}`, `(`, `)`, `\` or `/`, or when there are no regexps:

```moonbit skip nocheck
let registry = @cucumber-expressions.ParamTypeRegistry::default()

// With transformer — returns typed custom value
registry.register(
  "color",
  @cucumber-expressions.ParamType::Custom("color"),
  [@cucumber-expressions.RegexPattern("red|green|blue")],
  transformer=@cucumber-expressions.Transformer::new(fn(groups) {
    @cucumber-expressions.ParamValue::StringVal(groups[0].to_upper())
  }),
)

// Without transformer — gives StringVal of the match
registry.register(
  "direction",
  @cucumber-expressions.ParamType::Custom("direction"),
  [@cucumber-expressions.RegexPattern("north|south|east|west")],
)

let expr = @cucumber-expressions.Expression::parse_with_registry!(
  "the {color} ball",
  registry,
)
let m = expr.match_("the red ball").unwrap()
// m.params[0].value => StringVal("RED"), m.params[0].raw => "red"
```

### Typed Parameter Types

A typed parameter type gives values of your own type, with no casts. Registration returns a `ParameterType[T]` handle; use it to read the value. Registration also checks the number of capture groups: a transformer with `n` arguments needs `n` top-level capture groups (added over all regexps), and a transformer with 1 argument also accepts a regexp with no groups (it then gets the whole match).

#### `define1` to `define8`

```moonbit skip nocheck
let registry = @cucumber-expressions.ParamTypeRegistry::default()
let color = registry.define1("color", [@cucumber-expressions.RegexPattern("red|green|blue")], Color::new)
let coord = registry.define2("coord", [@cucumber-expressions.RegexPattern("(\\d+),(\\d+)")], (x, y) => {
  Coord::new(@string.parse_int(x), @string.parse_int(y))
})
let expr = @cucumber-expressions.Expression::parse_with_registry("a {color} ball at {coord}", registry)
let m = expr.match_("a red ball at 3,4").unwrap()
let c : Color = color.get(m.params[0])  // raises if params[0] is not a {color}
let p : Coord = m.get(coord)            // the only {coord} of the match
let all : Array[Color] = m.get_all(color)
```

#### `Captures`: typed parts with `zip` and `map`

`Captures` decodes each capture group with a typed part (`string()`, `int()`, `long()`, `float()`, `double()`, `custom(f)`, `optional(part)`). `zip` joins parts into a flat tuple, and `map` makes one value. Register it with `define_with`:

```moonbit skip nocheck
let seat = registry.define_with(
  "seat",
  [@cucumber-expressions.RegexPattern("(\\d+)-(\\w+)-(\\d+)")],
  @cucumber-expressions.Captures::int()
    .zip(@cucumber-expressions.Captures::string())
    .zip(@cucumber-expressions.Captures::int())
    .map((row, block, number) => Seat::new(row, block, number)),
)
```

A group that did not match raises `GroupDidNotMatch`, unless its part is wrapped in `Captures::optional`, which gives `None`.

`map` returns a decoder that can be zipped again, so large types are built from named parts:

```moonbit skip nocheck
let person = @cucumber-expressions.Captures::string().zip(@cucumber-expressions.Captures::string()).map((first, last) => Person::new(first, last))
let customer = person.zip(address).zip(contact).map((p, a, c) => Customer::new(p, a, c))
```

After 8 values, `zip` folds the 8 values into one tuple and continues, so there is no hard limit.

#### Traits: `ParameterTypeDef` and `FromGroups1` to `FromGroups8`

```moonbit skip nocheck
impl @cucumber-expressions.ParameterTypeDef for Color with name() { "color" }
impl @cucumber-expressions.ParameterTypeDef for Color with regexps() {
  [@cucumber-expressions.RegexPattern("red|green|blue")]
}
impl @cucumber-expressions.FromGroups1 for Color with from_groups(name) { Color::new(name) }

let color : @cucumber-expressions.ParameterType[Color] = registry.define_type1()
```

`use_for_snippets` (default `true`) and `prefer_for_regexp_match` (default `false`) can be overridden in the `ParameterTypeDef` implementation.

### Regular Expressions

`RegularExpression` matches a step with a regex. Each top-level capture group gives one parameter. The registry finds the type of a group from its regexp, so `(\d+)` gives `{int}`. A group with no registered type gives `AnonymousVal`, and an optional group that did not match gives `NullVal`.

```moonbit skip nocheck
let expr = @cucumber-expressions.RegularExpression::new("^I have (\\d+) cukes? in my (.+)$")
let m = expr.match_("I have 3 cukes in my belly").unwrap()
// m.params[0].value => IntVal(3), m.params[1].value => AnonymousVal("belly")
```

When more than one parameter type has the regexp of a group, `match_` raises `AmbiguousParameterTypeError`. Give one of the types `prefer_for_regexp_match=true` in `register` to fix this. The built-in `{int}`, `{double}` and `{}` are preferential, so `(\d+)` gives `{int}` and a group with the float regexp gives `{double}`, the same as the Java implementation.

`ExpressionFactory` makes a `StepExpression` from a string. A string that starts with `^` or ends with `$`, or that starts and ends with `/`, is a regular expression. All other strings are Cucumber Expressions.

```moonbit skip nocheck
let factory = @cucumber-expressions.ExpressionFactory::new(registry)
let expr = factory.create_expression("^I have (\\d+) cukes$") // Regular(...)
let expr = factory.create_expression("I have {int} cukes")    // Cucumber(...)
```

### Snippet Generation

`CucumberExpressionGenerator` makes Cucumber Expressions from step text, for example for the snippet of an undefined step. It uses only the parameter types with `use_for_snippets=true` (the default for custom types; for the built-in types, only `{int}`, `{float}` and `{string}`).

```moonbit skip nocheck
let generator = @cucumber-expressions.CucumberExpressionGenerator::new(registry)
let generated = generator.generate_expressions("I have 2 cucumbers and 1.5 tomato")
// generated[0].source() => "I have {int} cucumbers and {float} tomato"
// generated[0].parameter_names() => ["int", "float"]
```

### Error Handling

`tokenize`, `parse_expression`, `compile_expression` and `Expression::parse` raise `ExpressionError`. `tokenize` and `parse_expression` raise only the syntax errors; the structure errors come when the expression compiles:

| Variant                | Cause                                                         |
| ---------------------- | ------------------------------------------------------------- |
| `UnmatchedBrace`       | Missing closing `}`                                           |
| `UnmatchedParen`       | Missing closing `)`                                           |
| `CannotEscape`         | Invalid escape sequence                                       |
| `UnexpectedEscapeEnd`  | Backslash at end of expression                                |
| `ValidationError`      | Structural errors (empty alternation, nested optionals, etc.) |
| `UnknownParameterType` | Unregistered `{name}` in expression                           |

Each error has `position()` (the code point offset of the problem) and
`message()`. One error has no column: when the compiled regex does not compile (for example because a custom parameter type has a regexp that is not valid), the position is 0 and the message gives the regex error. The message uses the same format as the reference
implementation, for example:

```
This Cucumber Expression has a problem at column 3:

(a(b))
  ^-^
An optional may not contain an other optional.
If you did not mean to use an optional type you can use '\(' to escape the '('. For more complicated expressions consider using a regular expression instead.
```

## Specification Compliance

This library implements the [Cucumber Expressions specification](https://github.com/cucumber/cucumber-expressions). All 11 built-in parameter types are supported with typed transformers. The conformance suite (`src/conformance_wbtest.mbt`) is generated from the official [testdata](https://github.com/cucumber/cucumber-expressions/tree/main/testdata) and covers tokenization, parsing, compilation, and end-to-end matching. Known gaps are skipped in the suite and tracked as [issues](https://github.com/moonrockz/cucumber-expressions/issues).

## Related Projects

- [moonrockz/gherkin](https://github.com/moonrockz/gherkin) -- Gherkin parser for MoonBit
- [moonrockz/cucumber-messages](https://github.com/moonrockz/cucumber-messages) -- Cucumber Messages protocol types for MoonBit

## License

Apache-2.0
