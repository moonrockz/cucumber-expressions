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
  /// The capture group did not match. Only a `RegularExpression` with an
  /// optional group gives this value.
  NullVal
}

///|
pub impl Show for ParamValue with fn output(self, logger) {
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
    NullVal => logger.write_string("NullVal")
  }
}

///|
pub impl @debug.Debug for ParamValue with fn to_repr(self) {
  match self {
    IntVal(v) => @debug.Repr::ctor("IntVal", [(None, @debug.Repr(v))])
    FloatVal(v) => @debug.Repr::ctor("FloatVal", [(None, @debug.Repr(v))])
    DoubleVal(v) => @debug.Repr::ctor("DoubleVal", [(None, @debug.Repr(v))])
    LongVal(v) => @debug.Repr::ctor("LongVal", [(None, @debug.Repr(v))])
    ByteVal(v) => @debug.Repr::ctor("ByteVal", [(None, @debug.Repr(v))])
    ShortVal(v) => @debug.Repr::ctor("ShortVal", [(None, @debug.Repr(v))])
    StringVal(v) => @debug.Repr::ctor("StringVal", [(None, @debug.Repr(v))])
    WordVal(v) => @debug.Repr::ctor("WordVal", [(None, @debug.Repr(v))])
    AnonymousVal(v) =>
      @debug.Repr::ctor("AnonymousVal", [(None, @debug.Repr(v))])
    BigDecimalVal(v) =>
      @debug.Repr::ctor("BigDecimalVal", [
        (None, @debug.Repr::literal(v.to_string())),
      ])
    BigIntegerVal(v) =>
      @debug.Repr::ctor("BigIntegerVal", [(None, @debug.Repr(v))])
    CustomVal(any) =>
      @debug.Repr::ctor("CustomVal", [
        (None, @debug.Repr::literal("<\{any.type_name()}>")),
      ])
    NullVal => @debug.Repr::literal("NullVal")
  }
}

///|
pub impl Eq for ParamValue with fn equal(self, other) -> Bool {
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
    (NullVal, NullVal) => true
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
pub impl @debug.Debug for Transformer with fn to_repr(_self) {
  @debug.Repr::literal("<transformer>")
}

///|
pub extend ParamValue with Show::{to_string, output}

///|
#deprecated
pub extend ParamValue with Eq::{not_equal, equal}

///|
#deprecated
pub extend ParamValue with @debug.Debug::{to_repr}

///|
#deprecated
pub extend Transformer with @debug.Debug::{to_repr}
