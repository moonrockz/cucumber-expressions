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
let count = m.params[0].value // "42"
let place = m.params[1].value // "basket"
```

## Features

### Built-in Parameter Types

| Parameter  | Description                      | Example match       |
| ---------- | -------------------------------- | ------------------- |
| `{int}`    | Integers, optionally negative    | `42`, `-1`          |
| `{float}`  | Decimal and scientific notation  | `3.14`, `-1.5e10`   |
| `{string}` | Single- or double-quoted strings | `"hello"`, `'hi'`   |
| `{word}`   | A single word (no whitespace)    | `banana`            |
| `{}`       | Anonymous -- matches anything    | `whatever you want` |

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

Register your own named parameter types:

```moonbit skip nocheck
let registry = @cucumber-expressions.ParamTypeRegistry::default()
registry.register(
  "color",
  @cucumber-expressions.ParamType::Custom("color"),
  ["red", "green", "blue"],
)
let expr = @cucumber-expressions.Expression::parse_with_registry!(
  "the {color} ball",
  registry,
)
let m = expr.match_("the red ball").unwrap()
// m.params[0] => { value: "red", type_: Custom("color") }
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

This library implements the [Cucumber Expressions specification](https://github.com/cucumber/cucumber-expressions). The test suite includes ports of the official test cases covering tokenization, parsing, compilation, and end-to-end matching.

## Related Projects

- [moonrockz/gherkin](https://github.com/moonrockz/gherkin) -- Gherkin parser for MoonBit
- [moonrockz/cucumber-messages](https://github.com/moonrockz/cucumber-messages) -- Cucumber Messages protocol types for MoonBit

## License

Apache-2.0
