import './moccTypes.dart';
import '../../barista/lib/interface/interface.dart';
import '../compiler_entry.dart';
import '../runtime/runtime.dart';

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
abstract class MoccObj extends MoccType {
  final dynamic innerValue;

  const MoccObj(this.innerValue);

  MoccInt get objectHash => MoccInt(hashCode);

  MoccType get objectType => this;

  MoccStr toMoccString() {
    if (this is Primitive) {
      return MoccStr(
        runtimeType.toString().replaceAll("Mocc", "").toLowerCase(),
      );
    } else {
      return toMoccString();
    }
  }
}

@PortedObject()
abstract class Primitive extends MoccObj {
  const Primitive(super.innerValue);

  @override
  MoccStr toMoccString() => MoccStr(innerValue.toString());
}

@PortedObject()
abstract class Composite extends MoccObj {
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
@PortedObject()
abstract class MoccInv extends Composite {
  const MoccInv(super.innerValue);

  MoccObj call(Interpreter interpreter, Arguments args);
}

@PortedObject()
class MoccFn extends MoccInv {
  final FuncDecl declaration;
  final Environment _closure;
  MoccFn(this.declaration, this._closure) : super(declaration);

  Environment createEnvironment(Interpreter interpreter, Arguments args) {
    final Environment environment = Environment(_closure);
    for (int i = 0; i < declaration.params.length; i++) {
      environment.defineObject(
          declaration.params[i].lexeme, args.positionalArgs[i]);
    }
    return environment;
  }

  @override
  MoccObj call(Interpreter interpreter, Arguments args) {
    final Environment environment = createEnvironment(interpreter, args);
    try {
      interpreter.executeBlock(declaration.body, environment);
    } on Return catch (e) {
      return e.value.toMoccObject();
    }
    return const MoccNull();
  }

  @override
  MoccStr toMoccString() {
    return MoccStr(
        "${declaration.name.lexeme}<fn<${declaration.returnType.asMoccType}>>");
  }
}

@PortedObject()
class MoccStruct extends MoccInv {
  final String name;
  final Map<String, MoccFn> methods;
  const MoccStruct(this.name, this.methods) : super(name);

  MoccFn? findMethod(String name) {
    if (methods.containsKey(name)) {
      return methods[name]!;
    } else {
      return null;
    }
  }

  @override
  MoccObj call(Interpreter interpreter, Arguments args) {
    final MoccObjectInstance instance = MoccObjectInstance(this);
    return instance;
  }

  @override
  MoccStr toMoccString() {
    return MoccStr(name);
  }
}

@PortedObject()
class MoccObjectInstance extends MoccObj {
  final MoccStruct struct;
  final Map<String, MoccObj> fields = {};
  MoccObjectInstance(this.struct) : super(struct);

  MoccObj get(Token name) {
    if (fields.containsKey(name.lexeme)) {
      return fields.get(name.lexeme);
    }

    MoccFn? method = struct.findMethod(name.lexeme);
    if (method != null) return method;

    throw NameError(
      NameError.undefinedName(name.lexeme),
      lineNo: name.lineNo,
      offendingLine: ErrorHandler.lines[name.lineNo],
      start: name.start,
      description:
          "The property '${name.lexeme}' is not defined for '${struct.name}'",
      source: Source.interpreter,
    );
  }

  void set(Token name, MoccObj value) {
    fields[name.lexeme] = value;
  }

  @override
  MoccStr toMoccString() {
    return MoccStr("${struct.toMoccString().innerValue} object");
  }
}

///////////////////////

class Log extends MoccFn {
  Log()
      : super(
          FuncDecl.portedFn(
            'log',
            Parameters(positionalArgs: [
              {'msg': MoccStr}
            ], namedArgs: {}),
            MoccVoid,
          ),
          coreLibEnv,
        );

  @override
  MoccVoid call(Interpreter interpreter, Arguments args) {
    final Environment environment = createEnvironment(interpreter, args);
    Interface.write(args.positionalArgs.first.toMoccString().innerValue,
        LogType.log, Source.program);
    return const MoccNull();
  }
}

extension MapUtils on Map<String, MoccObj> {
  MoccObj get(String name) => this[name]!;
}

extension TypeUtils on Type {
  String get asMoccType {
    return toString().replaceAll("Mocc", "").toLowerCase();
  }
}
