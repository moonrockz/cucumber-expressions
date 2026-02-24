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

Each matched parameter is a `Param` with three fields:
- `value` — a typed `ParamValue` (e.g. `IntVal(42)`, `FloatVal(3.14)`)
- `type_` — the `ParamType` that matched (e.g. `Int`, `Float`)
- `raw` — the original matched text as a `String`

## Features

### Built-in Parameter Types

All 11 types from the Cucumber Expressions specification:

| Parameter        | Description                      | Example match       | Value type           |
| ---------------- | -------------------------------- | ------------------- | -------------------- |
| `{int}`          | Integers, optionally negative    | `42`, `-1`          | `IntVal(Int)`        |
| `{float}`        | Decimal and scientific notation  | `3.14`, `-1.5e10`   | `FloatVal(Double)`   |
| `{double}`       | Same as float                    | `3.14`, `1.5e10`    | `DoubleVal(Double)`  |
| `{long}`         | 64-bit integers                  | `9223372036854775807` | `LongVal(Int64)`   |
| `{byte}`         | Byte-range integers              | `127`, `255`        | `ByteVal(Byte)`      |
| `{short}`        | Short integers                   | `8080`              | `ShortVal(Int)`      |
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

Register your own named parameter types with an optional transformer:

```moonbit skip nocheck
let registry = @cucumber-expressions.ParamTypeRegistry::default()

// With transformer — returns typed custom value
registry.register(
  "color",
  @cucumber-expressions.ParamType::Custom("color"),
  [@cucumber-expressions.RegexPattern("red|green|blue")],
  transformer=@cucumber-expressions.Transformer::new(fn(groups) {
    @cucumber-expressions.ParamValue::CustomVal(@any.of(groups[0]))
  }),
)

// Without transformer — defaults to CustomVal wrapping the raw string
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
// m.params[0].value => CustomVal(<Any>), m.params[0].raw => "red"
```

### Error Handling

`Expression::parse` raises `ExpressionError` with descriptive messages and source positions:

| Variant                | Cause                                                         |
| ---------------------- | ------------------------------------------------------------- |
| `UnmatchedBrace`       | Missing closing `}`                                           |
| `UnmatchedParen`       | Missing closing `)`                                           |
| `CannotEscape`         | Invalid escape sequence                                       |
| `UnexpectedEscapeEnd`  | Backslash at end of expression                                |
| `ValidationError`      | Structural errors (empty alternation, nested optionals, etc.) |
| `UnknownParameterType` | Unregistered `{name}` in expression                           |

## Specification Compliance

This library implements the [Cucumber Expressions specification](https://github.com/cucumber/cucumber-expressions). All 11 built-in parameter types are supported with typed transformers. The test suite includes ports of the official test cases covering tokenization, parsing, compilation, and end-to-end matching.

## Related Projects

- [moonrockz/gherkin](https://github.com/moonrockz/gherkin) -- Gherkin parser for MoonBit
- [moonrockz/cucumber-messages](https://github.com/moonrockz/cucumber-messages) -- Cucumber Messages protocol types for MoonBit

## License

Apache-2.0
