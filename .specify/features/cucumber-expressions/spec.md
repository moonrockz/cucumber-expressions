# Feature Specification: Cucumber Expressions for MoonBit

**Feature Branch**: `main`
**Created**: 2026-02-21
**Status**: Draft
**Input**: MoonBit implementation of the Cucumber Expressions specification

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Parse and match simple parameter expressions (Priority: P1)

As a BDD framework author, I want to parse cucumber expressions like `"I have {int} cucumbers"` and match them against step text to extract typed parameters.

**Why this priority**: This is the core use case. Without parameter matching, the library has no value.

**Independent Test**: Can be fully tested by parsing an expression and matching it against sample text, verifying extracted parameters.

**Acceptance Scenarios**:

1. **Given** the expression `"I have {int} cucumbers"`, **When** matched against `"I have 42 cucumbers"`, **Then** it returns a match with one `Int` param valued `42`
2. **Given** the expression `"I have {float} cucumbers"`, **When** matched against `"I have 3.14 cucumbers"`, **Then** it returns a match with one `Float` param valued `3.14`
3. **Given** the expression `"I select {string}"`, **When** matched against `"I select \"blue\""`, **Then** it returns a match with one `String` param valued `blue` (quotes stripped)
4. **Given** the expression `"I have {word} cucumbers"`, **When** matched against `"I have big cucumbers"`, **Then** it returns a match with one `Word` param valued `big`
5. **Given** the expression `"{}"`, **When** matched against `"anything goes"`, **Then** it returns a match with one `Anonymous` param valued `"anything goes"`
6. **Given** the expression `"I have {int} cucumbers"`, **When** matched against `"I have many cucumbers"`, **Then** it returns `None` (no match)

---

### User Story 2 - Parse optional text in expressions (Priority: P1)

As a BDD framework author, I want to use optional text like `"I have {int} cucumber(s)"` so that both singular and plural forms match.

**Why this priority**: Optional text is one of the three core syntax features and is commonly used.

**Independent Test**: Parse expression with optional group, match against both forms.

**Acceptance Scenarios**:

1. **Given** the expression `"I have {int} cucumber(s)"`, **When** matched against `"I have 1 cucumber"`, **Then** it matches with param `1`
2. **Given** the expression `"I have {int} cucumber(s)"`, **When** matched against `"I have 5 cucumbers"`, **Then** it matches with param `5`

---

### User Story 3 - Parse alternation in expressions (Priority: P1)

As a BDD framework author, I want to use alternation like `"I have a cat/dog"` so that multiple word choices match the same step.

**Why this priority**: Alternation is one of the three core syntax features.

**Independent Test**: Parse expression with alternation, match against each alternative.

**Acceptance Scenarios**:

1. **Given** the expression `"I have a cat/dog"`, **When** matched against `"I have a cat"`, **Then** it matches
2. **Given** the expression `"I have a cat/dog"`, **When** matched against `"I have a dog"`, **Then** it matches
3. **Given** the expression `"I have a cat/dog"`, **When** matched against `"I have a fish"`, **Then** it returns `None`
4. **Given** the expression `"three hungry/blind mice"`, **When** matched against `"three blind mice"`, **Then** it matches

---

### User Story 4 - Register and use custom parameter types (Priority: P2)

As a BDD framework author, I want to register custom parameter types like `{color}` matching `red|blue|green` so that domain-specific values can be extracted.

**Why this priority**: Extends the library for real-world usage but not required for MVP.

**Independent Test**: Register a custom type in the registry, parse an expression using it, match text.

**Acceptance Scenarios**:

1. **Given** a registry with custom type `color` matching `red|blue|green`, **When** the expression `"I select {color}"` is matched against `"I select blue"`, **Then** it returns a match with param `blue` of custom type `color`
2. **Given** a registry with no custom types, **When** the expression `"I select {color}"` is parsed, **Then** it raises an error for unknown parameter type

---

### User Story 5 - Escaping special characters (Priority: P2)

As a BDD framework author, I want to escape special characters with backslash so that literal `(`, `{`, `/`, and `\` can appear in expressions.

**Why this priority**: Required for spec compliance but less commonly used in practice.

**Independent Test**: Parse expressions with escaped characters, verify they match literal text.

**Acceptance Scenarios**:

1. **Given** the expression `"I have \(optional\) cucumbers"`, **When** matched against `"I have (optional) cucumbers"`, **Then** it matches (parentheses are literal)
2. **Given** the expression `"I use a/b\/c"`, **When** matched against `"I use a"`, **Then** it matches as alternation `a` or `b/c`
3. **Given** the expression `"path\\to\\file"`, **When** matched against `"path\to\file"`, **Then** it matches

---

### Edge Cases

- What happens when expression is empty (`""`)? Should match only empty string.
- What happens with unmatched `{`? Parse error with descriptive message.
- What happens with unmatched `(`? Parse error with descriptive message.
- What happens with unmatched `}` or `)`? Treated as literal text (asymmetric behavior per spec).
- What happens with `/` surrounded by whitespace? Not alternation, treated as literal text.
- What happens with nested optionals `((a))`? Valid AST but invalid expression — error during validation.
- What happens with alternation arms that are only optionals `(a)/(b)`? Invalid expression — error during validation.
- What happens with backslash at end of expression? Tokenizer error: "end of line cannot be escaped."
- What happens with backslash before non-escapable character? Tokenizer error.
- What happens with Unicode text? Passed through unchanged, matches natively.
- What happens with multiple `{string}` parameters? Each gets distinct capture groups.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Library MUST parse all valid cucumber expressions per the official grammar
- **FR-002**: Library MUST produce descriptive parse errors for invalid expressions (with source position)
- **FR-003**: Library MUST compile expressions to regex for matching
- **FR-004**: Library MUST support built-in parameter types: `{int}`, `{float}`, `{string}`, `{word}`, `{}`
- **FR-005**: Library MUST extract typed parameters from matched text
- **FR-006**: Library MUST support optional text syntax `(text)`
- **FR-007**: Library MUST support alternation syntax `a/b/c` with correct boundary detection
- **FR-008**: Library MUST support escaping with backslash for `(`, `)`, `{`, `}`, `/`, `\`, and space
- **FR-009**: Library MUST support custom parameter type registration via `ParamTypeRegistry`
- **FR-010**: Library MUST pass the official cucumber-expressions test suite
- **FR-011**: All public types MUST derive `Show`, `Eq`, `ToJson`, `FromJson`
- **FR-012**: Library MUST have zero dependencies beyond `moonbitlang/x`

### Key Entities

- **Expression**: A parsed cucumber expression, compiled to regex for matching
- **AST Nodes**: `ExpressionNode`, `TextNode`, `ParameterNode`, `OptionalNode`, `AlternationNode`, `AlternativeNode`
- **ParamType**: Enum of built-in types (`Int`, `Float`, `String_`, `Word`, `Anonymous`) plus `Custom(String)`
- **ParamTypeRegistry**: Registry mapping parameter type names to regex patterns and transforms
- **Match**: Result of matching an expression against text, containing extracted `Param` values
- **Param**: An extracted parameter with its raw value and `ParamType`

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All official cucumber-expressions test cases pass (tokenizer, parser, transformation, matching)
- **SC-002**: Expression parsing and matching completes in under 1ms for typical expressions
- **SC-003**: Library has zero runtime panics — all error paths use typed errors
- **SC-004**: Library is published to mooncakes.io and importable by moonspec
