part of mochaccino.sdk.compiler;

class CompileJob {
  final String source;
  final String fpath;
  late String fname;
  CompileJob(this.source, this.fpath) {
    fname = fpath.split('/').last;
    ErrorHandler.currentFileName = fname;
    ErrorHandler.currentFilePath = fpath;
  }
}

class CompileResult {
  final List<ConsoleLog> logs;
  const CompileResult(this.logs);
}

abstract class CompileComponent {
  const CompileComponent();
}

class Compiler extends CompileComponent {
  final CompileJob compileJob;

  const Compiler(this.compileJob);

  CompileResult compile() {
    final CompileResult compileResult = CompileResult([]);
    final Tokeniser tokeniser = Tokeniser(compileJob.source, compileResult);
    final Parser parser = Parser(
      tokeniser.tokenise(),
      compileResult,
      compileJob,
    );
    final Interpreter interpreter = Interpreter(parser.parse(), compileJob);
    interpreter.interpret();
    return compileResult;
  }
}

extension StringUtils on String {
  String indent(int indent, [String indentStr = '-']) =>
      "|" + (indentStr * indent) + this;
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
