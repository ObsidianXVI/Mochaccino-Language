library mochaccino.sdk.compiler.runtime.mocc_types;

import './dart_port.dart';
export './dart_port.dart';

class PortedObject {
  const PortedObject();
}

class Parameters {
  final List<Map<String, Type>> positionalArgs;
  final Map<String, Map<MoccType, MoccObject>> namedArgs;

  Parameters({required this.positionalArgs, required this.namedArgs});
}

class Arguments {
  final List<MoccObject> positionalArgs;
  final Map<String, MoccObject> namedArgs;

  const Arguments({this.positionalArgs = const [], this.namedArgs = const {}});
}
