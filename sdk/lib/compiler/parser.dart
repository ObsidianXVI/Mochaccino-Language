part of mochaccino.sdk.compiler;

class Parser extends CompileComponent {
  final List<String> sourceLines = [];
  final List<Token> tokens;
  final CompileResult compileResult;
  final CompileJob compileJob;
  int current = 0;

  Parser(this.tokens, this.compileResult, this.compileJob) {
    sourceLines.addAll(compileJob.source.split('\n'));
  }

  List<Statement> parse() {
    final List<Statement> statements = [];
    while (!atEnd) {
      Statement? stmt = parseDeclaration();
      if (stmt != null) statements.add(stmt);
    }
    // DEBUG: print out generated tokens
    for (Statement stmt in statements) {
      compileResult.logs.add(
        ConsoleLog(
          LogType.info,
          stmt.toTree(0),
          Source.parser,
          debug: true,
        ),
      );
    }
    return statements;
  }

  void synchronize() {
    advance();

    while (!atEnd) {
      if (previous().tokenType == TokenType.SEMICOLON) return;

      switch (peek().tokenType) {
        case TokenType.STRUCT:
        case TokenType.FUNC:
        case TokenType.VAR:
        case TokenType.FOR:
        case TokenType.IF:
        case TokenType.WHILE:
        case TokenType.RETURN:
        case TokenType.OK:
        case TokenType.NOTOK:
        case TokenType.PROP:
        case TokenType.INCLUDE:
        case TokenType.MODULE:
        case TokenType.STATIC:
        case TokenType.DEBUG_FLAG:
        case TokenType.DOCK:
        case TokenType.PACKAGE:
        case TokenType.GUARDED:
          return;
      }

      advance();
    }
  }

  Statement? parseDeclaration() {
    try {
      if (match([TokenType.VAR])) return parseVarDecl();
      return parseStatement();
    } catch (e) {
      synchronize();
      return null;
    }
  }

  Statement parseVarDecl() {
    Token name = consume(TokenType.IDENTIFIER, "Expected an identifier");

    Expression initialiser = Value(null);

    if (match([TokenType.ANGLED_LEFT]))
      null; // type annotation `parseTypeAnnotation`

    if (match([TokenType.EQUAL])) {
      initialiser = parseExpression();
    }

    consume(TokenType.SEMICOLON, "Expect ';' after variable declaration.");
    return new InitialiserStmt(name, mocc.Object(null), initialiser);
  }

  Statement parseStatement() {
    if (match([TokenType.OK])) return parseOkStmt();

    return parseExpressionStmt();
  }

  Statement parseOkStmt() {
    Expression value = parseExpression();
    consume(TokenType.SEMICOLON, ';');
    return OkStmt(value);
  }

  Statement parseExpressionStmt() {
    Expression expression = parseExpression();
    consume(TokenType.SEMICOLON, ';');
    return ExpressionStmt(expression);
  }

  Expression parseExpression() => parseEquality();
  Expression parseEquality() {
    Expression expr = parseLogical();

    while (match([TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL])) {
      Token op = previous();
      Expression rightOperand = parseLogical();
      expr = EqualityExp(expr, EqualityOp(op), rightOperand);
    }

    return expr;
  }

  Expression parseLogical() {
    Expression expr = parseComparison();

    while (match([
      TokenType.AMPERSAND_AMPERSAND,
      TokenType.PIPE_PIPE,
    ])) {
      Token op = previous();
      Expression rightOperand = parseComparison();
      expr = LogicalExp(expr, LogicalOp(op), rightOperand);
    }

    return expr;
  }

  Expression parseComparison() {
    Expression expr = parseArithmetic();

    while (match([
      TokenType.ANGLED_LEFT,
      TokenType.ANGLED_LEFT_EQUAL,
      TokenType.ANGLED_RIGHT,
      TokenType.ANGLED_RIGHT_EQUAL,
    ])) {
      Token op = previous();
      Expression right = parseArithmetic();
      expr = ComparativeExp(expr, ComparativeOp(op), right);
    }

    return expr;
  }

  Expression parseArithmetic() {
    Expression expr = parseFactor();

    while (match([
      TokenType.PLUS,
      TokenType.MINUS,
    ])) {
      Token op = previous();
      Expression right = parseFactor();
      expr = ArithmeticExp(expr, ArithmeticOp(op), right);
    }

    return expr;
  }

  Expression parseFactor() {
    Expression expr = parseUnary();

    while (match([TokenType.SLASH, TokenType.STAR])) {
      Token op = previous();
      Expression right = parseUnary();
      expr = FactorExp(expr, ArithmeticOp(op), right);
    }

    return expr;
  }

  Expression parseUnary() {
    if (match([TokenType.BANG, TokenType.MINUS])) {
      Token op = previous();
      Expression right = parseValue();
      return UnaryExp(UnaryPrefixOp(op), right);
    }

    return parseValue();
  }

  Expression parseValue() {
    if (match([TokenType.FALSE])) return Value(false);

    if (match([TokenType.TRUE])) return Value(true);

    if (match([TokenType.NULL])) return Value(null);

    if (match([TokenType.NUMBER, TokenType.STRING]))
      return Value(previous().literal);

    if (match([TokenType.IDENTIFIER])) {
      return VariableReference(previous());
    }

    if (match([TokenType.LEFT_PAREN])) {
      Expression expr = parseExpression();
      consume(TokenType.RIGHT_PAREN, ')');
      return Group(expr);
    }

    throw SyntaxError(
      SyntaxError.unexpectedToken(peek()),
      lineNo: peek().lineNo,
      start: peek().start,
      offendingLine: sourceLines[peek().lineNo],
      description:
          "Expression expected, but token '${peek().lexeme}' was found. Token details:"
              .newline(peek().toString().indent(4)),
      source: Source.parser,
    );
  }

  bool match(List<TokenType> types) {
    for (TokenType type in types) {
      if (check(type)) {
        advance();
        return true;
      }
    }
    return false;
  }

  bool check(TokenType type) {
    if (atEnd) return false;
    return peek().tokenType == type;
  }

  Token advance() {
    if (!atEnd) current++;
    return previous();
  }

  bool get atEnd => peek().tokenType == TokenType.EOF;

  Token peek() {
    return tokens[current];
  }

  Token previous([int lookBehind = 1]) {
    return tokens[current - lookBehind];
  }

  Token consume(TokenType type, String expectedChar) {
    if (check(type)) return advance();
    throw SyntaxError(
      SyntaxError.unterminatedPair(expectedChar),
      lineNo: peek().lineNo,
      start: peek().start,
      offendingLine: sourceLines[peek().lineNo],
      description: "'$expectedChar' expected.",
      source: Source.parser,
    );
  }
}

abstract class Node {
  String toTree(int indent);
}

abstract class Statement implements Node {}

class ExpressionStmt extends Statement {
  final Expression expression;

  ExpressionStmt(this.expression);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}".indent(indent).newline(
          expression.toTree(indent + 2),
        );
  }
}

class InitialiserStmt extends Statement {
  final Token name;
  final mocc.MoccType objectType;
  final Expression? initialiser;

  InitialiserStmt(this.name, this.objectType, this.initialiser);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(
          "Variable: ${name.lexeme}".indent(indent + 2),
        )
        .newline(
          initialiser != null
              ? initialiser!.toTree(indent + 4)
              : Value(null).toTree(indent + 4),
        );
  }
}

class OkStmt extends Statement {
  final Expression expression;

  OkStmt(this.expression);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}".indent(indent).newline(
          expression.toTree(indent + 2),
        );
  }
}

abstract class Expression implements Node {}

class VariableReference implements Expression {
  final Token name;

  VariableReference(this.name);

  @override
  String toTree(int indent) => "MoccObject: ${name.lexeme}".indent(indent);
}

abstract class BinaryExp implements Expression {
  final Expression leftOperand;
  final Operator op;
  final Expression rightOperand;

  BinaryExp(this.leftOperand, this.op, this.rightOperand);
}

abstract class Operator implements Node {}

abstract class Keyword implements Node {}

abstract class Literal implements Node {}

class EqualityExp implements BinaryExp {
  final Expression leftOperand;
  final EqualityOp op;
  final Expression rightOperand;

  EqualityExp(this.leftOperand, this.op, this.rightOperand);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(
          op.toTree(indent + 2),
        )
        .newline(leftOperand.toTree(indent + 4))
        .newline(rightOperand.toTree(indent + 4));
  }

  @override
  String toString() => "$leftOperand $op $rightOperand";
}

class EqualityOp implements Operator {
  late EqualitySymbol symbol;
  final Token op;

  EqualityOp(this.op) {
    symbol = op.toSymbol();
  }

  @override
  String toTree(int indent) {
    return "${this.runtimeType}: ${symbol.toString().replaceAll('EqualitySymbol.', '')}"
        .indent(indent);
  }

  @override
  String toString() => op.lexeme;
}

class Group implements Expression {
  final Expression expression;

  Group(this.expression);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(expression.toTree(indent + 2));
  }

  @override
  String toString() => "$expression";
}

class ArithmeticExp implements BinaryExp {
  final Expression leftOperand;
  final ArithmeticOp op;
  final Expression rightOperand;

  ArithmeticExp(this.leftOperand, this.op, this.rightOperand);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(
          op.toTree(indent + 2),
        )
        .newline(leftOperand.toTree(indent + 4))
        .newline(rightOperand.toTree(indent + 4));
  }

  @override
  String toString() => "$leftOperand $op $rightOperand";
}

class FactorExp implements ArithmeticExp {
  final Expression leftOperand;
  final ArithmeticOp op;
  final Expression rightOperand;

  FactorExp(this.leftOperand, this.op, this.rightOperand);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(
          op.toTree(indent + 2),
        )
        .newline(leftOperand.toTree(indent + 4))
        .newline(rightOperand.toTree(indent + 4));
  }

  @override
  String toString() => "$leftOperand $op $rightOperand";
}

class UnaryExp implements Expression {
  final Expression value;
  final UnaryPrefixOp unaryPrefix;

  UnaryExp(this.unaryPrefix, this.value);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(
          unaryPrefix.toTree(indent + 2),
        )
        .newline(value.toTree(indent + 4));
  }

  @override
  String toString() => "$unaryPrefix$value";
}

class ArithmeticOp implements Operator {
  late ArithmeticSymbol symbol;
  final Token op;

  ArithmeticOp(this.op) {
    symbol = op.toSymbol() is List ? op.toSymbol()[0] : op.toSymbol();
  }

  @override
  String toTree(int indent) {
    return "${this.runtimeType}: ${symbol.toString().replaceAll('ArithmeticSymbol.', '')}"
        .indent(indent);
  }

  @override
  String toString() => op.lexeme;
}

class ComparativeExp implements BinaryExp {
  final Expression leftOperand;
  final ComparativeOp op;
  final Expression rightOperand;

  ComparativeExp(this.leftOperand, this.op, this.rightOperand);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(
          op.toTree(indent + 2),
        )
        .newline(leftOperand.toTree(indent + 4))
        .newline(rightOperand.toTree(indent + 4));
  }

  @override
  String toString() => "$leftOperand $op $rightOperand";
}

class ComparativeOp implements Operator {
  // comparative_op = "==" | "!=" | "<" | ">" | "<=" | ">=";
  late ComparativeSymbol symbol;
  final Token op;

  ComparativeOp(this.op) {
    symbol = op.toSymbol();
  }

  @override
  String toTree(int indent) {
    return "${this.runtimeType}: ${symbol.toString().replaceAll('ComparativeSymbol.', '')}"
        .indent(indent);
  }

  @override
  String toString() => op.lexeme;
}

class LogicalOp implements Operator {
  late LogicalSymbol symbol;
  final Token op;

  LogicalOp(this.op) {
    symbol = op.toSymbol();
  }

  @override
  String toTree(int indent) {
    return "${this.runtimeType}: ${symbol.toString().replaceAll('LogicalSymbol.', '')}"
        .indent(indent);
  }

  @override
  String toString() => op.lexeme;
}

class LogicalExp implements BinaryExp {
  final Expression leftOperand;
  final LogicalOp op;
  final Expression rightOperand;

  LogicalExp(this.leftOperand, this.op, this.rightOperand);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(
          op.toTree(indent + 2),
        )
        .newline(leftOperand.toTree(indent + 4))
        .newline(rightOperand.toTree(indent + 4));
  }

  @override
  String toString() => "$leftOperand $op $rightOperand";
}

class UnaryPrefixOp implements Operator {
  late UnaryPrefixSymbol symbol;
  final Token op;

  UnaryPrefixOp(this.op) {
    symbol = op.toSymbol() is List ? op.toSymbol()[1] : op.toSymbol();
  }

  @override
  String toTree(int indent) {
    return "${this.runtimeType}: ${symbol.toString().replaceAll('UnaryPrefixSymbol.', '')}"
        .indent(indent);
  }

  @override
  String toString() => op.lexeme;
}

class Value implements Literal, Expression {
  final dynamic value;

  Value(this.value);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}: [${value.runtimeType}] ${value.toString()}"
        .indent(indent);
  }

  @override
  String toString() => value.toString();
}
