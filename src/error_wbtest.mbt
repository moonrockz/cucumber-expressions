///|
test "UnmatchedBrace construction and Show" {
  let err : ExpressionError = UnmatchedBrace(
    position=5,
    message="Expected }",
  )
  inspect(err, content=(
    #|UnmatchedBrace(position=5, message="Expected }")
  ))
}

///|
test "UnmatchedBrace position field" {
  match UnmatchedBrace(position=5, message="Expected }") {
    UnmatchedBrace(position~, ..) => inspect(position, content="5")
    _ => abort("unexpected variant")
  }
}

///|
test "UnmatchedBrace message field" {
  match UnmatchedBrace(position=5, message="Expected }") {
    UnmatchedBrace(message~, ..) => inspect(message, content="Expected }")
    _ => abort("unexpected variant")
  }
}

///|
test "UnmatchedParen construction and Show" {
  let err : ExpressionError = UnmatchedParen(
    position=3,
    message="Expected )",
  )
  inspect(err, content=(
    #|UnmatchedParen(position=3, message="Expected )")
  ))
}

///|
test "UnmatchedParen position field" {
  match UnmatchedParen(position=3, message="Expected )") {
    UnmatchedParen(position~, ..) => inspect(position, content="3")
    _ => abort("unexpected variant")
  }
}

///|
test "UnmatchedParen message field" {
  match UnmatchedParen(position=3, message="Expected )") {
    UnmatchedParen(message~, ..) => inspect(message, content="Expected )")
    _ => abort("unexpected variant")
  }
}

///|
test "CannotEscape construction and Show" {
  let err : ExpressionError = CannotEscape(
    position=7,
    character='*',
    message="Cannot escape *",
  )
  inspect(err, content=(
    #|CannotEscape(position=7, character='*', message="Cannot escape *")
  ))
}

///|
test "CannotEscape position field" {
  match CannotEscape(position=7, character='*', message="Cannot escape *") {
    CannotEscape(position~, ..) => inspect(position, content="7")
    _ => abort("unexpected variant")
  }
}

///|
test "CannotEscape character field" {
  match CannotEscape(position=7, character='*', message="Cannot escape *") {
    CannotEscape(character~, ..) => inspect(character, content="*")
    _ => abort("unexpected variant")
  }
}

///|
test "CannotEscape message field" {
  match CannotEscape(position=7, character='*', message="Cannot escape *") {
    CannotEscape(message~, ..) => inspect(message, content="Cannot escape *")
    _ => abort("unexpected variant")
  }
}

///|
test "UnexpectedEscapeEnd construction and Show" {
  let err : ExpressionError = UnexpectedEscapeEnd(
    position=10,
    message="Unexpected end of escape",
  )
  inspect(err, content=(
    #|UnexpectedEscapeEnd(position=10, message="Unexpected end of escape")
  ))
}

///|
test "UnexpectedEscapeEnd position field" {
  match UnexpectedEscapeEnd(position=10, message="Unexpected end of escape") {
    UnexpectedEscapeEnd(position~, ..) => inspect(position, content="10")
    _ => abort("unexpected variant")
  }
}

///|
test "UnexpectedEscapeEnd message field" {
  match UnexpectedEscapeEnd(position=10, message="Unexpected end of escape") {
    UnexpectedEscapeEnd(message~, ..) =>
      inspect(message, content="Unexpected end of escape")
    _ => abort("unexpected variant")
  }
}

///|
test "ValidationError construction and Show" {
  let err : ExpressionError = ValidationError(
    position=0,
    message="Nested optionals not allowed",
  )
  inspect(err, content=(
    #|ValidationError(position=0, message="Nested optionals not allowed")
  ))
}

///|
test "ValidationError position field" {
  match ValidationError(position=0, message="Nested optionals not allowed") {
    ValidationError(position~, ..) => inspect(position, content="0")
    _ => abort("unexpected variant")
  }
}

///|
test "ValidationError message field" {
  match ValidationError(position=0, message="Nested optionals not allowed") {
    ValidationError(message~, ..) =>
      inspect(message, content="Nested optionals not allowed")
    _ => abort("unexpected variant")
  }
}

///|
test "UnknownParameterType construction and Show" {
  let err : ExpressionError = UnknownParameterType(
    name="bigint",
    message="Unknown parameter type: bigint",
  )
  inspect(err, content=(
    #|UnknownParameterType(name="bigint", message="Unknown parameter type: bigint")
  ))
}

///|
test "UnknownParameterType name field" {
  match UnknownParameterType(
    name="bigint",
    message="Unknown parameter type: bigint",
  ) {
    UnknownParameterType(name~, ..) => inspect(name, content="bigint")
    _ => abort("unexpected variant")
  }
}

///|
test "UnknownParameterType message field" {
  match UnknownParameterType(
    name="bigint",
    message="Unknown parameter type: bigint",
  ) {
    UnknownParameterType(message~, ..) =>
      inspect(message, content="Unknown parameter type: bigint")
    _ => abort("unexpected variant")
  }
}
