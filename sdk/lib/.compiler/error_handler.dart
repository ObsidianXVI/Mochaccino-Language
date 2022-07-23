part of mochaccino.sdk.compiler;

enum IssueType {
  SyntaxError,
  PackageError,
  StackError,
  TypeError,
  ReferenceError,
}

enum IssueReporter {
  console,
}

enum TextColor {
  red,
  yellow,
  green,
  pink,
  cyan,
}

class IssueTitle {
  static String unterminatedPair(String pair) => "Unterminated '$pair' pair";
  static String unexpectedChar(String char) => "Unexpected character '$char'";
  static String unexpectedToken(Token token) =>
      "Unexpected token '${token.lexeme}'";
  static String operationTypeError(
          String op, Type expectedType, Type givenType) =>
      "Operation '$op' requires operand(s) to be [$expectedType] but [$givenType] found instead.";
  static String undefinedObject(String name) =>
      "Mochaccino Object named '$name' not defined";
}

class Issue {
  final IssueType issueType;
  final String title;
  final String filePath;
  final int lineNo;
  final String offendingLine;
  final int start;
  final String description;

  Issue(
    this.issueType,
    this.title, {
    required this.lineNo,
    required this.offendingLine,
    required this.start,
    required this.description,
    this.filePath = 'MAIN',
  });

  String get consoleString {
    return """
${issueType.toString().replaceAll("IssueType.", "")}: $title
  in [$filePath]:
    $lineNo| $offendingLine
$description
""";
  }
}

class ErrorHandler {
  static final List<Issue> issues = [];

  static void reportAll([IssueReporter issueReporter = IssueReporter.console]) {
    if (issueReporter == IssueReporter.console) {
      issues.forEach((Issue issue) => print(issue.consoleString));
    }
  }
}

class StaticError implements Exception {}

class RuntimeError implements Exception {
  final Issue issue;

  RuntimeError(this.issue);
}

class ParseException implements StaticError {
  static ParseException raise(Issue issue) {
    ErrorHandler.issues.add(issue);
    return ParseException();
  }
}

extension ConsoleUtils on String {
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
