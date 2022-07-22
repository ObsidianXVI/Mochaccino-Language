# Caramel EBNF Definition
Since we couldn't find any established standards of BNF syntax online, we decided to create our own. This file clarifies the syntax of Caramel — our very own flavour of EBNF which will be used to define grammar rules for Mochaccino.

## Production Rule
Symbol: `x = y ;`

Example:
```js
term = "A";
term2 = "A"
        "B"
        "C"
        ;
```

## Concatenation
Juxtaposition implicitly denotes concatenation.

## Grouping
Symbol: `(term1 term2)`

Example:
```js
term =  ("A" "B") | "C"; // A followed by B, or just C
```

## Option
Symbol: `|` or `[...]`

Example:
```js
term =  "A" | "B";       // A or B
term2 = ("A" | "B") "C"; // A or B, followed by C
term3 = term [term2];    // term, optionally followed by term2, which can be present 0 or 1 times
```

## Repetition
Symbol: `term*` or `term+` or `term{6}`

Example:
```js
term =  "A"*;         // A, repeated zero or more times
term2 = "B"+ ;        // B, repeated at least once
term3 = ("A" "B"){6}; // A followed by B, and the set is repeated exactly 6 times
```

## RegEx
Symbol: `term :: rule;`

When a rule is defined as a RegEx, it cannot reference non-terminals, and characters used will be interpreted as RegEx syntax rather than Caramel EBNF. The RegEx flavour used is ECMAScript.

Example:
```js
number :: [0-9];
```

## Terminals
These are the default terminals that can be included in the grammar definition:

- `NUMBER`: whole numbers of any number of digits, decimals are strictly not included 
    - `NUMBER = (1|2|3|4|5|6|7|8|9|0)*;`
- `STRING`: a line of unrestricted text enclosed in double or single quotes, whitespace allowed
    - `STRING = ('"' char* '"') | ("'" char* "'")`
    - `char` is known to be any character, uppercase or lowercase, number, symbol, or whitespace
- `TYPE`: a type literal which follows the same rules as `TEXT`
    - `TYPE = TEXT;`
- `TEXT`: an identifier-safe text which can include numbers (though not as the first character) and underscores, but not whitespaces
    - `TEXT = ["_"] {a-zA-Z} (NUMBER | [a-zA-z])*;`