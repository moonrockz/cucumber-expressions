# Project Agents.md Guide

This is a [MoonBit](https://docs.moonbitlang.com) project.

You can browse and install extra skills here:
<https://github.com/moonbitlang/skills>

## Project Overview

This module (`moonrockz/cucumber-expressions`) is a **standalone library** that
parses and matches [Cucumber Expressions](https://github.com/cucumber/cucumber-expressions)
-- the simpler alternative to regular expressions used in BDD step definitions.

The library has **zero dependencies** beyond `moonbitlang/x` and
`moonbitlang/regexp`. It is a general-purpose pattern matching library usable by
any MoonBit project, not coupled to any particular test framework.

### Architecture Summary

```
moonrockz/cucumber-expressions
├── src/                  # The library (sole artifact)
│   ├── ast.mbt           # AST node types (ExpressionNode, TextNode, etc.)
│   ├── tokenizer.mbt     # Expression string → Token array
│   ├── parser.mbt        # Tokens → AST (three-phase: group, alternation, merge)
│   ├── validator.mbt     # AST constraint validation
│   ├── compiler.mbt      # AST → regex string
│   ├── expression.mbt    # Public API: Expression, Match, Param
│   ├── param_type.mbt    # ParamType enum + ParamTypeRegistry
│   ├── error.mbt         # ExpressionError suberror types
│   ├── lib.mbt           # Package entry point
│   ├── *_wbtest.mbt      # Whitebox tests
│   └── moon.pkg          # Package config (DSL format)
├── docs/plans/           # Design and implementation plans
├── .specify/             # Speckit spec-driven development artifacts
├── .beads/               # Issue tracking database
└── mise-tasks/           # File-based mise tasks
```

### Processing Pipeline

```
Expression string → tokenize() → Token[]
                  → parse_expression() → AST (Node)
                  → validate() → validated AST
                  → compile() → regex string
                  → @regexp.compile() → Regexp
                  → Expression::match_() → Match?
```

## Project Structure

- MoonBit packages are organized per directory, for each directory, there is a
  `moon.pkg` file listing its dependencies. Each package has its files and
  blackbox test files (common, ending in `_test.mbt`) and whitebox test files
  (ending in `_wbtest.mbt`).

- In the toplevel directory, there is a `moon.mod.json` file listing about the
  module and some meta information.

## Design Philosophy

This project follows **functional design principles**. These are non-negotiable:

- **Algebraic data types (ADTs)**: Model domain concepts using enums (sum types)
  and structs (product types). Use ADTs to make the type system express the
  domain precisely.

- **Make invalid states unrepresentable**: Design types so that illegal
  combinations cannot be constructed. If a state shouldn't exist, the type
  system should prevent it -- not runtime checks.

- **Avoid primitive obsession**: Do not use raw `String`, `Int`, or `Bool` where
  a domain-specific type is appropriate. Wrap primitives in meaningful types.

- **Prefer immutability**: Default to immutable data. Use `mut` only when
  mutation is clearly necessary and localized.

- **Pattern matching over conditionals**: Use `match` expressions to
  exhaustively handle all variants of an enum.

- **Total functions**: Functions should handle all possible inputs. Use `raise`
  with typed `suberror` for parse failures. Return `Option` instead of panicking.

## Test-Driven Development (TDD)

This project practices **strict TDD**. Tests are written **before**
implementation code. This is not optional.

### The TDD Cycle

For every piece of new functionality, follow **Red-Green-Refactor**:

1. **Red**: Write a failing test that describes the desired behavior. Run it.
   Confirm it fails for the right reason.
2. **Green**: Write the **minimum** implementation code to make the test pass.
3. **Refactor**: Clean up the implementation while keeping tests green.

### Using `#declaration_only` for Spec-First Design

MoonBit's `#declaration_only` attribute lets you define function signatures
before implementing them:

```moonbit
#declaration_only
pub fn Expression::parse(input : String) -> Expression!ExpressionError {
  ...
}
```

Use this to sketch out the public API, write tests against it, then fill in
implementations as tests go green.

### Testing Conventions

- Use `inspect(value, content="expected")` for snapshot testing
- Use `assert_eq` for stable, well-defined results
- Use `_wbtest.mbt` files for whitebox tests (access to private internals)
- Run `moon test --update` to refresh snapshots when behavior changes
- Run `moon coverage analyze > uncovered.log` to check coverage

## Coding Convention

- MoonBit code is organized in block style, each block is separated by `///|`,
  the order of each block is irrelevant. In some refactorings, you can process
  block by block independently.

- Try to keep deprecated blocks in a file called `deprecated.mbt` in each
  directory.

## Conventional Commits

All commit messages MUST follow **[Conventional Commits](https://www.conventionalcommits.org)**:

```
type(scope): description
```

### Commit Types

| Type       | Purpose                    | Version bump |
|------------|----------------------------|-------------|
| `feat`     | New feature                | MINOR        |
| `fix`      | Bug fix                    | PATCH        |
| `refactor` | Code restructuring         | -            |
| `perf`     | Performance improvement    | -            |
| `docs`     | Documentation only         | -            |
| `test`     | Adding/updating tests      | -            |
| `build`    | Build system changes       | -            |
| `ci`       | CI/CD configuration        | -            |
| `chore`    | Maintenance tasks          | -            |
| `style`    | Code formatting (no logic) | -            |

Breaking changes: add `!` after type (e.g., `feat(parser)!: change return type`).

## Mise Tasks

All build, test, and release operations are **file-based mise tasks** in
`mise-tasks/`. Use `mise run <task>` to execute them.

| Task                  | Purpose                                        |
|-----------------------|------------------------------------------------|
| `test:unit`           | Run MoonBit unit tests (`moon test`)           |
| `release:version`     | Compute next version from conventional commits |
| `release:credentials` | Set up mooncakes.io credentials (CI only)      |
| `release:publish`     | Publish package to mooncakes.io                |

### Creating New Tasks

New tasks go in `mise-tasks/` as executable scripts with `#MISE` metadata.
Use subdirectories for namespacing: `mise-tasks/build/native` becomes
`build:native`.

**Rules:**
- **Always** use file-based tasks in `mise-tasks/` -- never add inline TOML
  tasks to `.mise.toml`.
- The `.mise.toml` file contains only `[tools]` -- no `[tasks]` sections.

## Tooling

- `moon fmt` is used to format your code properly.

- `moon ide` provides project navigation helpers like `peek-def`, `outline`, and
  `find-references`. See $moonbit-agent-guide for details.

- `moon info` is used to update the generated interface of the package, each
  package has a generated interface file `.mbti`, it is a brief formal
  description of the package. If nothing in `.mbti` changes, this means your
  change does not bring the visible changes to the external package users, it is
  typically a safe refactoring.

- In the last step, run `moon info && moon fmt` to update the interface and
  format the code. Check the diffs of `.mbti` file to see if the changes are
  expected.

- Run `mise run test:unit` to check tests pass. MoonBit supports snapshot
  testing; when changes affect outputs, run `moon test --update` to refresh
  snapshots.

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for results that
  are stable or very unlikely to change. Use snapshot tests to record current
  behavior. You can use `moon coverage analyze > uncovered.log` to see which
  parts of your code are not covered by tests.

## Release Process

This project publishes to **mooncakes.io** (MoonBit package registry) and
**GitHub Releases**.

- Releases triggered by pushing a tag matching `v*` or via workflow_dispatch
- Requires `MOONCAKES_USER_TOKEN` org secret in GitHub Actions
- Pre-publish checks: `moon check`, `moon test`, `moon fmt`
- Package published as `moonrockz/cucumber-expressions` on mooncakes.io

## Issue Tracking

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get
started.

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT
complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
