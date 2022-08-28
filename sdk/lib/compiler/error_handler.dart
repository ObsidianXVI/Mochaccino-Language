part of mochaccino.sdk.compiler;

class ErrorHandler {
  static final List<Issue> issues = [];
  static String currentFileName = 'main.mocc';
  static String currentFilePath = '<ANONYMOUS>';
  static final List<String> lines = [];
}

abstract class Issue implements Exception {
  final String title;
  final String filePath = ErrorHandler.currentFilePath;
  final String fileName = ErrorHandler.currentFileName;
  final int lineNo;
  final String offendingLine;
  final int start;
  final String description;
  final Source source;
  Issue(
    this.title, {
    required this.lineNo,
    required this.offendingLine,
    required this.start,
    required this.description,
    required this.source,
  });

  String get consoleString {
    return """
${toString().replaceAll("Instance of '", '').replaceAll("'", '')}: $title
  $description
  [$fileName:$lineNo]:
    ${lineNo + 1}| $offendingLine
""";
  }
}

class PackageError extends Issue {
  PackageError(
    super.title, {
    required super.lineNo,
    required super.offendingLine,
    required super.start,
    required super.description,
    required super.source,
  });
}

class SyntaxError extends Issue {
  SyntaxError(
    super.title, {
    required super.lineNo,
    required super.offendingLine,
    required super.start,
    required super.description,
    required super.source,
  });

  static String unterminatedPair(String pair) => "Unterminated '$pair' pair";
  static String unexpectedChar(String char) => "Unexpected character '$char'";
  static String unexpectedToken(Token token) =>
      "Unexpected token '${token.lexeme}'";
  static String invalidPropertyAccess() =>
      "Property access can only be used on struct instances";
  static String invalidFieldAccess() =>
      "Field access can only be used on struct instances";
  static String invalidThisKeyword() =>
      "The 'this' keyword can only be used inside structs";
  static String invalidReturnKeyword() =>
      "Return statements cannot be used in struct initialisers";
  static String invalidSuperKeyword() =>
      "The 'super' keyword cannot be used in this context";
}

class TypeError extends Issue {
  TypeError(
    super.title, {
    required super.lineNo,
    required super.offendingLine,
    required super.start,
    required super.description,
    required super.source,
  });

  static String operationTypeError(
          String op, Type expectedType, Type givenType) =>
      "Operation '$op' requires operand(s) to be [$expectedType] but [$givenType] given instead.";
}

class ReferenceError extends Issue {
  ReferenceError(
    super.title, {
    required super.lineNo,
    required super.offendingLine,
    required super.start,
    required super.description,
    required super.source,
  });
  static String undefinedObject(String name) => "Name '$name' not defined";
  static String invalidAssignmentTarget(String name) =>
      "'$name' is an invalid assignment target";
  static String nameIsWrongType(
          String name, Type expectedType, Type givenType) =>
      "'$name' should be <$expectedType> but <$givenType> was given instead";
}

class StackError extends Issue {
  StackError(
    super.title, {
    required super.lineNo,
    required super.offendingLine,
    required super.start,
    required super.description,
    required super.source,
  });
}

class ArgumentError extends Issue {
  ArgumentError(
    super.title, {
    required super.lineNo,
    required super.offendingLine,
    required super.start,
    required super.description,
    required super.source,
  });

  static String tooManyArguments(int argsCount) =>
      "Too many arguments provided ($argsCount)";

  static String tooManyParameters(int paramsCount) =>
      "Too many parameters defined ($paramsCount)";

  static String wrongNumberOfArguments(int expectedCount, int argsCount) =>
      "Expected $expectedCount positional arguments, but $argsCount provided";
}

class NameError extends Issue {
  NameError(
    super.title, {
    required super.lineNo,
    required super.offendingLine,
    required super.start,
    required super.description,
    required super.source,
  });

  static String alreadyDefined(Token name) =>
      "Name '${name.lexeme}' already defined in this scope";

  static String accessSelfInInitialiser(String name) =>
      "The name '$name' can't be used in its own initialiser";

  static String undefinedName(String name) => "The name '$name' is not defined";
  static String cannotInheritFromSelf(String name) =>
      "The struct '$name' cannot inherit from itself";
}

abstract class StableException implements Exception {}

class Return extends StableException {
  final Object? value;

  Return(this.value);
}
