part of mochaccino.sdk.compiler;

enum TokenType {
  // SINGLE-CHARACTER TOKENS
  LEFT_PAREN,
  RIGHT_PAREN,
  LEFT_BRACK,
  RIGHT_BRACK,
  LEFT_BRACE,
  RIGHT_BRACE,
  COMMA,
  DOT,
  MINUS,
  PLUS,
  COLON,
  SEMICOLON,
  SLASH,
  STAR,

  // ONE- or TWO-CHARACTER TOKENS
  BANG,
  BANG_EQUAL,
  EQUAL,
  EQUAL_EQUAL,
  ANGLED_RIGHT,
  ANGLED_RIGHT_EQUAL,
  ANGLED_LEFT,
  ANGLED_LEFT_EQUAL,
  PIPE_PIPE,
  AMPERSAND_AMPERSAND,

  // LITERALS
  IDENTIFIER,
  STRING,
  NUMBER,
  FALSE,
  TRUE,
  NULL,

  // KEYWORDS
  OK,
  NOTOK,
  NAMED,
  PACKAGE,
  INCLUDE,
  PORT,
  FROM,
  AS,
  GUARDED,
  EXCEPT,
  VAR,
  RETURN,
  ASYNC,
  STATIC,
  MODULE,
  STRUCT,
  COLLECTION,
  FUNC,
  DOCK,
  EXTENDS,
  IMPLEMENTS,
  IF,
  ELIF,
  ELSE,
  FOR,
  WHILE,
  PROP,
  GET,
  SET,
  THIS,
  SUPER,

  // DEBUG FLAGS
  DEBUG_FLAG,
  STRUCT_ANNOTATION,

  // EOF
  EOF,
}

enum EqualitySymbol { isEqual, isNotEqual }

enum ArithmeticSymbol { plus, minus, star, divide }

enum ComparativeSymbol {
  lessThan,
  greaterThan,
  lessThanEqual,
  greaterThanEqual
}

enum LogicalSymbol { or, and }

enum UnaryPrefixSymbol { bang, minus }

enum UnaryPostfixSymbol { increment, decrement }

class Tokeniser {
  final CompileResult compileResult;
  final String source;
  Tokeniser(this.source, this.compileResult) {
    lines.addAll(source.split('\n'));
  }
  final List<String> lines = [];
  final List<Token> tokens = [];
  int start = 0;
  int current = 0;
  int lineNo = 0;

  List<Token> tokenise() {
    while (!atEnd) {
      start = current;
      scanToken();
    }
    tokens.add(
      Token(
        TokenType.EOF,
        '',
        lineNo: source.split('\n').length,
        start: 0,
      ),
    );

    // DEBUG: print out generated tokens
    if (Interface.debugMode) {
      for (Token tok in tokens) {
        compileResult.logs.add(
          ConsoleLog(
            LogType.info,
            tok.toString(),
            Source.tokeniser,
            debug: true,
          ),
        );
      }
    }
    return tokens;
  }

  void scanToken() {
    String c = advance();
    switch (c) {
      case '(':
        addToken(TokenType.LEFT_PAREN);
        break;
      case ')':
        addToken(TokenType.RIGHT_PAREN);
        break;
      case '{':
        addToken(TokenType.LEFT_BRACE);
        break;
      case '}':
        addToken(TokenType.RIGHT_BRACE);
        break;
      case ',':
        addToken(TokenType.COMMA);
        break;
      case '.':
        addToken(TokenType.DOT);
        break;
      case '-':
        addToken(TokenType.MINUS);
        break;
      case '+':
        addToken(TokenType.PLUS);
        break;
      case ':':
        addToken(TokenType.COLON);
        break;
      case ';':
        addToken(TokenType.SEMICOLON);
        break;
      case '*':
        addToken(TokenType.STAR);
        break;
      case '!':
        addToken(match('=') ? TokenType.BANG_EQUAL : TokenType.BANG);
        break;
      case '=':
        addToken(match('=') ? TokenType.EQUAL_EQUAL : TokenType.EQUAL);
        break;
      case '<':
        addToken(
            match('=') ? TokenType.ANGLED_LEFT_EQUAL : TokenType.ANGLED_LEFT);
        break;
      case '>':
        addToken(
            match('=') ? TokenType.ANGLED_RIGHT_EQUAL : TokenType.ANGLED_RIGHT);
        break;
      case '/':
        if (match('/')) {
          while (peek() != '\n' && !atEnd) {
            advance();
          }
        } else {
          addToken(TokenType.SLASH);
        }
        break;
      case '|':
        if (match('|')) {
          addToken(TokenType.PIPE_PIPE);
        } else {
          ErrorHandler.issues.add(
            SyntaxError(
              SyntaxError.unexpectedChar(c),
              lineNo: lineNo,
              start: current,
              offendingLine: lines[lineNo],
              description:
                  "Tokeniser could not produce a token for: $c. It may be an illegal character in the given context.",
              source: Source.tokeniser,
            ),
          );
        }
        break;
      case '&':
        if (match('&')) {
          addToken(TokenType.PIPE_PIPE);
        } else {
          ErrorHandler.issues.add(
            SyntaxError(
              SyntaxError.unexpectedChar(c),
              lineNo: lineNo,
              start: current,
              offendingLine: lines[lineNo],
              description:
                  "Tokeniser could not produce a token for: $c. It may be an illegal character in the given context.",
              source: Source.tokeniser,
            ),
          );
        }
        break;
      case ' ':
      case '\r':
      case '\t':
        // Ignore whitespace.
        break;
      case '\n':
        lineNo++;
        break;
      case '"':
      case "'":
        tokeniseString(c);
        break;
      default:
        if (c.isDigit) {
          tokeniseNumber();
        } else if (c.isAlpha) {
          tokeniseIdentifier();
        } else {
          ErrorHandler.issues.add(
            SyntaxError(
              SyntaxError.unexpectedChar(c),
              lineNo: lineNo,
              start: current,
              offendingLine: lines[lineNo],
              description:
                  "Tokeniser could not produce a token for: $c. It may be an illegal character in the given context.",
              source: Source.tokeniser,
            ),
          );
        }
        break;
    }
  }

  void addToken(TokenType tokenType, [Object? literal]) {
    tokens.add(
      Token(
        tokenType,
        source.substring(start, current),
        lineNo: lineNo,
        start: start,
        literal: literal,
      ),
    );
  }

  String advance() {
    return source.charAt(current++);
  }

  bool match(String expected) {
    if (atEnd) return false;
    if (source.charAt(current) != expected) return false;

    current++;
    return true;
  }

  String peek([int lookaheadCount = 0]) {
    if (current + lookaheadCount >= source.length) return 'EOF';
    return source.charAt(current + lookaheadCount);
  }

  void tokeniseString(String delimiter) {
    while (peek() != delimiter && !atEnd) {
      if (peek() == '\n') lineNo++;
      advance();
    }

    if (atEnd) {
      // unterminated string error
      ErrorHandler.issues.add(
        SyntaxError(
          SyntaxError.unterminatedPair(delimiter),
          lineNo: lineNo,
          start: start,
          offendingLine: lines[lineNo],
          description: 'Unterminated string literal.',
          source: Source.tokeniser,
        ),
      );
      return;
    }

    advance();

    String value = source.substring(start + 1, current - 1);
    addToken(TokenType.STRING, value);
  }

  void tokeniseNumber() {
    while (peek().isDigit) {
      advance();
    }

    if (peek() == '.' && peek(1).isDigit) {
      advance();
      while (peek().isDigit) {
        advance();
      }
    }

    addToken(
      TokenType.NUMBER,
      double.parse(
        source.substring(start, current),
      ),
    );
  }

  void tokeniseIdentifier() {
    while (peek().isAlphaNum) {
      advance();
    }
    String text = source.substring(start, current);
    addToken(keywords[text] ?? TokenType.IDENTIFIER);
  }

  bool get atEnd => !(current < source.length);
}

class Token {
  final TokenType tokenType;
  final String lexeme;
  final Object? literal;
  final int lineNo;
  final int start;

  Token(
    this.tokenType,
    this.lexeme, {
    required this.lineNo,
    required this.start,
    this.literal,
  });

  Token.magical(
    this.lexeme, [
    this.tokenType = TokenType.EOF,
    this.literal = '',
    this.lineNo = 0,
    this.start = 0,
  ]);

  @override
  String toString() =>
      "'$lexeme': $tokenType ${literal ?? ''} [$lineNo:$start]";

  dynamic toSymbol() {
    switch (lexeme) {
      case '+':
        return ArithmeticSymbol.plus;
      case '-':
        return [ArithmeticSymbol.minus, UnaryPrefixSymbol.minus];
      case '*':
        return ArithmeticSymbol.star;
      case '/':
        return ArithmeticSymbol.divide;
      case '==':
        return EqualitySymbol.isEqual;
      case '!=':
        return EqualitySymbol.isNotEqual;
      case '<':
        return ComparativeSymbol.lessThan;
      case '<=':
        return ComparativeSymbol.lessThanEqual;
      case '>':
        return ComparativeSymbol.greaterThan;
      case '>=':
        return ComparativeSymbol.greaterThanEqual;
      case '||':
        return LogicalSymbol.or;
      case '&&':
        return LogicalSymbol.and;
      case '!':
        return UnaryPrefixSymbol.bang;
      case '++':
        return UnaryPostfixSymbol.increment;
      case '--':
        return UnaryPostfixSymbol.decrement;
      default:
        throw Exception(lexeme);
    }
  }
}

final Map<String, TokenType> keywords = {
  'ok': TokenType.OK,
  'notok': TokenType.NOTOK,
  'named': TokenType.NAMED,
  'package': TokenType.PACKAGE,
  'include': TokenType.INCLUDE,
  'from': TokenType.FROM,
  'as': TokenType.AS,
  'guarded': TokenType.GUARDED,
  'except': TokenType.EXCEPT,
  'var': TokenType.VAR,
  'return': TokenType.RETURN,
  'async': TokenType.ASYNC,
  'static': TokenType.STATIC,
  'module:': TokenType.MODULE,
  'struct': TokenType.STRUCT,
  'collection': TokenType.COLLECTION,
  'port': TokenType.PORT,
  'func': TokenType.FUNC,
  'dock': TokenType.DOCK,
  'extends': TokenType.EXTENDS,
  'implements': TokenType.IMPLEMENTS,
  'if': TokenType.IF,
  'elif': TokenType.ELIF,
  'else': TokenType.ELSE,
  'for': TokenType.FOR,
  'while': TokenType.WHILE,
  'prop': TokenType.PROP,
  'get': TokenType.GET,
  'set': TokenType.SET,
  'true': TokenType.TRUE,
  'false': TokenType.FALSE,
  'null': TokenType.NULL,
};
