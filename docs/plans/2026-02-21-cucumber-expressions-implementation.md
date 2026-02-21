# Cucumber Expressions Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a spec-compliant Cucumber Expressions parser and matcher for MoonBit.

**Architecture:** Parse expressions into an AST, then compile the AST to regex for matching. Use a two-phase parse: permissive grammar first, then validate constraints (for better error messages). Built-in and custom parameter types map to regex patterns via a registry.

**Tech Stack:** MoonBit, moonbitlang/x standard library, mise for task running, mooncakes.io for publishing.

---

### Task 1: Project Scaffolding

**Files:**
- Create: `moon.mod.json`
- Create: `src/moon.pkg.json`
- Create: `.gitignore`
- Create: `CLAUDE.md`
- Create: `.mise.toml`
- Create: `mise-tasks/test/unit`

**Step 1: Create moon.mod.json**

```json
{
  "name": "moonrockz/cucumber-expressions",
  "version": "0.1.0",
  "deps": {
    "moonbitlang/x": "0.4.40"
  },
  "readme": "README.mbt.md",
  "repository": "https://github.com/moonrockz/cucumber-expressions",
  "license": "Apache-2.0",
  "keywords": ["cucumber", "expressions", "bdd", "testing", "gherkin"],
  "description": "Cucumber Expressions parser and matcher for MoonBit",
  "source": "src"
}
```

**Step 2: Create src/moon.pkg.json**

```json
{
  "import": [
    "moonbitlang/core/json"
  ]
}
```

**Step 3: Create .gitignore**

```
.DS_Store
_build/
target/
.mooncakes/
.moonagent/
__pycache__/
*.py[cod]
.venv/
```

**Step 4: Create CLAUDE.md**

```markdown
# Claude Code Project Instructions

## Commit Messages

All commits MUST use **Conventional Commits** format:

```
type(scope): description
```

Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `style`

## Build & Test

Use **`mise run`** for all operations:

```bash
mise run test:unit        # MoonBit unit tests
```

## Mise Tasks

Tasks are **file-based scripts** in `mise-tasks/`. Never add inline `[tasks]` to `.mise.toml`.
```

**Step 5: Create .mise.toml**

```toml
[tools]
"moonbit" = "latest"
```

**Step 6: Create mise-tasks/test/unit**

```bash
#!/usr/bin/env bash
#MISE description="Run MoonBit unit tests"
set -euo pipefail
moon test
```

**Step 7: Create a minimal src/lib.mbt to make the project compile**

```moonbit
///|
/// Cucumber Expressions for MoonBit.
///
/// A parser and matcher for Cucumber Expressions, the simpler alternative
/// to regular expressions used in BDD step definitions.
pub fn version() -> String {
  "0.1.0"
}
```

**Step 8: Run moon check to verify project compiles**

Run: `moon check`
Expected: Success, no errors

**Step 9: Commit**

```bash
git add -A
git commit -m "chore: project scaffolding with moon.mod.json and mise tasks"
```

---

### Task 2: AST Types

**Files:**
- Create: `src/ast.mbt`
- Create: `src/ast_wbtest.mbt`

**Step 1: Write tests for AST node construction**

Create `src/ast_wbtest.mbt`:

```moonbit
///|
test "TextNode creation" {
  let node = TextNode("hello")
  inspect(node, content="TextNode(\"hello\")")
}

///|
test "ParameterNode creation" {
  let node = ParameterNode("int")
  inspect(node, content="ParameterNode(\"int\")")
}

///|
test "OptionalNode creation" {
  let node = OptionalNode([TextNode("blind")])
  inspect(node, content="OptionalNode([TextNode(\"blind\")])")
}

///|
test "AlternationNode creation" {
  let node = AlternationNode([
    [TextNode("cat")],
    [TextNode("dog")],
  ])
  inspect(node, content="AlternationNode([[TextNode(\"cat\")], [TextNode(\"dog\")]])")
}

///|
test "ExpressionNode creation" {
  let node = ExpressionNode([
    TextNode("I have "),
    ParameterNode("int"),
    TextNode(" cucumbers"),
  ])
  inspect(node, content="ExpressionNode([TextNode(\"I have \"), ParameterNode(\"int\"), TextNode(\" cucumbers\")])")
}
```

**Step 2: Run tests to verify they fail**

Run: `mise run test:unit`
Expected: FAIL — types not defined yet

**Step 3: Implement AST types**

Create `src/ast.mbt`:

```moonbit
///|
/// A single node in a cucumber expression AST.
pub(all) enum Node {
  /// Literal text (non-whitespace or whitespace).
  TextNode(String)
  /// A parameter reference like `{int}` or `{string}`.
  ParameterNode(String)
  /// Optional text like `(blind)`. Contains child nodes.
  OptionalNode(Array[Node])
  /// Alternation like `cat/dog`. Each alternative is an array of nodes.
  AlternationNode(Array[Array[Node]])
  /// Top-level expression node containing all children.
  ExpressionNode(Array[Node])
} derive(Show, Eq, ToJson, FromJson)
```

**Step 4: Update tests to use Node:: prefix and run**

Update `src/ast_wbtest.mbt` to use `Node::TextNode(...)` etc.

Run: `mise run test:unit`
Expected: PASS

**Step 5: Commit**

```bash
git add src/ast.mbt src/ast_wbtest.mbt
git commit -m "feat(ast): define expression AST node types"
```

---

### Task 3: Error Types

**Files:**
- Create: `src/error.mbt`
- Create: `src/error_wbtest.mbt`

**Step 1: Write tests for error construction**

```moonbit
///|
test "ExpressionError: unmatched opening brace" {
  let err : ExpressionError = UnmatchedBrace(position=5, message="{ does not have a matching }")
  inspect(err.message(), content="{ does not have a matching }")
}

///|
test "ExpressionError: cannot escape" {
  let err : ExpressionError = CannotEscape(position=3, character='x', message="can't escape 'x'")
  inspect(err.position(), content="3")
}
```

**Step 2: Run to verify failure**

Run: `mise run test:unit`
Expected: FAIL

**Step 3: Implement error types**

```moonbit
///|
/// Errors that can occur during cucumber expression parsing.
pub suberror ExpressionError {
  /// Unmatched opening brace `{`.
  UnmatchedBrace(position~ : Int, message~ : String)
  /// Unmatched opening parenthesis `(`.
  UnmatchedParen(position~ : Int, message~ : String)
  /// Cannot escape the given character.
  CannotEscape(position~ : Int, character~ : Char, message~ : String)
  /// End of line cannot be escaped.
  UnexpectedEscapeEnd(position~ : Int, message~ : String)
  /// Expression validation error (e.g., nested optionals, empty alternation).
  ValidationError(position~ : Int, message~ : String)
  /// Unknown parameter type name.
  UnknownParameterType(name~ : String, message~ : String)
}
```

**Step 4: Run tests**

Run: `mise run test:unit`
Expected: PASS

**Step 5: Commit**

```bash
git add src/error.mbt src/error_wbtest.mbt
git commit -m "feat(error): define expression error types"
```

---

### Task 4: Built-in Parameter Types and Registry

**Files:**
- Create: `src/param_type.mbt`
- Create: `src/param_type_wbtest.mbt`

**Step 1: Write tests**

```moonbit
///|
test "ParamType: built-in types" {
  inspect(ParamType::Int, content="Int")
  inspect(ParamType::Float, content="Float")
  inspect(ParamType::String_, content="String_")
  inspect(ParamType::Word, content="Word")
  inspect(ParamType::Anonymous, content="Anonymous")
}

///|
test "ParamTypeRegistry: default has built-in types" {
  let reg = ParamTypeRegistry::default()
  inspect(reg.get("int").is_empty().not(), content="true")
  inspect(reg.get("float").is_empty().not(), content="true")
  inspect(reg.get("string").is_empty().not(), content="true")
  inspect(reg.get("word").is_empty().not(), content="true")
  inspect(reg.get("").is_empty().not(), content="true")
}

///|
test "ParamTypeRegistry: regex for int" {
  let reg = ParamTypeRegistry::default()
  inspect(reg.get("int"), content="Some((Int, [\"(?:-?\\\\d+)\", \"(?:\\\\d+)\"]))")
}

///|
test "ParamTypeRegistry: custom type" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), ["red|blue|green"])
  inspect(reg.get("color").is_empty().not(), content="true")
}
```

**Step 2: Run to verify failure**

Run: `mise run test:unit`
Expected: FAIL

**Step 3: Implement parameter types and registry**

```moonbit
///|
/// Parameter types supported by cucumber expressions.
pub(all) enum ParamType {
  Int
  Float
  String_
  Word
  Anonymous
  Custom(String)
} derive(Show, Eq, ToJson, FromJson)

///|
/// Registry mapping parameter type names to their regex patterns.
pub(all) struct ParamTypeRegistry {
  mut entries : Array[(String, ParamType, Array[String])]
}

///|
pub fn ParamTypeRegistry::new() -> ParamTypeRegistry {
  { entries: [] }
}

///|
pub fn ParamTypeRegistry::default() -> ParamTypeRegistry {
  let reg = ParamTypeRegistry::new()
  reg.register("int", ParamType::Int, ["(?:-?\\d+)", "(?:\\d+)"])
  reg.register("float", ParamType::Float, ["(?:[+-]?(?:\\d+|\\d+\\.\\d*|\\d*\\.\\d+)(?:[eE][+-]?\\d+)?)"])
  reg.register("string", ParamType::String_, ["\"([^\"\\\\]*(\\\\.[^\"\\\\]*)*)\"", "'([^'\\\\]*(\\\\.[^'\\\\]*)*)'"])
  reg.register("word", ParamType::Word, ["[^\\s]+"])
  reg.register("", ParamType::Anonymous, [".*"])
  reg
}

///|
pub fn ParamTypeRegistry::register(
  self : ParamTypeRegistry,
  name : String,
  type_ : ParamType,
  patterns : Array[String],
) -> Unit {
  self.entries.push((name, type_, patterns))
}

///|
pub fn ParamTypeRegistry::get(
  self : ParamTypeRegistry,
  name : String,
) -> (ParamType, Array[String])? {
  for entry in self.entries {
    if entry.0 == name {
      return Some((entry.1, entry.2))
    }
  }
  None
}
```

**Step 4: Run tests and update snapshots**

Run: `mise run test:unit`
If snapshot mismatches: `moon test --update`
Expected: PASS

**Step 5: Commit**

```bash
git add src/param_type.mbt src/param_type_wbtest.mbt
git commit -m "feat(param): define parameter types and registry with built-in types"
```

---

### Task 5: Tokenizer

**Files:**
- Create: `src/tokenizer.mbt`
- Create: `src/tokenizer_wbtest.mbt`

**Step 1: Write tests based on official test cases**

```moonbit
///|
test "tokenize: simple text" {
  let tokens = tokenize!("three blind mice")
  inspect(tokens, content="[Text(\"three blind mice\")]")
}

///|
test "tokenize: parameter" {
  let tokens = tokenize!("{int}")
  inspect(tokens, content="[BeginParameter, Text(\"int\"), EndParameter]")
}

///|
test "tokenize: optional" {
  let tokens = tokenize!("(blind)")
  inspect(tokens, content="[BeginOptional, Text(\"blind\"), EndOptional]")
}

///|
test "tokenize: alternation" {
  let tokens = tokenize!("cat/dog")
  inspect(tokens, content="[Text(\"cat\"), Alternation, Text(\"dog\")]")
}

///|
test "tokenize: escaped opening paren" {
  let tokens = tokenize!("\\(blind\\)")
  inspect(tokens, content="[Text(\"(blind)\")]")
}

///|
test "tokenize: error unmatched brace" {
  let result = try { tokenize!("{int") } catch { e => e }
  inspect(result.to_string().contains("does not have a matching"), content="true")
}

///|
test "tokenize: error backslash at end" {
  let result = try { tokenize!("hello\\") } catch { e => e }
  inspect(result.to_string().contains("cannot be escaped"), content="true")
}
```

**Step 2: Run to verify failure**

Run: `mise run test:unit`
Expected: FAIL

**Step 3: Implement tokenizer**

Define `Token` enum and `tokenize()` function. The tokenizer:
1. Iterates characters, tracking position
2. Handles escape sequences (`\` followed by escapable char)
3. Tracks brace/paren depth for matching
4. Emits `BeginParameter`/`EndParameter`, `BeginOptional`/`EndOptional`, `Alternation`, `Text` tokens
5. Raises `ExpressionError` for invalid sequences

```moonbit
///|
pub(all) enum Token {
  Text(String)
  BeginParameter
  EndParameter
  BeginOptional
  EndOptional
  Alternation
  WhiteSpace(String)
} derive(Show, Eq)
```

**Step 4: Run tests and iterate**

Run: `mise run test:unit`
Expected: PASS after implementation

**Step 5: Commit**

```bash
git add src/tokenizer.mbt src/tokenizer_wbtest.mbt
git commit -m "feat(tokenizer): implement expression tokenizer with escape handling"
```

---

### Task 6: Parser (Tokens to AST)

**Files:**
- Create: `src/parser.mbt`
- Create: `src/parser_wbtest.mbt`

**Step 1: Write tests based on official parser test cases**

```moonbit
///|
test "parse: simple text" {
  let ast = parse_expression!("three blind mice")
  inspect(ast, content="ExpressionNode([TextNode(\"three blind mice\")])")
}

///|
test "parse: parameter" {
  let ast = parse_expression!("{string}")
  inspect(ast, content="ExpressionNode([ParameterNode(\"string\")])")
}

///|
test "parse: optional" {
  let ast = parse_expression!("(blind)")
  inspect(ast, content="ExpressionNode([OptionalNode([TextNode(\"blind\")])])")
}

///|
test "parse: alternation" {
  let ast = parse_expression!("mice/rats")
  inspect(ast, content="ExpressionNode([AlternationNode([[TextNode(\"mice\")], [TextNode(\"rats\")]])])")
}

///|
test "parse: alternation in phrase" {
  let ast = parse_expression!("three hungry/blind mice")
  inspect(ast, content="ExpressionNode([TextNode(\"three \"), AlternationNode([[TextNode(\"hungry\")], [TextNode(\"blind\")]]), TextNode(\" mice\")])")
}

///|
test "parse: optional in phrase" {
  let ast = parse_expression!("three (blind) mice")
  inspect(ast, content="ExpressionNode([TextNode(\"three \"), OptionalNode([TextNode(\"blind\")]), TextNode(\" mice\")])")
}

///|
test "parse: empty expression" {
  let ast = parse_expression!("")
  inspect(ast, content="ExpressionNode([])")
}

///|
test "parse: anonymous parameter" {
  let ast = parse_expression!("{}")
  inspect(ast, content="ExpressionNode([ParameterNode(\"\")])")
}
```

**Step 2: Run to verify failure, then implement**

The parser takes tokenizer output and builds the AST:
1. Group tokens between `BeginParameter`/`EndParameter` into `ParameterNode`
2. Group tokens between `BeginOptional`/`EndOptional` into `OptionalNode`
3. Detect alternation boundaries (whitespace or parameter boundaries)
4. Group `Alternation`-separated sequences into `AlternationNode`
5. Everything else becomes `TextNode`

**Step 3: Run tests**

Run: `mise run test:unit`
Expected: PASS

**Step 4: Commit**

```bash
git add src/parser.mbt src/parser_wbtest.mbt
git commit -m "feat(parser): implement expression parser producing AST"
```

---

### Task 7: AST Validator

**Files:**
- Create: `src/validator.mbt`
- Create: `src/validator_wbtest.mbt`

**Step 1: Write tests for invalid expressions**

```moonbit
///|
test "validate: nested optionals rejected" {
  // ((very) blind) — valid AST, invalid expression
  let result = try { parse_and_validate!("((very) blind)") } catch { e => e }
  inspect(result.to_string().contains("nested"), content="true")
}

///|
test "validate: alternation of only optionals rejected" {
  // (a)/(b) — all-optional alternation arms
  let result = try { parse_and_validate!("(a)/(b)") } catch { e => e }
  inspect(result.to_string().contains("optional"), content="true")
}

///|
test "validate: valid expression passes" {
  let ast = parse_and_validate!("I have {int} cucumber(s)")
  inspect(ast.is_empty().not(), content="true")
}
```

**Step 2: Implement validator**

Walk the AST and check:
- No nested optionals
- Alternation arms contain at least one non-optional text node
- No empty alternation arms (per spec)
- Parameters reference known types (deferred to matching phase if registry not available)

**Step 3: Run tests**

Run: `mise run test:unit`
Expected: PASS

**Step 4: Commit**

```bash
git add src/validator.mbt src/validator_wbtest.mbt
git commit -m "feat(validator): validate AST constraints (nested optionals, empty alternation)"
```

---

### Task 8: Expression to Regex Compiler

**Files:**
- Create: `src/compiler.mbt`
- Create: `src/compiler_wbtest.mbt`

**Step 1: Write tests based on official transformation test cases**

```moonbit
///|
test "compile: empty" {
  let regex = compile!("", ParamTypeRegistry::default())
  inspect(regex, content="^$")
}

///|
test "compile: text" {
  let regex = compile!("a", ParamTypeRegistry::default())
  inspect(regex, content="^a$")
}

///|
test "compile: optional" {
  let regex = compile!("(a)", ParamTypeRegistry::default())
  inspect(regex, content="^(?:a)?$")
}

///|
test "compile: alternation" {
  let regex = compile!("a/b c/d/e", ParamTypeRegistry::default())
  inspect(regex, content="^(?:a|b) (?:c|d|e)$")
}

///|
test "compile: alternation with optional" {
  let regex = compile!("a/b(c)", ParamTypeRegistry::default())
  inspect(regex, content="^(?:a|b(?:c)?)$")
}

///|
test "compile: parameter int" {
  let regex = compile!("{int}", ParamTypeRegistry::default())
  inspect(regex, content="^((?:-?\\d+)|(?:\\d+))$")
}

///|
test "compile: unicode" {
  let regex = compile!("Привет, Мир(ы)!", ParamTypeRegistry::default())
  inspect(regex, content="^Привет, Мир(?:ы)?!$")
}

///|
test "compile: escape regex metacharacters" {
  let regex = compile!("^$[]", ParamTypeRegistry::default())
  inspect(regex, content="^\\^\\$\\[\\]$")
}
```

**Step 2: Run to verify failure, then implement**

The compiler walks the AST and produces regex:
- `ExpressionNode` → `^` + children + `$`
- `TextNode` → escape regex metacharacters (`^$[]()\\{}.|?*+`)
- `ParameterNode` → look up name in registry, produce `((?:pat1)|(?:pat2))` capturing group
- `OptionalNode` → `(?:` + children + `)?`
- `AlternationNode` → `(?:` + alternatives joined by `|` + `)`

**Step 3: Run tests**

Run: `mise run test:unit`
Expected: PASS

**Step 4: Commit**

```bash
git add src/compiler.mbt src/compiler_wbtest.mbt
git commit -m "feat(compiler): compile expression AST to regex"
```

---

### Task 9: Expression Matching and Parameter Extraction

**Files:**
- Create: `src/expression.mbt`
- Create: `src/expression_test.mbt` (blackbox)

**Step 1: Write blackbox tests for the public API**

```moonbit
///|
test "Expression: match int parameter" {
  let expr = Expression::parse!("I have {int} cucumbers")
  let m = expr.match_("I have 42 cucumbers")
  inspect(m.is_empty().not(), content="true")
  guard m is Some(match_) else { abort("expected match") }
  inspect(match_.params[0].value, content="42")
  inspect(match_.params[0].type_, content="Int")
}

///|
test "Expression: match float parameter" {
  let expr = Expression::parse!("I have {float} cucumbers")
  let m = expr.match_("I have 3.14 cucumbers")
  guard m is Some(match_) else { abort("expected match") }
  inspect(match_.params[0].value, content="3.14")
}

///|
test "Expression: match string parameter" {
  let expr = Expression::parse!("I select {string}")
  let m = expr.match_("I select \"blue\"")
  guard m is Some(match_) else { abort("expected match") }
  inspect(match_.params[0].value, content="blue")
}

///|
test "Expression: no match returns None" {
  let expr = Expression::parse!("I have {int} cucumbers")
  let m = expr.match_("I have many cucumbers")
  inspect(m, content="None")
}

///|
test "Expression: optional text matches both forms" {
  let expr = Expression::parse!("I have {int} cucumber(s)")
  inspect(expr.match_("I have 1 cucumber").is_empty().not(), content="true")
  inspect(expr.match_("I have 5 cucumbers").is_empty().not(), content="true")
}

///|
test "Expression: alternation" {
  let expr = Expression::parse!("I have a cat/dog")
  inspect(expr.match_("I have a cat").is_empty().not(), content="true")
  inspect(expr.match_("I have a dog").is_empty().not(), content="true")
  inspect(expr.match_("I have a fish"), content="None")
}
```

**Step 2: Run to verify failure, then implement**

`Expression` is the main public type. It:
1. Parses the expression string to AST (via parser)
2. Validates the AST (via validator)
3. Compiles to regex (via compiler)
4. Stores the compiled regex and parameter type list

`Expression::match_()` runs the regex against text and extracts parameters.

**Note:** MoonBit's standard library may not include a regex engine. Research options:
- Check if `moonbitlang/x` has regex support
- If not, we may need to implement a basic regex matcher or find a mooncakes package
- Alternative: implement matching directly from the AST without regex compilation

**Step 3: Run tests**

Run: `mise run test:unit`
Expected: PASS

**Step 4: Commit**

```bash
git add src/expression.mbt src/expression_test.mbt
git commit -m "feat(expression): implement Expression parse and match public API"
```

---

### Task 10: Custom Parameter Types

**Files:**
- Modify: `src/param_type.mbt`
- Modify: `src/expression.mbt`
- Create: `src/custom_param_wbtest.mbt`

**Step 1: Write tests for custom parameter types**

```moonbit
///|
test "custom param: register and match color" {
  let reg = ParamTypeRegistry::default()
  reg.register("color", ParamType::Custom("color"), ["red|blue|green"])
  let expr = Expression::parse_with_registry!("I select {color}", reg)
  let m = expr.match_("I select blue")
  guard m is Some(match_) else { abort("expected match") }
  inspect(match_.params[0].value, content="blue")
  inspect(match_.params[0].type_, content="Custom(\"color\")")
}

///|
test "custom param: unknown type errors" {
  let result = try { Expression::parse!("I select {color}") } catch { e => e }
  inspect(result.to_string().contains("Unknown"), content="true")
}
```

**Step 2: Implement and run tests**

Add `Expression::parse_with_registry()` that accepts a custom registry.

Run: `mise run test:unit`
Expected: PASS

**Step 3: Commit**

```bash
git add src/param_type.mbt src/expression.mbt src/custom_param_wbtest.mbt
git commit -m "feat(param): support custom parameter type registration and matching"
```

---

### Task 11: Official Test Suite Port

**Files:**
- Create: `src/spec_test.mbt`

**Step 1: Port official test cases**

Systematically port test cases from the cucumber-expressions testdata:

1. **Tokenizer tests** — verify token output for each test case
2. **Parser tests** — verify AST output for each test case
3. **Transformation tests** — verify regex output for each test case
4. **Matching tests** — verify match results for each test case

Include all edge cases:
- Escaped characters
- Unicode expressions
- Empty expressions
- Unmatched delimiters (error cases)
- Nested optionals (validation error)
- Alternation boundary detection
- Multiple parameters in one expression

**Step 2: Run tests and fix any failures**

Run: `mise run test:unit`
Expected: ALL PASS

**Step 3: Commit**

```bash
git add src/spec_test.mbt
git commit -m "test: port official cucumber-expressions test suite"
```

---

### Task 12: Public API Cleanup and Documentation

**Files:**
- Create: `README.mbt.md`
- Modify: `src/lib.mbt`
- Review: all `pub` visibility

**Step 1: Create README.mbt.md with API examples**

Document:
- Basic usage (parse + match)
- All built-in parameter types
- Optional text
- Alternation
- Custom parameter types
- Error handling

Follow the style of `moonrockz/gherkin/README.mbt.md`.

**Step 2: Clean up lib.mbt exports**

Ensure the public API surface is minimal and well-documented:
- `Expression::parse()` and `Expression::parse_with_registry()`
- `Expression::match_()`
- `Match` and `Param` types
- `ParamType` enum
- `ParamTypeRegistry`
- `ExpressionError`

**Step 3: Run all tests one final time**

Run: `mise run test:unit`
Expected: ALL PASS

**Step 4: Commit**

```bash
git add README.mbt.md src/lib.mbt
git commit -m "docs: add README with API documentation and examples"
```

---

## Dependency Order

```
Task 1 (scaffolding)
  ├── Task 2 (AST types)
  ├── Task 3 (error types)
  └── Task 4 (param types + registry)
       └── Task 5 (tokenizer)
            └── Task 6 (parser)
                 └── Task 7 (validator)
                      └── Task 8 (compiler)
                           └── Task 9 (expression + matching)
                                └── Task 10 (custom params)
                                     └── Task 11 (test suite)
                                          └── Task 12 (docs + cleanup)
```

## Critical Research Note

**Regex engine availability:** Before Task 8, verify whether MoonBit's standard library (`moonbitlang/x`) includes a regex engine. If not, the compiler and matcher may need to:
- Use a third-party regex crate from mooncakes.io
- Implement a simple NFA-based matcher
- Match directly from the AST (walking the expression tree against the input string character by character)

This decision affects Tasks 8-9 and should be researched at the start of Task 8.
