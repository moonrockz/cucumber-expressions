///|
/// A typed value produced by a transformer function.
/// Built-in types have concrete variants for compile-time pattern matching.
/// Custom types use `CustomVal(@any.Any)` for type-erased transformer results.
pub(all) enum ParamValue {
  IntVal(Int)
  FloatVal(Double)
  DoubleVal(Double)
  LongVal(Int64)
  ByteVal(Byte)
  ShortVal(Int)
  StringVal(String)
  WordVal(String)
  AnonymousVal(String)
  BigDecimalVal(@decimal.Decimal)
  BigIntegerVal(BigInt)
  CustomVal(@any.Any)
}

///|
impl Show for ParamValue with output(self, logger) {
  match self {
    IntVal(v) => logger.write_string("IntVal(\{v})")
    FloatVal(v) => logger.write_string("FloatVal(\{v})")
    DoubleVal(v) => logger.write_string("DoubleVal(\{v})")
    LongVal(v) => logger.write_string("LongVal(\{v})")
    ByteVal(v) => logger.write_string("ByteVal(\{v})")
    ShortVal(v) => logger.write_string("ShortVal(\{v})")
    StringVal(v) => logger.write_string("StringVal(\{v})")
    WordVal(v) => logger.write_string("WordVal(\{v})")
    AnonymousVal(v) => logger.write_string("AnonymousVal(\{v})")
    BigDecimalVal(v) => logger.write_string("BigDecimalVal(\{v})")
    BigIntegerVal(v) => logger.write_string("BigIntegerVal(\{v})")
    CustomVal(any) => logger.write_string("CustomVal(<\{any.type_name()}>)")
  }
}

///|
impl Eq for ParamValue with equal(self, other) -> Bool {
  match (self, other) {
    (IntVal(a), IntVal(b)) => a == b
    (FloatVal(a), FloatVal(b)) => a == b
    (DoubleVal(a), DoubleVal(b)) => a == b
    (LongVal(a), LongVal(b)) => a == b
    (ByteVal(a), ByteVal(b)) => a == b
    (ShortVal(a), ShortVal(b)) => a == b
    (StringVal(a), StringVal(b)) => a == b
    (WordVal(a), WordVal(b)) => a == b
    (AnonymousVal(a), AnonymousVal(b)) => a == b
    (BigDecimalVal(a), BigDecimalVal(b)) => a == b
    (BigIntegerVal(a), BigIntegerVal(b)) => a == b
    (CustomVal(_), CustomVal(_)) => true // identity comparison not meaningful for Any
    _ => false
  }
}

///|
/// A transformer function that converts captured regex group strings into a typed ParamValue.
/// Receives an array of captured group strings (arity matches capture groups in the regex).
pub(all) struct Transformer {
  priv f : (Array[String]) -> ParamValue raise Error
}

///|
pub fn Transformer::new(
  f : (Array[String]) -> ParamValue raise Error,
) -> Transformer {
  { f, }
}

///|
pub fn Transformer::call(
  self : Transformer,
  groups : Array[String],
) -> ParamValue raise Error {
  (self.f)(groups)
}

///|
impl Show for Transformer with output(_self, logger) {
  logger.write_string("<transformer>")
}

///|
impl Eq for Transformer with equal(_self, _other) -> Bool {
  false
}
