# moonrockz/cucumber-expressions

A [Cucumber Expressions](https://github.com/cucumber/cucumber-expressions) parser and matcher for MoonBit. The simpler alternative to regular expressions used in BDD step definitions.

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

## Built-in Parameter Types

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

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("{word} costs {float} dollars")
let m = expr.match_("coffee costs 4.50 dollars").unwrap()
// m.params[0].value => WordVal("coffee"), m.params[0].raw => "coffee"
// m.params[1].value => FloatVal(4.5), m.params[1].raw => "4.50"
```

## Optional Text

Parentheses mark text as optional. This is useful for plurals:

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("I have {int} cucumber(s)")
expr.match_("I have 1 cucumber")   // matches
expr.match_("I have 5 cucumbers")  // matches
```

## Alternation

Use `/` to match one of several alternatives:

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("I have a cat/dog")
expr.match_("I have a cat") // matches
expr.match_("I have a dog") // matches
```

## Custom Parameter Types

Register your own named parameter types with `ParamTypeRegistry`. An optional transformer converts matched text into a typed value:

```moonbit skip nocheck
let registry = @cucumber-expressions.ParamTypeRegistry::default()
registry.register(
  "color",
  @cucumber-expressions.ParamType::Custom("color"),
  [@cucumber-expressions.RegexPattern("red|green|blue")],
  transformer=@cucumber-expressions.Transformer::new(fn(groups) {
    @cucumber-expressions.ParamValue::CustomVal(@any.of(groups[0]))
  }),
)
let expr = @cucumber-expressions.Expression::parse_with_registry!(
  "the {color} ball",
  registry,
)
let m = expr.match_("the red ball").unwrap()
// m.params[0].value => CustomVal(<Any>), m.params[0].raw => "red"
```

## Match Result

`Expression::match_` returns a `Match?`. A successful match contains an array of `Param` values in order. Each `Param` has:

- `value` — typed `ParamValue` (pattern-matchable enum)
- `type_` — which `ParamType` matched
- `raw` — original matched text as `String`

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("{word} is {int}")
match expr.match_("MoonBit is 1") {
  Some(m) => {
    let name = m.params[0]  // { value: WordVal("MoonBit"), type_: Word, raw: "MoonBit" }
    let num  = m.params[1]  // { value: IntVal(1), type_: Int, raw: "1" }
  }
  None => println("no match")
}
```

## Error Handling

`Expression::parse` raises `ExpressionError`, a suberror with these variants:

| Variant                | Cause                              |
| ---------------------- | ---------------------------------- |
| `UnmatchedBrace`       | Missing closing `}`                |
| `UnmatchedParen`       | Missing closing `)`                |
| `CannotEscape`         | Invalid escape sequence            |
| `UnexpectedEscapeEnd`  | Backslash at end of expression     |
| `ValidationError`      | Structural errors (empty alternation, nested optionals, etc.) |
| `UnknownParameterType` | Unregistered `{name}` in expression |

```moonbit skip nocheck
try {
  let _ = @cucumber-expressions.Expression::parse!("{unknown}")
} catch {
  @cucumber-expressions.ExpressionError::UnknownParameterType(name=name, ..) =>
    println("Unknown parameter: " + name)
}
```

## License

Apache-2.0
