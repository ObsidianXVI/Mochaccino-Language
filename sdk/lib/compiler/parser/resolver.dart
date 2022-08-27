part of mochaccino.sdk.compiler;

enum StructType {
  none,
  struct,
}

enum FunctionType {
  none,
  function,
  method,
  initialiser,
}

class NameResolver {
  final Interpreter _interpreter;
  final Stack<Map<String, bool>> scopes = Stack<Map<String, bool>>();
  FunctionType _currentFunction = FunctionType.none;
  StructType _currentStruct = StructType.none;

  NameResolver(this._interpreter);

  void resolve(List<Statement> statements) {
    for (Statement statement in statements) {
      resolveStmt(statement);
    }
  }

  void resolveBlockStmt(BlockStmt stmt) {
    beginScope();
    resolve(stmt.statements);
    endScope();
  }

  void resolveStmt(Statement stmt) {
    if (stmt is InitialiserStmt) {
      resolveVarStatement(stmt);
    } else if (stmt is FuncDecl) {
      resolveFuncDecl(stmt);
    } else if (stmt is ExpressionStmt) {
      resolveExpressionStmt(stmt);
    } else if (stmt is IfStmt) {
      resolveIfStatement(stmt);
    } else if (stmt is ReturnStmt) {
      resolveReturnStmt(stmt);
    } else if (stmt is WhileStmt) {
      resolveWhileStmt(stmt);
    } else if (stmt is StructDecl) {
      resolveStructDecl(stmt);
    }
  }

  void resolveStructDecl(StructDecl stmt) {
    StructType enclosingStruct = _currentStruct;
    _currentStruct = StructType.struct;
    declare(stmt.name);
    define(stmt.name);
    beginScope();
    scopes.peek()["this"] = true;

    for (FuncDecl method in stmt.methods) {
      FunctionType funcType = FunctionType.method;
      if (method.name.lexeme == "init") {
        funcType = FunctionType.initialiser;
      }
      resolveFunctionBody(method, funcType);
    }
    endScope();
    _currentStruct = enclosingStruct;
  }

  void resolveWhileStmt(WhileStmt stmt) {
    resolveExpression(stmt.condition);
    resolveStmt(stmt.body);
  }

  void resolveReturnStmt(ReturnStmt stmt) {
    if (_currentFunction == FunctionType.none) {
      throw SyntaxError(
        SyntaxError.unexpectedToken(stmt.keyword),
        lineNo: stmt.keyword.lineNo,
        offendingLine: ErrorHandler.lines[stmt.keyword.lineNo],
        start: stmt.keyword.start,
        description:
            "'return' keyword can't be used in top-level code. Try removing the keyword.",
        source: Source.analyser,
      );
    } else if (_currentFunction == FunctionType.initialiser) {
      throw SyntaxError(
        SyntaxError.invaludReturnKeyword(),
        lineNo: stmt.keyword.lineNo,
        offendingLine: ErrorHandler.lines[stmt.keyword.lineNo],
        start: stmt.keyword.start,
        description: "Try removing the 'return' keyword.",
        source: Source.analyser,
      );
    }
    if (stmt.value != null) {
      resolveExpression(stmt.value!);
    }
  }

  void resolveExpressionStmt(ExpressionStmt stmt) {
    resolveExpression(stmt.expression);
  }

  void resolveIfStatement(IfStmt stmt) {
    resolveExpression(stmt.condition);
    resolveStmt(stmt.thenBranch);
    if (stmt.elseBranch != null) resolveStmt(stmt.elseBranch!);
  }

  void resolveFuncDecl(FuncDecl stmt) {
    declare(stmt.name);
    define(stmt.name);

    resolveFunctionBody(stmt, FunctionType.function);
  }

  void resolveFunctionBody(FuncDecl decl, FunctionType functionType) {
    FunctionType enclosingFunction = _currentFunction;
    _currentFunction = functionType;
    beginScope();
    for (Token param in decl.params) {
      declare(param);
      define(param);
    }
    resolve(decl.body);

    endScope();
    _currentFunction = enclosingFunction;
  }

  void resolveExpression(Expression expr) {
    if (expr is VariableReference) {
      resolveVariableReference(expr);
    } else if (expr is VariableAssignment) {
      resolveVariableAssignment(expr);
    } else if (expr is BinaryExp) {
      resolveBinaryExpr(expr);
    } else if (expr is InvocationExpression) {
      resolveInvocationExpr(expr);
    } else if (expr is Group) {
      resolveGroupExpr(expr);
    } else if (expr is LogicalExp) {
      resolveLogicalExpr(expr);
    } else if (expr is UnaryExp) {
      resolveUnaryExpr(expr);
    } else if (expr is GetExpression) {
      resolveGetExpression(expr);
    } else if (expr is SetExpression) {
      resolveSetExpression(expr);
    } else if (expr is ThisReference) {
      resolveThisReference(expr);
    }
  }

  void resolveThisReference(ThisReference expr) {
    if (_currentStruct == StructType.none) {
      throw SyntaxError(
        SyntaxError.invalidThisKeyword(),
        lineNo: expr.keyword.lineNo,
        offendingLine: ErrorHandler.lines[expr.keyword.lineNo],
        start: expr.keyword.start,
        description:
            "Ensure that the keyword is placed inside the struct body, and check for other syntax errors.",
        source: Source.analyser,
      );
    }
    resolveLocal(expr, expr.keyword);
  }

  void resolveSetExpression(SetExpression expr) {
    resolveExpression(expr.value);
    resolveExpression(expr.object);
  }

  void resolveGetExpression(GetExpression expr) {
    resolveExpression(expr.object);
  }

  void resolveUnaryExpr(UnaryExp expr) {
    resolveExpression(expr.value);
  }

  void resolveLogicalExpr(LogicalExp expr) {
    resolveExpression(expr.leftOperand);
    resolveExpression(expr.rightOperand);
  }

  void resolveGroupExpr(Group expr) {
    resolveExpression(expr.expression);
  }

  void resolveInvocationExpr(InvocationExpression expr) {
    resolveExpression(expr.callee);

    for (Expression argument in expr.arguments) {
      resolveExpression(argument);
    }
  }

  void resolveBinaryExpr(BinaryExp expr) {
    resolveExpression(expr.leftOperand);
    resolveExpression(expr.rightOperand);
  }

  void resolveVariableReference(VariableReference expr) {
    if (!scopes.isEmpty && scopes.peek()[expr.name.lexeme] == false) {
      throw NameError(
        NameError.accessSelfInInitialiser(expr.name.lexeme),
        lineNo: expr.name.lineNo,
        offendingLine: ErrorHandler.lines[expr.name.lineNo],
        start: expr.name.start,
        description: "Can't read local variable in its own initializer.",
        source: Source.analyser,
      );
    }

    resolveLocal(expr, expr.name);
  }

  void resolveVariableAssignment(VariableAssignment expr) {
    resolveExpression(expr.value);
    resolveLocal(expr, expr.name);
  }

  void resolveLocal(Expression expr, Token name) {
    for (int i = scopes.size - 1; i >= 0; i--) {
      if (scopes.get(i).containsKey(name.lexeme)) {
        _interpreter.resolve(expr, scopes.size - 1 - i);
        return;
      }
    }
  }

  void resolveVarStatement(InitialiserStmt stmt) {
    declare(stmt.name);
    if (stmt.initialiser != null) {
      resolveExpression(stmt.initialiser!);
    }
    define(stmt.name);
  }

  void declare(Token name) {
    if (scopes.isEmpty) return;

    final Map<String, bool> scope = scopes.peek();
    if (scope.containsKey(name.lexeme)) {
      throw NameError(
        NameError.alreadyDefined(name),
        lineNo: name.lineNo,
        offendingLine: ErrorHandler.lines[name.lineNo],
        start: name.start,
        description:
            "The name '${name.lexeme}' has already been initialised in this scope. Use a different name, or remove the 'var' keyword.",
        source: Source.analyser,
      );
    }
    scope[name.lexeme] = false;
  }

  void define(Token name) {
    if (scopes.isEmpty) return;
    scopes.peek()[name.lexeme] = true;
  }

  void beginScope() => scopes.push(<String, bool>{});

  void endScope() => scopes.pop();
}

class Stack<E> {
  final List<E> stack = [];

  bool get isEmpty => stack.isEmpty;
  int get size => stack.length;

  void push(E element) => stack.add(element);
  E pop() => stack.removeLast();
  E peek() => stack.last;
  E get(int index) => stack[index];
}
