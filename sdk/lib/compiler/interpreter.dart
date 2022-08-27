part of mochaccino.sdk.compiler;

class Interpreter {
  final List<Statement> statements;
  final CompileJob compileJob;
  final List<String> sourceLines = [];
  final Map<Expression, int> locals = {};
  Environment environment = Environment();
  late Environment _global;

  Interpreter(this.statements, this.compileJob) {
    sourceLines.addAll(ErrorHandler.lines);
    environment.compileJob = compileJob;
    _global = environment;
    _loadPortedObjects();
  }

  void resolve(Expression expr, int depth) {
    locals[expr] = depth;
  }

  void _loadPortedObjects() {
    environment.defineObject('log', Log());
  }

  MoccObj lookupVariable(Token name, Expression expr) {
    final int? distance = locals[expr];
    if (distance != null) {
      return environment.getAt(distance, name.lexeme);
    } else {
      return _global.getObject(name);
    }
  }

  void interpret() {
    try {
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
    } else if (stmt is StructDecl) {
      interpretStructDecl(stmt);
    }
  }

  void interpretStructDecl(StructDecl stmt) {
    environment.defineObject(stmt.name.lexeme, null);
    final Map<String, MoccFn> methods = {};
    for (FuncDecl method in stmt.methods) {
      MoccFn function =
          MoccFn(method, environment, method.name.lexeme == "new");
      methods[method.name.lexeme] = function;
    }

    final MoccStruct struct = MoccStruct(stmt.name.lexeme, methods);
    environment.redefineObject(stmt.name, struct);
  }

  void interpretReturnStmt(ReturnStmt stmt) {
    Object? value;
    if (stmt.value != null) value = evaluateExpression(stmt.value!);

    throw Return(value);
  }

  void interpretFuncDecl(FuncDecl decl) {
    final MoccFn function = MoccFn(decl, environment, false);
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

  MoccObj interpretThisReference(ThisReference expr) {
    return lookupVariable(expr.keyword, expr);
  }

  MoccObj interpretVarReference(VariableReference expr) {
    return lookupVariable(expr.name, expr);
  }

  Object? interpretVarAssignment(VariableAssignment expr) {
    Object? value = evaluateExpression(expr.value);
    final int? distance = locals[expr];
    if (distance != null) {
      environment.assignAt(distance, expr.name, value.toMoccObject());
    } else {
      _global.redefineObject(expr.name, value);
    }
    return value;
  }

  Object? interpretSetExpression(SetExpression expr) {
    Object? object = evaluateExpression(expr.object);

    if (object is! MoccObjectInstance) {
      throw SyntaxError(
        SyntaxError.invalidFieldAccess(),
        lineNo: expr.name.lineNo,
        offendingLine: sourceLines[expr.name.lineNo],
        start: expr.name.start,
        description: "description",
        source: Source.interpreter,
      );
    }

    Object? value = evaluateExpression(expr.value);
    object.set(expr.name, value.toMoccObject());
    return value;
  }

  Object? interpretGetExpression(GetExpression expr) {
    final Object? object = evaluateExpression(expr.object);
    if (object is MoccObjectInstance) {
      return object.get(expr.name);
    }

    throw SyntaxError(
      SyntaxError.invalidPropertyAccess(),
      lineNo: expr.name.lineNo,
      offendingLine: sourceLines[expr.name.lineNo],
      start: expr.name.start,
      description:
          "Property access can only be performed on struct instances, but '${expr.name}' is not one.",
      source: Source.interpreter,
    );
  }

  void interpretExpressionStmt(ExpressionStmt stmt) {
    evaluateExpression(stmt.expression);
  }

  void interpretOkStmt(OkStmt stmt) {
    Object? value = evaluateExpression(stmt.expression);
    Interface.writeLog("OK:${value.toMoccObject().innerValue}", Source.program);
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
    } else if (expr is GetExpression) {
      return interpretGetExpression(expr);
    } else if (expr is SetExpression) {
      return interpretSetExpression(expr);
    } else if (expr is ThisReference) {
      return interpretThisReference(expr);
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
    if (leftOperand is! double) {
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
    final List<MoccObj> arguments = [];
    for (Expression argument in invocation.arguments) {
      /// These should be [Value]s, but a [VariableReference] is passed
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
    } else if (callee is MoccFn) {
      final MoccFn moccInovation = callee;
      final Arguments args = Arguments(positionalArgs: arguments);
      args.checkArity(moccInovation.declaration.parameters, invocation.paren,
          sourceLines[invocation.paren.lineNo]);
      return moccInovation.call(this, args);
    } else if (callee is MoccStruct) {
      final MoccStruct struct = callee;
      return struct.call(this, Arguments(positionalArgs: arguments));
    } else {
      throw UnimplementedError();
    }
  }
}

extension ObjectUtils on Object? {
  MoccObj toMoccObject() {
    if (this is MoccObj) return this as MoccObj;
    if (this == null) return const MoccNull();
    if (this is int) return MoccInt(this as int);
    if (this is double) return MoccDbl(this as double);
    if (this is bool) return MoccBool(this as bool);
    if (this is String) return MoccStr(this as String);
    /* if (this is dynamic) */ return MoccDyn(this as dynamic);
  }
}

class Parameters {
  final List<Map<String, Type>> positionalArgs;
  final Map<String, Map<MoccType, MoccObj>> namedArgs;

  Parameters({required this.positionalArgs, required this.namedArgs});
}

class Arguments {
  final List<MoccObj> positionalArgs;
  final Map<String, MoccObj> namedArgs;

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
