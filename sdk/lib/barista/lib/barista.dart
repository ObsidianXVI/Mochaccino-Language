library mochaccino.barista;

import 'dart:io';

import './commands/commands.dart';
import './interface/interface.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    Interface.writeErr("Argument list is empty", Source.barista);
    exit(2);
  }
  switch (args.first) {
    case "init":
      // loading spinner
      Commands.init(args);
      break;
    case "run":
      Commands.run(args);
      break;
    default:
      Interface.writeErr("Command '${args.first}' not found", Source.barista);
      break;
  }
}
