///|
/// The value of a typed parameter type.
///
/// The value is kept in a closure. The closure writes the value into the
/// slot of the `ParameterType[T]` handle that made it, so reading the value
/// back needs no casts and works on every target.
pub struct TypedValue {
  priv type_name : String
  priv put : () -> Unit
}

///|
/// The name of the parameter type that made the value.
pub fn TypedValue::type_name(self : TypedValue) -> String {
  self.type_name
}

///|
/// A typed parameter type. `define1` to `define8`, `define_with` and
/// `define_type1` to `define_type8` return it. Use it to read the value of a
/// parameter of this type, with its type.
pub struct ParameterType[T] {
  priv name : String
  priv slot : Ref[T?]
}

///|
fn[T] ParameterType::new(name : String) -> ParameterType[T] {
  { name, slot: { val: None, }, }
}

///|
/// The name of the parameter type, as used in expressions.
pub fn[T] ParameterType::name(self : ParameterType[T]) -> String {
  self.name
}

///|
/// Wrap a value of this type.
fn[T] ParameterType::wrap(self : ParameterType[T], value : T) -> ParamValue {
  let slot = self.slot
  TypedVal({ type_name: self.name, put: () => slot.val = Some(value), })
}

///|
/// The value of `param`, or `None` when `param` did not come from this
/// handle.
fn[T] ParameterType::try_get(self : ParameterType[T], param : Param) -> T? {
  guard param.value is TypedVal(typed) else { return None }
  self.slot.val = None
  (typed.put)()
  let value = self.slot.val
  self.slot.val = None
  value
}

///|
/// The value of `param`. Raises `WrongParameterType` when `param` did not
/// come from this handle, including a type with the same name in another
/// registry.
pub fn[T] ParameterType::get(
  self : ParameterType[T],
  param : Param,
) -> T raise ParameterTypeError {
  match self.try_get(param) {
    Some(value) => value
    None =>
      raise WrongParameterType(
        expected=self.name,
        actual=parameter_type_name(param.type_),
      )
  }
}

///|
fn parameter_type_name(type_ : ParamType) -> String {
  match type_ {
    Int => "int"
    Float => "float"
    String_ => "string"
    Word => "word"
    Anonymous => ""
    Double_ => "double"
    Long => "long"
    Byte => "byte"
    Short => "short"
    BigDecimal => "bigdecimal"
    BigInteger => "biginteger"
    Custom(name) => name
  }
}

///|
/// The value of the only parameter of the match that came from `handle`.
/// Raises `MissingParameter` when there is none, and `AmbiguousParameter`
/// when there is more than one.
pub fn[T] Match::get(
  self : Match,
  handle : ParameterType[T],
) -> T raise ParameterTypeError {
  let values = self.get_all(handle)
  match values.length() {
    1 => values[0]
    0 => raise MissingParameter(name=handle.name)
    count => raise AmbiguousParameter(name=handle.name, count~)
  }
}

///|
/// The values of all parameters of the match that came from `handle`, in
/// order.
pub fn[T] Match::get_all(self : Match, handle : ParameterType[T]) -> Array[T] {
  self.params.filter_map(p => handle.try_get(p))
}
