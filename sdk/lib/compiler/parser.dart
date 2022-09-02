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
      final Statement? stmt = parseDeclaration();
      if (stmt != null) statements.add(stmt);
    }

    // DEBUG: print out generated tokens
    if (Interface.debugMode) {
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
    }
    return statements;
  }

  void synchronize() {
    advance();

    while (!atEnd) {
      if (previous().tokenType == TokenType.SEMICOLON) return;

      switch (peek().tokenType) {
        case TokenType.STRUCT:
        case TokenType.COLLECTION:
        case TokenType.FUNC:
        case TokenType.VAR:
        case TokenType.FOR:
        case TokenType.IF:
        case TokenType.WHILE:
        case TokenType.RETURN:
        case TokenType.OK:
        case TokenType.NOTOK:
        case TokenType.PROP:
        case TokenType.PORT:
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
      if (match([TokenType.FUNC])) return parseFuncDecl('function');
      if (match([TokenType.VAR])) return parseVarDecl();
      if (match([TokenType.STRUCT])) return parseStructDecl();
      return parseStatement();
    } on Issue catch (e) {
      ErrorHandler.issues.add(e);
      synchronize();
      return null;
    }
  }

  Statement parseStructDecl() {
    final Token name = consume(TokenType.IDENTIFIER, "Expected struct name.");
    final VariableReference? superstruct;
    if (match([TokenType.EXTENDS])) {
      consume(TokenType.IDENTIFIER, "Expected superstruct name.");
      superstruct = VariableReference(previous());
    } else {
      superstruct = null;
    }
    consume(TokenType.LEFT_BRACE, "Expected '{' before struct body.");

    final List<FuncDecl> methods = [];
    while (!check(TokenType.RIGHT_BRACE) && !atEnd) {
      if (match([TokenType.FUNC])) methods.add(parseFuncDecl("method"));
    }

    consume(TokenType.RIGHT_BRACE, "Expected '}' after struct body.");
    return StructDecl(name, methods, superstruct);
  }

  FuncDecl parseFuncDecl(String kind) {
    final Token name = consume(TokenType.IDENTIFIER, "Expected $kind name.");
    consume(TokenType.LEFT_PAREN, "Expected '(' after $kind name.");
    final List<Token> parameters = [];
    if (!check(TokenType.RIGHT_PAREN)) {
      do {
        if (parameters.length >= 200) {
          ErrorHandler.issues.add(
            ArgumentError(
              ArgumentError.tooManyParameters(parameters.length),
              lineNo: peek().lineNo,
              start: peek().start,
              offendingLine: sourceLines[peek().lineNo],
              description:
                  "Try limiting the number of parameters to under 200.",
              source: Source.parser,
            ),
          );
        }

        parameters
            .add(consume(TokenType.IDENTIFIER, "Expected parameter name."));
      } while (match([TokenType.COMMA]));
    }
    consume(TokenType.RIGHT_PAREN, "Expected ')' after parameter list.");
    final TypeAnnotation? typeAnnot = parseFullTypeAnnotation();
    if (typeAnnot == null) {
      final Token currentTok = peek();
      throw SyntaxError(
        SyntaxError.typeAnnotationExpected(),
        lineNo: currentTok.lineNo,
        offendingLine: ErrorHandler.lines[currentTok.lineNo],
        start: currentTok.start,
        description:
            "Expected a type annotation to specify the function's return type. Try adding '<void>' if the function does not return anything, or returns null.",
        source: Source.parser,
      );
    }
    final InferredType inferredType = InferredType(name, reference: typeAnnot);
    consume(TokenType.LEFT_BRACE, "Expected '{' before $kind body.");
    final List<Statement> body = parseBlock();
    return FuncDecl(name, parameters, body, inferredType);
  }

  Statement parseVarDecl() {
    Token name = consume(TokenType.IDENTIFIER, "Expected an identifier");

    Expression initialiser = Value(const MoccNull());

    final TypeAnnotation? typeAnnot = parseFullTypeAnnotation();
    final InferredType inferredType = typeAnnot == null
        ? InferredType(name, moccType: MoccDyn)
        : InferredType(name, reference: typeAnnot);
    if (match([TokenType.EQUAL])) {
      initialiser = parseExpression();
    }

    consume(TokenType.SEMICOLON, "Expect ';' after variable declaration.");
    return InitialiserStmt(name, inferredType, initialiser);
  }

  Statement parseStatement() {
    if (match([TokenType.RETURN])) return parseReturnStmt();
    if (match([TokenType.FOR])) return parseForStmt();
    if (match([TokenType.IF])) return parseIfStmt();
    if (match([TokenType.WHILE])) return parseWhileStmt();
    if (match([TokenType.OK])) return parseOkStmt();
    if (match([TokenType.LEFT_BRACE])) return BlockStmt(parseBlock());
    return parseExpressionStmt();
  }

  TypeAnnotation? parseFullTypeAnnotation() {
    final TypeAnnotation? returnable;
    if (match([TokenType.ANGLED_LEFT])) {
      returnable = parseTypeAnnotation();
      consume(
          TokenType.ANGLED_RIGHT, "Closing '>' expected after type annotation");
    } else {
      returnable = null;
    }
    return returnable;
  }

  TypeAnnotation parseTypeAnnotation() {
    // var x<map<K, V, T>, fn<void>, stream<f>> = ...
    final Token name = consume(TokenType.IDENTIFIER, "Type name expected");
    final List<TypeAnnotation> typeArgs = [];
    if (match([TokenType.ANGLED_LEFT])) {
      do {
        typeArgs.add(parseTypeAnnotation());
      } while (match([TokenType.COMMA]));
      consume(
          TokenType.ANGLED_RIGHT, "Closing '>' expected after type annotation");
    }
    return TypeAnnotation(name, typeArgs);
  }

  List<Statement> parseBlock() {
    final List<Statement> statements = [];

    while (!check(TokenType.RIGHT_BRACE) && !atEnd) {
      final Statement? stmt = parseDeclaration();
      if (stmt != null) statements.add(stmt);
    }

    consume(TokenType.RIGHT_BRACE, "Expected '}' after block.");
    return statements;
  }

  Statement parseReturnStmt() {
    Token keyword = previous();
    final Expression? value;
    if (!check(TokenType.SEMICOLON)) {
      value = parseExpression();
    } else {
      value = null;
    }

    consume(TokenType.SEMICOLON, "Expected ';' after return statement.");
    return ReturnStmt(keyword, value);
  }

  Statement parseForStmt() {
    consume(TokenType.LEFT_PAREN, "Expected '(' after 'for'.");
    final Statement? initializer;
    if (match([TokenType.SEMICOLON])) {
      initializer = null;
    } else if (match([TokenType.VAR])) {
      initializer = parseVarDecl();
    } else {
      initializer = parseExpressionStmt();
    }
    Expression? condition;
    if (!check(TokenType.SEMICOLON)) {
      condition = parseExpression();
    }
    consume(TokenType.SEMICOLON, "Expected ';' after loop condition.");

    Expression? increment;
    if (!check(TokenType.RIGHT_PAREN)) {
      increment = parseExpression();
    }
    consume(TokenType.RIGHT_PAREN, "Expected ')' after clauses.");
    Statement body = parseStatement();
    if (increment != null) {
      body = BlockStmt(([body, ExpressionStmt(increment)]));
    }
    condition ??= Value(const MoccBool(true));
    body = WhileStmt(condition, body);
    if (initializer != null) {
      body = BlockStmt([initializer, body]);
    }
    return body;
  }

  Statement parseWhileStmt() {
    consume(TokenType.LEFT_PAREN, "Expect '(' after 'while'.");
    final Expression condition = parseExpression();
    consume(TokenType.RIGHT_PAREN, "Expected ')' after condition.");
    final Statement body = parseStatement();

    return WhileStmt(condition, body);
  }

  Statement parseIfStmt() {
    consume(TokenType.LEFT_PAREN, "Expected '(' after 'if'.");
    final Expression condition = parseExpression();
    consume(TokenType.RIGHT_PAREN, "Expected ')' after if condition.");

    final Statement thenBranch = parseStatement();
    final Statement? elseBranch;
    if (match([TokenType.ELSE])) {
      elseBranch = parseStatement();
    } else {
      elseBranch = null;
    }

    return IfStmt(condition, thenBranch, elseBranch);
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

  Expression parseExpression() => parseAssignment();
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
    return parseInvCall();
  }

  Expression parseInvCall() {
    Expression expr = parseValue();
    while (true) {
      if (match([TokenType.LEFT_PAREN])) {
        expr = parseArgs(expr);
      } else if (match([TokenType.DOT])) {
        Token name =
            consume(TokenType.IDENTIFIER, "Expected property name after '.'");
        expr = GetExpression(expr, name);
      } else {
        break;
      }
    }
    return expr;
  }

  Expression parseArgs(Expression callee) {
    final List<Expression> arguments = [];
    if (!check(TokenType.RIGHT_PAREN)) {
      do {
        arguments.add(parseExpression());
      } while (match([TokenType.COMMA]));
    }

    Token paren = consume(
        TokenType.RIGHT_PAREN, "Expected ')' after arguments in invocation.");

    if (arguments.length > 200) {
      ErrorHandler.issues.add(
        ArgumentError(
          ArgumentError.tooManyArguments(arguments.length),
          lineNo: peek().lineNo,
          start: peek().start,
          offendingLine: sourceLines[peek().lineNo],
          description: "Try limiting the number of arguments to under 200.",
          source: Source.parser,
        ),
      );
    }
    return InvocationExpression(callee, paren, arguments);
  }

  Expression parseValue() {
    if (match([TokenType.FALSE])) return Value(const MoccBool(false));
    if (match([TokenType.TRUE])) return Value(const MoccBool(true));

    if (match([TokenType.NULL])) return Value(const MoccNull());

    if (match([TokenType.NUMBER, TokenType.STRING])) {
      final Object? literal = previous().literal;
      if (literal is num) {
        return Value(MoccDbl(double.parse(literal.toString())));
      } else if (literal is String) {
        return Value(MoccStr(literal.toString()));
      }
    }

    if (match([TokenType.SUPER])) {
      final Token keyword = previous();
      consume(TokenType.DOT, "Expected '.' after 'super'.");
      final Token method =
          consume(TokenType.IDENTIFIER, "Expected method name.");
      return SuperReference(keyword, method);
    }

    if (match([TokenType.THIS])) return ThisReference(previous());

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

  Expression parseAssignment() {
    Expression expr = parseEquality();

    if (match([TokenType.EQUAL])) {
      Token equals = previous();
      Expression value = parseAssignment();

      if (expr is VariableReference) {
        Token name = expr.name;
        return VariableAssignment(name, value);
      } else if (expr is GetExpression) {
        return SetExpression(expr.object, expr.name, value);
      }

      ErrorHandler.issues.add(
        ReferenceError(
          ReferenceError.invalidAssignmentTarget(equals.lexeme),
          lineNo: equals.lineNo,
          start: equals.start,
          offendingLine: sourceLines[equals.lineNo],
          description:
              "Try declaring a variable named '${equals.lexeme}' in the current scope",
          source: Source.parser,
        ),
      );
    }

    return expr;
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
      SyntaxError.unexpectedChar(peek().lexeme),
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

class IfStmt extends Statement {
  final Expression condition;
  final Statement thenBranch;
  final Statement? elseBranch;

  IfStmt(this.condition, this.thenBranch, this.elseBranch);

  @override
  String toTree(int indent) => "${this.runtimeType}".indent(indent)
    ..newline("CONDITION: ${condition.toTree(indent + 2)}".indent(indent + 2))
    ..newline("THEN: ${thenBranch.toTree(indent + 2)}".indent(indent + 2))
    ..newline("ELSE: ${elseBranch?.toTree(indent + 2)}".indent(indent + 2));
}

class WhileStmt extends Statement {
  final Expression condition;
  final Statement body;

  WhileStmt(this.condition, this.body);

  @override
  String toTree(int indent) => "${this.runtimeType}".indent(indent)
    ..newline("WHILE: ${condition.toTree(indent + 2)}".indent(indent + 2))
    ..newline("DO: ${body.toTree(indent + 2)}".indent(indent + 2));
}

class ReturnStmt extends Statement {
  final Token keyword;
  final Expression? value;

  ReturnStmt(this.keyword, this.value);

  @override
  String toTree(int indent) => "${this.runtimeType}: ${value?.toTree(indent)}";
}

class BlockStmt extends Statement {
  final List<Statement> statements;

  BlockStmt(this.statements);

  @override
  String toTree(int indent) => "${this.runtimeType}".indent(indent)
    ..newline(
      statements
          .map((Statement s) => s.toTree(indent).indent(indent + 2))
          .toList()
          .join('\n'),
    );
}

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
  final InferredType inferredType;
  final Expression? initialiser;

  InitialiserStmt(this.name, this.inferredType, this.initialiser);

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
              : Value(const MoccNull()).toTree(indent + 4),
        );
  }
}

class StructDecl extends Statement {
  final Token name;
  final VariableReference? superstruct;
  final List<FuncDecl> methods;

  StructDecl(this.name, this.methods, this.superstruct);

  @override
  String toTree(int indent) => "${runtimeType.toString()} ${name.lexeme}"
      .newline("extends: ${superstruct?.name ?? 'NONE'}".indent(indent + 2));
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

class FuncDecl extends Statement {
  late Token name;
  late List<Token> params;
  late Parameters parameters;
  late List<Statement> body;
  final InferredType returnType;

  FuncDecl(this.name, this.params, this.body, this.returnType) {
    parameters = Parameters(
      positionalArgs: params.map((e) => {e.lexeme: MoccDyn}).toList(),
      namedArgs: const {},
    );
  }

  FuncDecl.portedFn(String name, this.parameters, this.returnType) {
    this.name = Token(TokenType.IDENTIFIER, name, lineNo: 0, start: 0);
    params = [];
    body = [];
  }

  @override
  String toTree(int indent) {
    return "${this.runtimeType}: ${name.lexeme}".indent(indent).newline(
          "PARAMS:".indent(indent + 2).newline(
                params
                    .map((Token t) => t.lexeme.indent(indent + 4))
                    .toList()
                    .join('\n'),
              ),
        );
  }
}

abstract class Expression implements Node {}

class VariableAssignment extends Expression {
  final Token name;
  final Expression value;

  VariableAssignment(this.name, this.value);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}".indent(indent)
      ..newline("NAME: ${name.lexeme}").indent(indent + 2)
      ..newline("VALUE: ${value.toTree(indent + 2)}").indent(indent + 2);
  }
}

class InvocationExpression implements Expression {
  final Expression callee;
  final Token paren;
  final List<Expression> arguments;

  InvocationExpression(this.callee, this.paren, this.arguments);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}"
        .indent(indent)
        .newline(callee.toTree(indent + 2))
        .newline(
            arguments.map((e) => e.toTree(indent + 2)).toList().join('\n'));
  }
}

class VariableReference implements Expression {
  final Token name;

  VariableReference(this.name);

  @override
  String toTree(int indent) => "MoccObject: ${name.lexeme}".indent(indent);
}

class GetExpression implements Expression {
  final Token name;
  final Expression object;

  GetExpression(this.object, this.name);

  @override
  String toTree(int indent) => "GET ${name.lexeme}"
      .newline("OF".indent(indent + 2))
      .indent(indent + 4)
      .newline(object.toTree(indent + 6));
}

class ThisReference implements Expression {
  final Token keyword;
  ThisReference(this.keyword);

  @override
  String toTree(int indent) => runtimeType.toString().indent(indent);
}

class SetExpression implements Expression {
  final Expression object;
  final Token name;
  final Expression value;

  SetExpression(this.object, this.name, this.value);

  @override
  String toTree(int indent) => "SET ${name.lexeme}"
      .indent(indent)
      .newline("OF: ${object.toTree(indent + 4)}")
      .indent(indent + 2)
      .newline("TO: ${value.toTree(indent + 4)}")
      .indent(indent + 2);
}

class SuperReference implements Expression {
  final Token keyword;
  final Token method;
  SuperReference(this.keyword, this.method);

  @override
  String toTree(int indent) => "$runtimeType"
      .indent(indent)
      .newline("METHOD: ${method.lexeme}".indent(indent + 2));
}

abstract class BinaryExp implements Expression {
  final Expression leftOperand;
  final Operator op;
  final Expression rightOperand;

  BinaryExp(this.leftOperand, this.op, this.rightOperand);
}

abstract class Operator implements Node {}

abstract class Keyword implements Node {
  final Token keyword;

  Keyword(this.keyword);

  @override
  String toTree(int indent) => "KW: ${keyword.lexeme}".indent(indent);
}

class ExtendKeyword extends Keyword {
  ExtendKeyword(super.keyword);
}

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
  final MoccObj value;

  Value(this.value);

  @override
  String toTree(int indent) {
    return "${this.runtimeType}: [${value.runtimeType}] ${value.toString()}"
        .indent(indent);
  }

  @override
  String toString() => value.toString();
}

class TypeAnnotation extends Expression {
  final Token name;
  final List<TypeAnnotation> typeArgs;

  TypeAnnotation(this.name, [this.typeArgs = const []]);

  @override
  String toString() {
    if (typeArgs.isEmpty) {
      return name.lexeme;
    } else {
      final String typeArgsStrings =
          typeArgs.map((e) => e.toString()).toList().join(', ');
      return "${name.lexeme}<$typeArgsStrings>";
    }
  }

  @override
  String toTree(int indent) {
    return "$runtimeType: ${name.lexeme}"
        .indent(indent)
        .newline("ARGS: ".indent(indent + 2))
        .newline(typeArgs.map((e) => e.toTree(indent + 4)).join('\n'));
  }
}

class InferredType extends Expression {
  final Token name;
  final TypeAnnotation? reference;
  final Type? moccType;

  InferredType(this.name, {this.reference, this.moccType});

  dynamic get value => reference ?? moccType;

  String get asTypeAnnot => moccType == null
      ? name.lexeme + reference.toString()
      : name.lexeme + moccType.runtimeType.asMoccType;

  @override
  String toTree(int indent) {
    return "InferredType of ${name.lexeme}:"
        .indent(indent)
        .newline(
            "annotation: ${reference?.toTree(indent + 2)}".indent(indent + 2))
        .newline("literal: $moccType".indent(indent + 2));
  }
}
