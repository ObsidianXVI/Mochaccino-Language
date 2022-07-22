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
}

extension EnumUtils on Source {
  String stringify() {
    if (this == Source.barista) return "BAR";
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
  static void writeWarn(String msg, Source source) =>
      Interface.write(msg, LogType.warn, source);
  static void writeInfo(String msg, Source source) =>
      Interface.write(msg, LogType.info, source);
  static void writeErr(String msg, Source source) =>
      Interface.write(msg, LogType.err, source);

  static void readInput() => stdin.pipe(stdout);

  static void startSyncAction(String msg, Source source) {
    Interface.writeRaw("  $msg".padRight(30), LogType.log, Source.barista);
  }
}

class BaristaProcess {
  final String msg;
  const BaristaProcess(this.msg);

  void start() => Interface.startSyncAction(msg, Source.barista);
  void complete() {
    Interface.writeRaw('✓', LogType.log, Source.barista, false);
    Interface.writeRaw('\n', LogType.log, Source.barista, false);
  }
}
