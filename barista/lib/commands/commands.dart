library mochaccino.barista.commands;

import 'dart:io';

import '../interface/interface.dart';

class Commands {
  static void init(List<String> args) async {
    if (args.length >= 2) {
      String projName = args[1];
      // check filename
      if (projName.contains(' ')) {
        projName = args[1].replaceAll(' ', '_');
        Interface.writeWarn(
          "'${args[1]}' isn't allowed as project name, using '$projName' instead",
          Source.barista,
        );
      }
      BaristaProcess proc = BaristaProcess('Creating project files...')
        ..start();
      Directory projDir = await Directory('./$projName').create();
      Directory('./$projName/bin').create();
      Directory('./$projName/src').create();
      Directory('./$projName/tests').create();
      Directory('./$projName/sripts').create();
      File configsFile = await File('./$projName/caffeine.json').create();
      File mainFile = await File('./$projName/src/main.mocc').create();
      Future.delayed(const Duration(seconds: 3), () {
        proc.complete();
      });
    } else {
      Interface.writeErr(
          "1 positional argument expected:\nbar init <proj_name>",
          Source.barista);
    }
  }
}
