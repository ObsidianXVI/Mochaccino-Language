library mochaccino.sdk.compiler.runtime.mocc_types;

class Mochaccino {
  const Mochaccino();
}

class PortedObject extends Mochaccino {
  const PortedObject();
}

class MochaccinoType extends PortedObject {
  const MochaccinoType();
}

@MochaccinoType()
abstract class MoccType {
  const MoccType();
}

@MochaccinoType()
abstract class Meta extends MoccType {}

@MochaccinoType()
class STRUCT extends Meta {}

@MochaccinoType()
class MODULE extends Meta {}

@MochaccinoType()
abstract class Composite extends MoccType {
  const Composite();
}

@MochaccinoType()
class Object extends Composite {
  final dynamic value;
  const Object(this.value);
}

@MochaccinoType()
class Exception extends Object {
  Exception(super.value);
}

@MochaccinoType()
class Error extends Object {
  Error(super.value);
}

@MochaccinoType()
class Promise extends Object {
  Promise(super.value);
}

@MochaccinoType()
class Duration extends Object {
  Duration(super.value);
}

@MochaccinoType()
class DateTime extends Object {
  DateTime(super.value);
}

@MochaccinoType()
abstract class Primitive extends Object {
  Primitive(super.value);
}

@MochaccinoType()
class Int extends Primitive {
  Int(super.value);
}

@MochaccinoType()
class Double extends Primitive {
  Double(super.value);
}

@MochaccinoType()
class Num extends Primitive {
  Num(super.value);
}

@MochaccinoType()
class Bool extends Primitive {
  Bool(super.value);
}

@MochaccinoType()
class Str extends Primitive {
  Str(super.value);
}

@MochaccinoType()
class Map extends Primitive {
  Map(super.value);
}

@MochaccinoType()
class Array extends Primitive {
  Array(super.value);
}
