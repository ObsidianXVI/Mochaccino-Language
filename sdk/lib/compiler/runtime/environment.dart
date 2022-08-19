part of mochaccino.sdk.compiler.runtime;

class Environment {
  late CompileJob compileJob;
  final Map<String, MoccObj> values = {};
  final Environment? outer;

  Environment([this.outer = null]);

  void defineObject(String name, Object? value) {
    values[name] = value.toMoccObject();
  }

  MoccObj getAt(int distance, String name) {
    return ancestor(distance).values.get(name);
  }

  void assignAt(int distance, Token name, MoccObj value) {
    ancestor(distance).values[name.lexeme] = value;
  }

  Environment ancestor(int distance) {
    Environment environment = this;
    for (int i = 0; i < distance; i++) {
      environment = environment.outer!;
    }

    return environment;
  }

  void redefineObject(Token name, Object? value) {
    if (values.containsKey(name.lexeme)) {
      values[name.lexeme] = value.toMoccObject();
    } else if (outer != null) {
      return outer!.redefineObject(name, value);
    } else {
      throw ReferenceError(
        ReferenceError.undefinedObject(name.lexeme),
        lineNo: name.lineNo,
        offendingLine: compileJob.source.split('\n')[name.lineNo],
        start: name.start,
        description:
            "The variable '${name.lexeme}' has not been defined in the current scope and cannot be assigned to. Try adding the 'var' keyword to initialise the variable.",
        source: Source.interpreter,
      );
    }
  }

  MoccObj getObject(Token token) {
    if (values.containsKey(token.lexeme)) {
      return values[token.lexeme]!;
    } else if (outer != null) {
      return outer!.getObject(token);
    } else {
      throw ReferenceError(
        ReferenceError.undefinedObject(token.lexeme),
        lineNo: token.lineNo,
        offendingLine: compileJob.source.split('\n')[token.lineNo],
        start: token.start,
        description:
            "Try defining the object in a scope from which it can be accessed here.",
        source: Source.interpreter,
      );
    }
  }
}

final Environment coreLibEnv = Environment();
