part of mochaccino.sdk.compiler;

class Interpreter {
  final List<Statement> statements;
  final CompileJob compileJob;
  final List<String> sourceLines = [];

  Interpreter(this.statements, this.compileJob) {
    sourceLines.addAll(compileJob.source.split('\n'));
  }

  void interpret() {
    try {
      for (Statement stmt in statements) {
        interpretStmt(stmt);
      }
    } on Issue catch (runtimeError) {
      ErrorHandler.issues.add(runtimeError);
      ErrorHandler.issues.forEach(
        (Issue i) => Interface.writeErr(i.consoleString, Source.interpreter),
      );
    } catch (e) {
      print(e);
    }
  }

  void interpretStmt(Statement stmt) {
    if (stmt is InitialiserStmt) {
      interpretInitialiserStmt(stmt);
    } else if (stmt is ExpressionStmt) {
      interpretExpressionStmt(stmt);
    } else if (stmt is OkStmt) {
      interpretOkStmt(stmt);
    }
  }

  void interpretInitialiserStmt(InitialiserStmt stmt) {
    Object? value = null;
    if (stmt.initialiser != null) {
      value = evaluateExpression(stmt.initialiser!);
    }

    Environment.defineObject(stmt.name.lexeme, value);
  }

  Object? interpretVarReference(VariableReference expr) {
    return Environment.getObject(expr.name).innerValue;
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
}
