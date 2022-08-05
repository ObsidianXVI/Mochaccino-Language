import './moccTypes.dart';
import '../../barista/lib/interface/interface.dart';
import '../compiler_entry.dart';

/////////////////////////
/// PortedObject
/////////////////////////
@PortedObject()
abstract class MoccType {
  const MoccType();
}

@PortedObject()
abstract class MetaObject extends MoccType {
  const MetaObject();
}

@PortedObject()
abstract class MoccObject extends MoccType {
  final dynamic innerValue;

  const MoccObject(this.innerValue);

  MoccInt get objectHash => MoccInt(hashCode);

  MoccType get objectType => this;

  MoccStr toMoccString() {
    return MoccStr(innerValue.toString());
  }
}

@PortedObject()
abstract class Primitive extends MoccObject {
  const Primitive(super.innerValue);
}

@PortedObject()
abstract class Composite extends MoccObject {
  const Composite(super.innerValue);
}

class MoccStr extends Primitive {
  const MoccStr(String innerValue) : super(innerValue);
}

class MoccInt extends Primitive {
  const MoccInt(int innerValue) : super(innerValue);
}

class MoccDbl extends Primitive {
  const MoccDbl(double innerValue) : super(innerValue);
}

class MoccNum extends Primitive {
  const MoccNum(num innerValue) : super(innerValue);
}

class MoccBool extends Primitive {
  const MoccBool(bool innerValue) : super(innerValue);
}

class MoccDyn extends Primitive {
  const MoccDyn(dynamic innerValue) : super(innerValue);
}

abstract class MoccVoid extends Primitive {
  const MoccVoid() : super(null);
}

class MoccNull extends MoccVoid {
  const MoccNull();
}

////////////////////////

abstract class MoccInv<T extends MoccObject> extends Composite {
  final Parameters params;

  /// Mocc Maybe use factory?
  const MoccInv(this.params) : super(null);

  T call(Interpreter interpreter, Arguments args);
}

abstract class MoccFn<T extends MoccObject> extends MoccInv<T> {
  const MoccFn(super.params);
}

///////////////////////

class Log extends MoccFn<MoccVoid> {
  Log()
      : super(
          Parameters(
            positionalArgs: [
              {'payload': MoccStr}
            ],
            namedArgs: const {},
          ),
        );

  @override
  MoccVoid call(Interpreter interpreter, Arguments args) {
    Interface.write(
        args.positionalArgs.first.innerValue, LogType.log, Source.program);
    return const MoccNull();
  }
}

extension MapUtils on Map<String, MoccObject> {
  MoccObject get(String name) => this[name]!;
}
