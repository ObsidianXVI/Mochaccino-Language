library mochaccino.sdk.compiler;

import 'package:mochaccino_sdk/barista/lib/interface/interface.dart';
import './runtime/runtime.dart';
import './runtime/moccTypes.dart';
import './runtime/dart_port.dart';
import './resolvers/resolver.dart';
import 'dart:io';

part './compiler.dart';
part './tokeniser.dart';
part './parser.dart';
part './interpreter.dart';
part './error_handler.dart';

class CompilerEntryPoint {
  static void executeFile(String fpath, bool debugMode) {
    Interface.debugMode = debugMode;
    final Stopwatch stopwatch = Stopwatch()..start();

    InterfaceProcess compJobProc = InterfaceProcess(
      "Creating compile job...",
      Source.compiler,
      debug: debugMode,
    )..start();
    final Compiler compiler = Compiler(
      CompileJob(File(fpath).readAsStringSync(), fpath),
    );
    compJobProc.complete();
    ErrorHandler.lines.addAll(compiler.compileJob.source.split('\n'));
    final CompileResult compileResult = compiler.compile();
    for (ConsoleLog log in compileResult.logs) {
      Interface.write(log.msg, log.logType, log.source);
    }

    for (Issue i in ErrorHandler.issues) {
      Interface.writeErr(i.consoleString, i.source);
    }

    Interface.writeInfo(
        "Exit[0] in ${stopwatch.elapsedMilliseconds}ms", Source.compiler);

    stopwatch.stop();
    exit(0);
  }
}
