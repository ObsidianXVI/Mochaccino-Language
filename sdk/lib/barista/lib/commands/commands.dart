library mochaccino.barista.commands;

import 'dart:convert';
import 'dart:io';

import '../interface/interface.dart';

import 'package:mochaccino_sdk/sdk.dart';

class Commands {
  static void run(List<String> args) {
    if (args.isNotEmpty) {
      CompilerEntryPoint.executeFile(args[1], args.contains('--debug'));
    } else {
      Interface.writeErr("1 positional argument expected:", Source.barista);
      Interface.writeErr(
          "  bar run <path/to/file.mocc> [--debug]", Source.barista);
    }
  }

  static void init(List<String> args) async {
    if (args.length >= 2) {
      String projName = args[1];
      String pkgName = projName;
      // check filename
      if (pkgName.contains(' ')) {
        pkgName = args[1].replaceAll(' ', '_');
        Interface.writeWarn(
          "'$projName' isn't allowed as a project name, using '$pkgName' instead",
          Source.barista,
        );
      }
      BaristaProcess proc = BaristaProcess(
        'Creating project files...',
        Source.barista,
      )..start();
      Directory projDir = await Directory('./$projName').create();
      Directory('./$projName/bin').create();
      Directory('./$projName/src').create();
      Directory('./$projName/tests').create();
      Directory('./$projName/sripts').create();
      Directory('./$projName/docs').create();
      File configsFile = await File('./$projName/caffeine.json').create();
      File mainFile = await File('./$projName/src/main.mocc').create();
      configsFile.writeAsString(jsonEncode({
        "name": projName,
        "description": "",
        "version": "0.0.1",
        "author": {"name": "Author Name", "github": ""},
        "environment": {
          "sdk": "0.0.1",
          "compiler": "0.0.1",
          "barista": "0.0.1"
        },
        "dependencies": [
          {"name": "package_name"}
        ],
        "factories": [
          {"name": "core", "path": "path/to/core_factory.dart"}
        ],
        "scripts": {"script-name": "path/to/script.mocc"}
      }));
      Future.delayed(const Duration(seconds: 3), () {
        proc.complete();
      });
    } else {
      Interface.writeErr("1 positional argument expected:", Source.barista);
      Interface.writeErr("  bar init <proj_name>", Source.barista);
    }
  }
}
