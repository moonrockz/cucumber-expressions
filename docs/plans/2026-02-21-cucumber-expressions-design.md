# Cucumber Expressions for MoonBit — Design

**Date:** 2026-02-21
**Package:** `moonrockz/cucumber-expressions`
**Status:** Approved

## Overview

A standalone MoonBit implementation of the [Cucumber Expressions](https://github.com/cucumber/cucumber-expressions) specification. Cucumber Expressions are a simpler alternative to Regular Expressions for matching step definitions in BDD frameworks.

This package is a dependency of `moonrockz/moonspec` but has no dependency on it — it is a general-purpose pattern matching library usable independently.

## Reference

- [Cucumber Expressions spec](https://github.com/cucumber/cucumber-expressions)
- [cucumber-rs/cucumber-expressions](https://github.com/cucumber-rs/cucumber-expressions) (Rust reference)

## Expression Syntax

```
"I have {int} cucumbers"              — built-in parameter type
"I have {int} {word} cucumbers"       — multiple parameters
"I select {string}"                   — quoted string matching
"I have {int}/{int} cucumbers"        — literal slash
"I have {int} cucumber(s)"            — optional text
"I have {int} cucumber/gherkin"       — alternation
```

## Public API

### Core Types

```moonbit
pub struct Expression {
  // parsed expression AST
}

pub fn Expression::parse(expr : String) -> Expression!Error

pub fn Expression::match_(self, text : String) -> Match?

pub struct Match {
  params : Array[Param]
}

pub struct Param {
  value : String
  type_ : ParamType
}

pub enum ParamType {
  Int
  Float
  String_
  Word
  Anonymous
  Custom(String)
}
```

### Parameter Type Registry

```moonbit
pub struct ParamTypeRegistry {
  // ...
}

pub fn ParamTypeRegistry::new() -> ParamTypeRegistry

pub fn ParamTypeRegistry::register(
  self,
  name : String,
  regex : String,
  transform : (String) -> String,
) -> Unit

pub fn ParamTypeRegistry::default() -> ParamTypeRegistry
// Pre-registers: {int}, {float}, {string}, {word}, {}
```

### Expression Compilation

Cucumber Expressions are compiled to regex internally:

```
"I have {int} cucumber(s)"
  → regex: ^I have (-?\d+) cucumber(?:s)?$
  → param types: [Int]
```

## Package Structure

```
cucumber-expressions/
  src/
    expression.mbt       — Expression type, parse, match
    param_type.mbt        — ParamType, ParamTypeRegistry
    compiler.mbt          — expression → regex compilation
    ast.mbt               — expression AST nodes
    parser.mbt            — expression string → AST
    error.mbt             — error types
    expression_test.mbt   — blackbox tests
    expression_wbtest.mbt — whitebox tests
  moon.mod.json
  moon.pkg.json
  README.md
```

## Design Principles

- **Standalone** — no dependency on moonspec or gherkin
- **Spec-compliant** — pass the cucumber-expressions test suite
- **ADTs** — model the expression AST with algebraic data types
- **Total functions** — return `Result`/`Option`, never panic
- **TDD** — red-green-refactor with snapshot testing

## Built-in Parameter Types

| Expression | Regex | Description |
|---|---|---|
| `{int}` | `-?\d+` | Integer |
| `{float}` | `-?\d*\.?\d+` | Floating point |
| `{string}` | `"[^"]*"` or `'[^']*'` | Quoted string (quotes stripped) |
| `{word}` | `\S+` | Single word (no whitespace) |
| `{}` | `.*` | Anonymous, matches anything |
