part of mochaccino.sdk.compiler;

class Interpreter {
  final List<Statement> statements;
  final CompileJob compileJob;
  final List<String> sourceLines = [];
  Environment environment = Environment();
  late Environment _global;

  Interpreter(this.statements, this.compileJob) {
    sourceLines.addAll(compileJob.source.split('\n'));
    environment.compileJob = compileJob;
    _global = environment;
  }

  void _loadPortedObjects() {
    environment.defineObject('log', Log());
  }

  void interpret() {
    try {
      _loadPortedObjects();
      for (Statement stmt in statements) {
        interpretStmt(stmt);
      }
    } on Issue catch (runtimeError) {
      ErrorHandler.issues.add(runtimeError);
      for (Issue i in ErrorHandler.issues) {
        Interface.writeErr(i.consoleString, Source.interpreter);
      }
    } catch (e, st) {
      print(e);
      print(st);
    }
  }

  void interpretStmt(Statement stmt) {
    if (stmt is InitialiserStmt) {
      interpretInitialiserStmt(stmt);
    } else if (stmt is ExpressionStmt) {
      interpretExpressionStmt(stmt);
    } else if (stmt is OkStmt) {
      interpretOkStmt(stmt);
    } else if (stmt is BlockStmt) {
      interpretBlockStmt(stmt);
    } else if (stmt is IfStmt) {
      interpretIfStmt(stmt);
    } else if (stmt is WhileStmt) {
      interpretWhileStmt(stmt);
    } else if (stmt is FuncDecl) {
      interpretFuncDecl(stmt);
    } else if (stmt is ReturnStmt) {
      interpretReturnStmt(stmt);
    }
  }

  void interpretReturnStmt(ReturnStmt stmt) {
    Object? value = null;
    if (stmt.value != null) value = evaluateExpression(stmt.value!);

    throw Return(value);
  }

  void interpretFuncDecl(FuncDecl decl) {
    final MoccFn function = MoccFn(decl);
    environment.defineObject(decl.name.lexeme, function);
  }

  void interpretWhileStmt(WhileStmt stmt) {
    while (isTruthy(evaluateExpression(stmt.condition))) {
      interpretStmt(stmt.body);
    }
  }

  void interpretIfStmt(IfStmt stmt) {
    if (isTruthy(evaluateExpression(stmt.condition))) {
      interpretStmt(stmt.thenBranch);
    } else if (stmt.elseBranch != null) {
      interpretStmt(stmt.elseBranch!);
    }
  }

  void interpretBlockStmt(BlockStmt stmt) {
    executeBlock(stmt.statements, Environment(environment));
  }

  void executeBlock(List<Statement?> statements, Environment environment) {
    Environment previous = this.environment;
    try {
      this.environment = environment;

      for (Statement? statement in statements) {
        if (statement != null) interpretStmt(statement);
      }
    } finally {
      this.environment = previous;
    }
  }

  void interpretInitialiserStmt(InitialiserStmt stmt) {
    Object? value = null;
    if (stmt.initialiser != null) {
      value = evaluateExpression(stmt.initialiser!);
    }

    environment.defineObject(stmt.name.lexeme, value);
  }

  Object? interpretVarReference(VariableReference expr) {
    return environment.getObject(expr.name).innerValue;
  }

  Object? interpretVarAssignment(VariableAssignment expr) {
    Object? value = evaluateExpression(expr.value);
    environment.redefineObject(expr.name, value);
    return value;
  }

  void interpretExpressionStmt(ExpressionStmt stmt) {
    evaluateExpression(stmt.expression);
  }

  void interpretOkStmt(OkStmt stmt) {
    Object? value = evaluateExpression(stmt.expression);
    Interface.writeLog("OK:${value.toString()}", Source.program);
  }

  Object? interpretLiteral(Value value) {
    return value.value;
  }

  Object? interpretGroup(Group group) {
    return evaluateExpression(group.expression);
  }

  Object? evaluateExpression(Expression expr) {
    if (expr is BinaryExp) {
      return interpretBinary(expr);
    } else if (expr is UnaryExp) {
      return interpretUnary(expr);
    } else if (expr is Group) {
      return interpretGroup(expr);
    } else if (expr is Literal) {
      return interpretLiteral((expr as Value));
    } else if (expr is VariableReference) {
      return interpretVarReference(expr);
    } else if (expr is VariableAssignment) {
      return interpretVarAssignment(expr);
    } else if (expr is InvocationExpression) {
      return interpretInvocationExpression(expr);
    }

    return null;
  }

  bool isTruthy(Object? obj) {
    if (obj == null) return false;
    if (obj is bool) return obj;
    return true;
  }

  bool isEqual(Object? left, Object? right) {
    if (left == null && right == null) return true;
    if (left == null) return false;

    return (left == right);
  }

  void checkBooleanOperand(dynamic op, Object? operand, Token token) {
    if (operand is bool) return;
    throw TypeError(
      TypeError.operationTypeError(token.lexeme, bool, operand.runtimeType),
      lineNo: token.lineNo,
      start: token.start,
      offendingLine: sourceLines[token.lineNo],
      description:
          "The operation '${token.lexeme}' requires that the operand '$operand' be of type [bool], but the type given is [${operand.runtimeType}].",
      source: Source.interpreter,
    );
  }

  void checkNumberOperand(dynamic op, Object? operand, Token token) {
    if (operand is double) return;
    throw TypeError(
      TypeError.operationTypeError(token.lexeme, double, operand.runtimeType),
      lineNo: token.lineNo,
      start: token.start,
      offendingLine: sourceLines[token.lineNo],
      description:
          "The operation '${token.lexeme}' requires that the operand '$operand' be of type [num], but the type given is [${operand.runtimeType}].",
      source: Source.interpreter,
    );
  }

  void checkNumberOperands(
      dynamic op, Object? leftOperand, Object? rightOperand, Token token) {
    if (leftOperand is double && rightOperand is double) return;
    if (!(leftOperand is double)) {
      throw TypeError(
        TypeError.operationTypeError(
          token.lexeme,
          double,
          leftOperand.runtimeType,
        ),
        lineNo: token.lineNo,
        start: token.start,
        offendingLine: sourceLines[token.lineNo],
        description:
            "The operation '${token.lexeme}' requires that the operand '$leftOperand' be of type [num], but the type given is [${leftOperand.runtimeType}].",
        source: Source.interpreter,
      );
    } else {
      throw TypeError(
        TypeError.operationTypeError(
          token.lexeme,
          double,
          rightOperand.runtimeType,
        ),
        lineNo: token.lineNo,
        start: token.start,
        offendingLine: sourceLines[token.lineNo],
        description:
            "The operation '${token.lexeme}' requires that the operand '$rightOperand' be of type [num], but the type given is [${rightOperand.runtimeType}].",
        source: Source.interpreter,
      );
    }
  }

  Object? interpretUnary(UnaryExp expr) {
    Object? value = evaluateExpression(expr.value);

    switch (expr.unaryPrefix.symbol) {
      case UnaryPrefixSymbol.minus:
        checkNumberOperand(expr.unaryPrefix.symbol, value, expr.unaryPrefix.op);
        return -(int.parse(value.toString()));
      case UnaryPrefixSymbol.bang:
        checkBooleanOperand(
            expr.unaryPrefix.symbol, value, expr.unaryPrefix.op);
        return !(isTruthy(value));
    }
  }

  Object? interpretBinary(BinaryExp expr) {
    Object? left = evaluateExpression(expr.leftOperand);
    Object? right = evaluateExpression(expr.rightOperand);
    if (expr is EqualityExp) {
      switch (expr.op.symbol) {
        case EqualitySymbol.isEqual:
          return isEqual(left, right);
        case EqualitySymbol.isNotEqual:
          return !isEqual(left, right);
      }
    } else if (expr is LogicalExp) {
      switch (expr.op.symbol) {
        case LogicalSymbol.and:
          checkBooleanOperand(expr.op.symbol, left, expr.op.op);
          checkBooleanOperand(expr.op.symbol, right, expr.op.op);
          return (left as bool) && (right as bool);
        case LogicalSymbol.or:
          checkBooleanOperand(expr.op.symbol, left, expr.op.op);
          checkBooleanOperand(expr.op.symbol, right, expr.op.op);
          return (left as bool) || (right as bool);
      }
    } else if (expr is ComparativeExp) {
      switch (expr.op.symbol) {
        case ComparativeSymbol.greaterThan:
          checkNumberOperands(expr.op, left, right, expr.op.op);
          return (left as double) > (right as double);
        case ComparativeSymbol.greaterThanEqual:
          checkNumberOperands(expr.op, left, right, expr.op.op);
          return (left as double) >= (right as double);
        case ComparativeSymbol.lessThan:
          checkNumberOperands(expr.op, left, right, expr.op.op);
          return (left as double) < (right as double);
        case ComparativeSymbol.lessThanEqual:
          checkNumberOperands(expr.op, left, right, expr.op.op);
          return (left as double) <= (right as double);
      }
    } else if (expr is ArithmeticExp) {
      switch (expr.op.symbol) {
        case ArithmeticSymbol.minus:
          checkNumberOperands(expr.op, left, right, expr.op.op);
          return (left as double) - (right as double);
        case ArithmeticSymbol.divide:
          checkNumberOperands(expr.op, left, right, expr.op.op);
          return (left as double) / (right as double);
        case ArithmeticSymbol.star:
          checkNumberOperands(expr.op, left, right, expr.op.op);
          return (left as double) * (right as double);
        case ArithmeticSymbol.plus:
          if ((left is double) && (right is double)) {
            return left + right;
          } else if (left is String && right is String) {
            return left + right;
          } else {
            if (left is double) {
              throw TypeError(
                TypeError.operationTypeError(
                  expr.op.op.lexeme,
                  double,
                  right.runtimeType,
                ),
                lineNo: expr.op.op.lineNo,
                start: expr.op.op.start,
                offendingLine: sourceLines[expr.op.op.lineNo],
                description:
                    "The operation '${expr.op.op.lexeme}' requires that the right operand '$right' be of type [num] because the left operand is of type [num], but the type given is [${right.runtimeType}].",
                source: Source.interpreter,
              );
            } else if (left is String) {
              throw TypeError(
                TypeError.operationTypeError(
                  expr.op.op.lexeme,
                  String,
                  right.runtimeType,
                ),
                lineNo: expr.op.op.lineNo,
                start: expr.op.op.start,
                offendingLine: sourceLines[expr.op.op.lineNo],
                description:
                    "The operation '${expr.op.op.lexeme}' requires that the right operand '$right' be of type [str] because the left operand is of type [str], but the type given is [${right.runtimeType}].",
                source: Source.interpreter,
              );
            }
          }
      }
    }
    return null;
  }

  Object? interpretInvocationExpression(InvocationExpression invocation) {
    Object? callee = evaluateExpression(invocation.callee);

    final List<MoccObject> arguments = [];
    for (Expression argument in invocation.arguments) {
      arguments.add(evaluateExpression(argument).toMoccObject());
    }

    if (callee is! MoccInv) {
      throw TypeError(
        TypeError.operationTypeError("()", MoccInv, callee.runtimeType),
        lineNo: invocation.paren.lineNo,
        offendingLine: sourceLines[invocation.paren.lineNo],
        start: invocation.paren.start,
        description:
            "A value of type [${callee.runtimeType}] can't be invoked.",
        source: Source.interpreter,
      );
    }
    MoccFn moccInovation = callee as MoccFn;
    final Arguments args = Arguments(positionalArgs: arguments);
    print(args.positionalArgs);
    args.checkArity(moccInovation.declaration.parameters, invocation.paren,
        sourceLines[invocation.paren.lineNo]);
    return moccInovation.call(this, args);
  }
}

extension ObjectUtils on Object? {
  MoccObject toMoccObject() {
    if (this == null) return const MoccNull();
    if (this is int) return MoccInt(this as int);
    if (this is double) return MoccDbl(this as double);
    if (this is bool) return MoccBool(this as bool);
    if (this is String) return MoccStr(this as String);
    return MoccDyn(this as dynamic);
  }
}

class Parameters {
  final List<Map<String, Type>> positionalArgs;
  final Map<String, Map<MoccType, MoccObject>> namedArgs;

  Parameters({required this.positionalArgs, required this.namedArgs});
}

class Arguments {
  final List<MoccObject> positionalArgs;
  final Map<String, MoccObject> namedArgs;

  const Arguments({this.positionalArgs = const [], this.namedArgs = const {}});

  void checkArity(Parameters parameters, Token paren, String offendingLine) {
    /// check if positional args are sufficient (DO NOT CHECK TYPE)
    /// check if required named args are provided
    /// check if too many args provided
    final int underflow =
        parameters.positionalArgs.length - positionalArgs.length;
    if (underflow > 0) {
      throw ArgumentError(
        ArgumentError.wrongNumberOfArguments(
            parameters.positionalArgs.length, positionalArgs.length),
        lineNo: paren.lineNo,
        offendingLine: offendingLine,
        start: paren.start,
        description:
            "Try adding $underflow more arguments for ${parameters.positionalArgs.sublist(parameters.positionalArgs.length - underflow).map((e) => "${e}").toList().join(', ')}.",
        source: Source.interpreter,
      );
    } else if (underflow < 0) {
      throw ArgumentError(
        ArgumentError.wrongNumberOfArguments(
            parameters.positionalArgs.length, positionalArgs.length),
        lineNo: paren.lineNo,
        offendingLine: offendingLine,
        start: paren.start,
        description: "Try removing ${-underflow} arguments.",
        source: Source.interpreter,
      );
    }
  }

  //todo: check named args
}
