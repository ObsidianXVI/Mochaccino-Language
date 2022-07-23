part of mochaccino.sdk.compiler.runtime;

abstract class Mochaccino {}

class MoccObject {
  late MoccType moccType;
  final Object? value;

  MoccObject(this.value, [MoccType? moccType]) {
    if (moccType == null) {
      this.moccType = PrimitiveType.dyn();
    } else {
      this.moccType = moccType;
    }
  }

  @override
  String toString() => value.toString() + "<" + moccType.toString() + ">";
}

class MoccType {
  final String lexeme;
  final List<MoccType>? typeArgs;

  const MoccType(this.lexeme, [this.typeArgs = const []]);

  @override
  String toString() {
    if (typeArgs != null)
      return typeArgs!
          .map((MoccType t) => "<${t.toString()}>")
          .toList()
          .join('');
    return lexeme;
  }
}

abstract class PrimitiveType implements MoccType {
  static MoccType dyn() => const MoccType('dyn');
  static MoccType str() => const MoccType('str');
  static MoccType num() => const MoccType('num');
  static MoccType bool() => const MoccType('bool');
  static MoccType fn(MoccType returnType) => MoccType('fn', [returnType]);
  static MoccType map(MoccType keyType, MoccType, valueType) =>
      MoccType('map', [keyType, valueType]);
  static MoccType arr(MoccType elementType) => MoccType('arr', [elementType]);
  static MoccType Void() => const MoccType('void');
  static MoccType promise(MoccType innerValueType) =>
      MoccType('promise', [innerValueType]);
  static MoccType Null() => const MoccType('null');
  static MoccType entryPoint() => const MoccType('entryPoint');
}
