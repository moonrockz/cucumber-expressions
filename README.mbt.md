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
let count = m.params[0].value // "42"
let place = m.params[1].value // "basket"
```

## Built-in Parameter Types

| Parameter  | Description                        | Example match      |
| ---------- | ---------------------------------- | ------------------ |
| `{int}`    | Integers, optionally negative      | `42`, `-1`         |
| `{float}`  | Decimal and scientific notation    | `3.14`, `-1.5e10`  |
| `{string}` | Single- or double-quoted strings   | `"hello"`, `'hi'`  |
| `{word}`   | A single word (no whitespace)      | `banana`           |
| `{}`       | Anonymous — matches anything       | `whatever you want` |

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("{word} costs {float} dollars")
let m = expr.match_("coffee costs 4.50 dollars").unwrap()
// m.params[0] => { value: "coffee", type_: Word }
// m.params[1] => { value: "4.50", type_: Float }
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

Register your own named parameter types with `ParamTypeRegistry`:

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

## Match Result

`Expression::match_` returns a `Match?`. A successful match contains an array of `Param` values in order:

```moonbit skip nocheck
let expr = @cucumber-expressions.Expression::parse!("{word} is {int}")
match expr.match_("MoonBit is 1") {
  Some(m) => {
    let name = m.params[0]  // { value: "MoonBit", type_: Word }
    let num  = m.params[1]  // { value: "1", type_: Int }
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
