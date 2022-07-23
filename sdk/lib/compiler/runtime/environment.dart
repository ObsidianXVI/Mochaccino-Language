part of mochaccino.sdk.compiler.runtime;

class Environment {
  static final Map<String, MoccObject> values = {};

  static void defineObject(String name, Object? value) {
    values[name] = MoccObject(value);
  }

  static MoccObject getObject(Token token) {
    if (values.containsKey(token.lexeme)) {
      return values[token.lexeme]!;
    }

    throw RuntimeError(
      Issue(
        IssueType.ReferenceError,
        IssueTitle.undefinedObject(token.lexeme),
        lineNo: token.lineNo,
        offendingLine: MochaccinoRuntime.sourceLines[token.lineNo],
        start: token.start,
        description:
            "Try defining the object in a scope from which it can be accessed here.",
      ),
    );
  }
}
