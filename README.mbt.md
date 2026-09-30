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

Each `Param` has `value`, `type_`, `raw` and `group`. `group` is the capture `Group` of the parameter, with `start` and `end` (UTF-16 offsets). `match_` raises the error of a transformer. `Expression::regexp()` gives the compiled regex.

## Built-in Parameter Types

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

Register your own named parameter types with `ParamTypeRegistry`. An optional transformer converts matched text into a typed value. The transformer gets the values of the capture groups of the regexp, or the whole match when the regexp has no capture groups. Without a transformer, the value is `CustomVal` of the first of these values.

`register` raises `ParameterTypeError` when the name is already registered, when the name has one of `{`, `}`, `(`, `)`, `\` or `/`, or when there are no regexps:

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

## Regular Expressions

`RegularExpression` matches a step with a regex. Each top-level capture group gives one parameter. The registry finds the type of a group from its regexp, so `(\d+)` gives `{int}`. A group with no registered type gives `AnonymousVal`, and an optional group that did not match gives `NullVal`.

```moonbit skip nocheck
let expr = @cucumber-expressions.RegularExpression::new("^I have (\\d+) cukes? in my (.+)$")
let m = expr.match_("I have 3 cukes in my belly").unwrap()
// m.params[0].value => IntVal(3), m.params[1].value => AnonymousVal("belly")
```

When more than one parameter type has the regexp of a group, `match_` raises `AmbiguousParameterTypeError`. Give one of the types `prefer_for_regexp_match=true` in `register` to fix this.

`ExpressionFactory` makes a `StepExpression` from a string. A string that starts with `^` or ends with `$`, or that starts and ends with `/`, is a regular expression. All other strings are Cucumber Expressions.

```moonbit skip nocheck
let factory = @cucumber-expressions.ExpressionFactory::new(registry)
let expr = factory.create_expression("^I have (\\d+) cukes$") // Regular(...)
let expr = factory.create_expression("I have {int} cukes")    // Cucumber(...)
```

## Snippet Generation

`CucumberExpressionGenerator` makes Cucumber Expressions from step text, for example for the snippet of an undefined step. It uses only the parameter types with `use_for_snippets=true` (the default for custom types; for the built-in types, only `{int}`, `{float}` and `{string}`).

```moonbit skip nocheck
let generator = @cucumber-expressions.CucumberExpressionGenerator::new(registry)
let generated = generator.generate_expressions("I have 2 cucumbers and 1.5 tomato")
// generated[0].source() => "I have {int} cucumbers and {float} tomato"
// generated[0].parameter_names() => ["int", "float"]
```

## Error Handling

`tokenize`, `parse_expression`, `compile_expression` and `Expression::parse` raise `ExpressionError`, a suberror with these variants:

| Variant                | Cause                              |
| ---------------------- | ---------------------------------- |
| `UnmatchedBrace`       | Missing closing `}`                |
| `UnmatchedParen`       | Missing closing `)`                |
| `CannotEscape`         | Invalid escape sequence            |
| `UnexpectedEscapeEnd`  | Backslash at end of expression     |
| `ValidationError`      | Structural errors (empty alternation, nested optionals, etc.) |
| `UnknownParameterType` | Unregistered `{name}` in expression |

Each error has `position()` (the code point offset of the problem) and
`message()`. One error has no column: when the compiled regex does not compile, the position is 0 and the message gives the regex error. The message uses the same format as the reference
implementation, for example:

```
This Cucumber Expression has a problem at column 3:

(a(b))
  ^-^
An optional may not contain an other optional.
If you did not mean to use an optional type you can use '\(' to escape the '('. For more complicated expressions consider using a regular expression instead.
```

```moonbit skip nocheck
try {
  let _ = @cucumber-expressions.Expression::parse!("{unknown}")
} catch {
  @cucumber-expressions.ExpressionError::UnknownParameterType(name~, ..) =>
    println("Unknown parameter: " + name)
}
```

## License

Apache-2.0
