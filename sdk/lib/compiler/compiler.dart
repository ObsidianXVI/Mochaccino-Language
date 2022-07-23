library mochaccino.sdk.compiler;

import 'dart:io';
import './runtime/runtime.dart';

part './tokeniser.dart';
part './parser.dart';
part './interpreter.dart';
part './error_handler.dart';

class Compiler {
  final String source;

  Compiler(this.source);

  void compile([bool debugMode = false]) {}

  void compilex([bool debugMode = false]) {
    MochaccinoRuntime.sourceLines = source.split('\n');

    Tokeniser tokeniser = Tokeniser(source);
    List<Token> tokens = tokeniser.tokenise();
    if (debugMode) tokens.forEach(print);

    Parser parser = Parser(tokens, source.split('\n'));
    List<Statement> statements = parser.parse();
    if (debugMode) statements.forEach((Statement s) => print(s.toTree(0)));

    Interpreter interpreter = Interpreter(statements, source.split('\n'));
    interpreter.interpret();

    if (ErrorHandler.issues.isNotEmpty) {
      ErrorHandler.reportAll();
      exit(1);
    }
  }
}

void main(List<String> args) {
  bool debugMode = true;
  if (args.isNotEmpty && args[0] == 'nodebug') debugMode = false;
  String source = File("/workspaces/Mochaccino-Language/sdk/test/simple.mocc")
      .readAsStringSync();
  Compiler cortado = Compiler(source);
  if (debugMode) print('Compiling:\n$source\n');
  cortado.compile(debugMode);
  if (debugMode)
    print(
        "Compiled ${ErrorHandler.issues.isEmpty ? 'successfully' : 'unsuccessfully with ${ErrorHandler.issues.length} issues'}");
}

extension StringUtils on String {
  String indent(int indent) => "|" + ("-" * indent) + this;
  String newline(String text) => this + "\n" + text;
  bool get isNewline => (this == '\n');
  bool get isEOF => (this == 'EOF');
  bool get isDigit => (<String>[
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9'
      ].contains(this));
  bool get isAlphaNum => (<String>[
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'l',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z',
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
        'X',
        'Y',
        'Z',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '_'
      ].contains(this));

  bool get isAlpha => (<String>[
        'a',
        'b',
        'c',
        'd',
        'e',
        'f',
        'g',
        'h',
        'i',
        'j',
        'k',
        'l',
        'm',
        'n',
        'o',
        'p',
        'q',
        'r',
        's',
        't',
        'u',
        'v',
        'w',
        'x',
        'y',
        'z',
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
        'X',
        'Y',
        'Z',
        '_'
      ].contains(this));

  String charAt(int pos) => this[pos];
}
