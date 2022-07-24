part of mochaccino.sdk.compiler;

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
