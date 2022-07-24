library mochaccino.sdk.compiler;

import 'package:barista/interface/interface.dart';
import './runtime/runtime.dart';
import './runtime/moccTypes.dart' as mocc;
import 'dart:io';

part './compiler.dart';
part './tokeniser.dart';
part './parser.dart';
part './interpreter.dart';
part './error_handler.dart';
part './symbols.dart';

void main(List<String> args) {
  late bool debugMode;
  if (args.isNotEmpty) {
    if (args[0] == 'no-debug') debugMode = false;
  } else {
    debugMode = true;
  }
  Interface.debugMode = debugMode;
  final Stopwatch stopwatch = Stopwatch()..start();

  InterfaceProcess compJobProc = InterfaceProcess(
    "Creating compile job...",
    Source.compiler,
    debug: debugMode,
  )..start();
  final Compiler compiler = Compiler(
    CompileJob("ok 1+1;"),
  );
  compJobProc.complete();
  final CompileResult compileResult = compiler.compile();
  for (ConsoleLog log in compileResult.logs) {
    Interface.write(log.msg, log.logType, log.source);
  }

  Interface.writeInfo(
      "Exit[0] in ${stopwatch.elapsedMilliseconds}ms", Source.compiler);

  stopwatch.stop();
  exit(0);
}
