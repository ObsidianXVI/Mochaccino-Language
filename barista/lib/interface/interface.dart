library mochaccino.barista.interface;

import 'dart:io';

enum LogType {
  log,
  warn,
  err,
  info,
}

enum Source {
  barista,
  compiler,
  tokeniser,
  parser,
  interpreter,
}

extension EnumUtils on Source {
  String stringify() {
    if (this == Source.barista) return "BAR";
    if (this == Source.compiler) return "COM";
    if (this == Source.tokeniser) return "TOK";
    if (this == Source.parser) return "PAR";
    if (this == Source.interpreter) return "INT";
    return toString();
  }
}

extension LogTypeUtils on LogType {
  String stringify() {
    if (this == LogType.log) return " LOG";
    if (this == LogType.info) return "INFO";
    if (this == LogType.err) return " ERR";
    if (this == LogType.warn) return "WARN";
    return toString();
  }
}

class Interface {
  static void writeRaw(
    String msg,
    LogType logType,
    Source source, [
    bool prefix = true,
  ]) {
    if (prefix) {
      stdout.write("☕ ${source.stringify()} ${logType.stringify()}: $msg");
    } else {
      stdout.write(msg);
    }
  }

  static void write(String msg, LogType logType, Source source) {
    stdout.writeln("☕ ${source.stringify()} ${logType.stringify()}: $msg");
  }

  static void writeLog(String msg, Source source) =>
      Interface.write(msg, LogType.log, source);
  static void writeSuccess(String msg, Source source) =>
      Interface.write(msg.withColor(TextColor.green), LogType.log, source);
  static void writeWarn(String msg, Source source) =>
      Interface.write(msg.withColor(TextColor.yellow), LogType.warn, source);
  static void writeInfo(String msg, Source source) =>
      Interface.write(msg.withColor(TextColor.cyan), LogType.info, source);
  static void writeErr(String msg, Source source) =>
      Interface.write(msg.withColor(TextColor.red), LogType.err, source);

  static void readInput() => stdin.pipe(stdout);

  static void startSyncAction(String msg, Source source) {
    Interface.writeRaw("  $msg".padRight(30), LogType.log, Source.barista);
  }
}

class InterfaceProcess {
  final String msg;
  const InterfaceProcess(this.msg);

  void start() => Interface.startSyncAction(msg, Source.barista);
  void complete([bool success = true]) {
    success
        ? Interface.writeRaw(
            '✓'.withColor(TextColor.green),
            LogType.log,
            Source.barista,
            false,
          )
        : Interface.writeRaw(
            '✗'.withColor(TextColor.red),
            LogType.log,
            Source.barista,
            false,
          );
    Interface.writeRaw('\n', LogType.log, Source.barista, false);
  }
}

class BaristaProcess extends InterfaceProcess {
  const BaristaProcess(super.msg);
}

enum TextColor {
  red,
  yellow,
  green,
  pink,
  cyan,
}

extension InterfaceUtils on String {
  String withColor(TextColor color) {
    switch (color) {
      case TextColor.red:
        return "\u001b[31m$this\u001b[0m";
      case TextColor.yellow:
        return "\u001b[33m$this\u001b[0m";
      case TextColor.green:
        return "\u001b[32$this\u001b[0m";
      case TextColor.pink:
        return "\u001b[35m$this\u001b[0m";
      case TextColor.cyan:
        return "\u001b[36m$this\u001b[0m";
    }
  }
}
