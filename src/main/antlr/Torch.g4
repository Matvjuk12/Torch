/*
 * Torch Programming Language v0.1 Grammar
 * =======================================
 * LL(*) parser grammar for Torch compiler frontend.
 * 
 * Design goals:
 * - Statically typed with full type inference (Hindley-Milner style)
 * - Built-in tensor types with static shapes for polyhedral analysis
 * - Broadcasting operators with correct precedence
 * - Zero-cost abstractions for MLIR/LLVM lowering
 * - Extensible module/trait system
 * 
 * Author: Matvey Zhukovsky
 */

grammar Torch;

/*
 * PROGRAM STRUCTURE
 * -----------------
 * Files contain modules, global functions, constants, type declarations.
 * Supports shebangs for scripting use.
 */
prog: (shebang)? (moduleDecl | globalItem)* EOF;

shebang: HASHBANG ~[\r\n]* NEWLINE;

// Modular system with imports and visibility control
moduleDecl: MODULE IDENTIFIER moduleBlock;
moduleBlock: LBRACE moduleItem* RBRACE;

moduleItem
    : importDecl
    | useDecl
    | globalFnDecl
    | globalVarDecl
    | globalConstDecl
    | typeDecl
    | traitDecl
    | implBlock
    ;

globalItem
    : globalFnDecl
    | globalVarDecl
    | globalConstDecl
    | typeDecl
    ;

// IMPORTS AND VISIBILITY
// ---------------------
importDecl: IMPORT importPath (AS IDENTIFIER)? SEMI;
useDecl: USE importPath (AS IDENTIFIER)? SEMI;
importPath: IDENTIFIER (DOT IDENTIFIER)*;

// Visibility modifiers for library compatibility
visibility: PUB | PUB LPAREN restrictedVisibility RPAREN;
restrictedVisibility: CRATE | SELF | SUPER | STR_LITERAL;

// FUNCTIONS
// ---------
globalFnDecl: attrs* visibility? FN IDENTIFIER fnSignature fnBody;
fnSignature: generics? LPAREN formalParams? RPAREN fnReturnType whereClause?;
fnBody: block | externBlock;

formalParams: formalParam (COMMA formalParam)*;
formalParam: IDENTIFIER paramAttrs? paramType?;
paramAttrs: MUT | REF;
paramType: COLON typeExpr;

fnReturnType: COLON typeExpr | /* implicit inference */;
whereClause: WHERE whereClauseItem (COMMA whereClauseItem)*;
whereClauseItem: IDENTIFIER COLON typeExpr | typeExpr COLON typeExpr;

// TYPES
// -----
typeExpr
    : primitiveType
    | tensorType
    | arrayType
    | sliceType
    | tupleType
    | referenceType
    | pointerType
    | functionType
    | structType
    | enumType
    | neverType
    | unitType
    | IDENTIFIER generics?
    ;

primitiveType: I8 | I16 | I32 | I64 | F32 | F64 | BOOL | CHAR | STR | UNIT;
tensorType: TENSOR LT typeExpr COMMA shape GT;
arrayType: LBRACK typeExpr SEMI INT_LITERAL? RBRACK;
sliceType: LBRACK typeExpr RBRACK;
tupleType: LPAREN tupleFieldTypes RPAREN;
tupleFieldTypes: typeExpr (COMMA typeExpr)* COMMA?;

referenceType: REF typeExpr;
pointerType: STAR typeExpr;
functionType: LPAREN formalParams? RPAREN ARROW typeExpr;
structType: IDENTIFIER generics?;
enumType: ENUM IDENTIFIER generics?;
neverType: NEVER;
unitType: UNIT | LPAREN RPAREN;

// Shapes enable static polyhedral analysis
shape: LBRACK shapeDim (COMMA shapeDim)* RBRACK;
shapeDim: INT_LITERAL | IDENTIFIER | STAR; // STAR = dynamic dim

// STRUCTS, ENUMS, TRAITS
// ----------------------
typeDecl: structDecl | enumDecl | typeAlias;
structDecl: STRUCT IDENTIFIER generics? typeParams? LBRACE structFields* RBRACE;
enumDecl: ENUM IDENTIFIER generics? LBRACE enumVariants* RBRACE;
typeAlias: TYPE IDENTIFIER generics? ASSIGN typeExpr SEMI;

structFields: structField (SEMI? structField)*;
structField: visibility? IDENTIFIER COLON typeExpr fieldInit?;
fieldInit: ASSIGN expr;

enumVariants: enumVariant (COMMA enumVariant)*;
enumVariant: IDENTIFIER tuplePattern? | IDENTIFIER LPAREN tupleFieldTypes? RPAREN;

traitDecl: TRAIT IDENTIFIER generics? LBRACE traitMembers* RBRACE;
traitMembers: traitMethod | traitTypeAlias | traitConst;
traitMethod: visibility? FN IDENTIFIER fnSignature SEMI;
traitTypeAlias: TYPE IDENTIFIER SEMI;
traitConst: CONST IDENTIFIER COLON typeExpr ASSIGN expr? SEMI;

implBlock: IMPL generics? FOR typeExpr LBRACE implItems* RBRACE;
implItems: implItem (SEMI? implItem)*;
implItem: fnDecl | constDecl | typeAlias;

// STATEMENTS
// ----------
stmt
    : letStmt
    | itemStmt
    | exprStmt
    | controlFlowStmt
    | blockStmt
    ;

letStmt: LET IDENTIFIER bindingPattern COLON typeExpr? ASSIGN expr? SEMI;
bindingPattern: IDENTIFIER | bindingPattern COMMA bindingPattern | UNDERSCORE;

itemStmt: fnDecl | structDecl | constDecl | typeAlias;
exprStmt: expr SEMI;

controlFlowStmt
    : ifExpr
    | loopExpr
    | forExpr
    | whileExpr
    | matchExpr
    | returnStmt
    | breakStmt
    | continueStmt
    | assertStmt
    ;

blockStmt: block;

// EXPRESSIONS
// -----------
expr
    // Highest precedence: indexing, method calls, field access
    : expr LBRACK indexArgs RBRACK                   # indexingExpr
    | expr DOT IDENTIFIER generics? LPAREN args? RPAREN  # methodCallExpr
    | expr DOT IDENTIFIER                           # fieldAccessExpr
    
    // Function calls
    | IDENTIFIER generics? LPAREN args? RPAREN      # functionCallExpr
    | closureExpr                                   # closureExpr
    
    // Binary operators (left associative, descending precedence)
    | lhs=expr op=broadcastOp rhs=expr              # broadcastExpr
    | lhs=expr op=mulDivModOp rhs=expr              # mulDivModExpr
    | lhs=expr op=addSubOp rhs=expr                 # addSubExpr
    | lhs=expr op=shiftOp rhs=expr                  # shiftExpr
    | lhs=expr op=bitwiseOp rhs=expr                # bitwiseExpr
    | lhs=expr op=comparisonOp rhs=expr             # comparisonExpr
    | lhs=expr op=equalityOp rhs=expr               # equalityExpr
    | lhs=expr AND rhs=expr                         # logicalAndExpr
    | lhs=expr OR rhs=expr                          # logicalOrExpr
    
    // Unary operators
    | unaryPrefixOp expr                            # unaryPrefixExpr
    | expr unaryPostfixOp                           # unaryPostfixExpr
    
    // Ranges and literals
    | expr RANGE expr                               # rangeExpr
    | IDENTIFIER                                    # identifierExpr
    | tensorLiteral                                 # tensorLiteralExpr
    | arrayLiteral                                  # arrayLiteralExpr
    | tupleLiteral                                  # tupleLiteralExpr
    | primitiveLiteral                              # primitiveLiteralExpr
    | LPAREN expr RPAREN                            # parenthesizedExpr
    | block                                         # blockExpr
    ;

indexArgs: expr (COMMA expr)*;
args: expr (COMMA expr)*;

// LITERALS
// --------
tensorLiteral: TENSOR LT typeExpr COMMA shape GT tensorData;
tensorData: LPAREN tensorRows? RPAREN;
tensorRows: tensorRow (COMMA tensorRow)*;
tensorRow: LPAREN expr (COMMA expr)* RPAREN;

arrayLiteral: LBRACK (expr (COMMA expr)* COMMA?)? RBRACK;
tupleLiteral: LPAREN (expr (COMMA expr)+ COMMA?)? RPAREN;

// Memory allocation helpers (lowered to memref.alloc)
allocExpr: allocZeros | allocOnes | allocRand;
allocZeros: ZEROS LT typeExpr COMMA shape GT;
allocOnes: ONES LT typeExpr COMMA shape GT;
allocRand: RAND LT typeExpr COMMA shape GT;

primitiveLiteral: INT_LITERAL | FLOAT_LITERAL | BOOL_LITERAL | CHAR_LITERAL | STR_LITERAL | NULL_LITERAL;

closureExpr: PIPE formalParams? PIPE ARROW expr;

// CONTROL FLOW
// ------------
ifExpr: IF expr block (ELSE ifTail)?; 
ifTail: ifExpr | block;

matchExpr: MATCH expr LBRACE matchArm+ RBRACE;
matchArm: patternList FAT_ARROW expr COMMA?;

forExpr: FOR IDENTIFIER IN expr block;
whileExpr: WHILE expr block;
loopExpr: LOOP block;

returnStmt: RETURN expr? SEMI;
breakStmt: BREAK IDENTIFIER? SEMI;
continueStmt: CONTINUE IDENTIFIER? SEMI;
assertStmt: ASSERT expr COMMA STR_LITERAL SEMI;

// PATTERNS
// --------
patternList: pattern (BAR pattern)*;
pattern
    : bindingPattern
    | literalPattern
    | tuplePattern
    | slicePattern
    | wildcardPattern
    ;

tuplePattern: LPAREN patternList? RPAREN;
slicePattern: IDENTIFIER LBRACK RANGE RBRACK;
wildcardPattern: UNDERSCORE;

// BLOCKS
// ------
block: LBRACE stmt* RBRACE;

// ATTRIBUTES AND MACROS
// ---------------------
attrs: attribute*;
attribute: POUND LBRACK IDENTIFIER (ASSIGN literal)? (COMMA attributeItem)* RBRACK;
attributeItem: IDENTIFIER | literal;

// EXTERNS
// -------
externBlock: EXTERN LBRACE externFn* RBRACE;
externFn: FN IDENTIFIER fnSignature SEMI;

// OPERATORS
// ---------
broadcastOp: MUL_DOT | ADD_DOT | SUB_DOT | DIV_DOT;
mulDivModOp: STAR | SLASH | PERCENT;
addSubOp: PLUS | MINUS;
shiftOp: SHL | SHR;
bitwiseOp: BIT_AND | BIT_OR | BIT_XOR;
comparisonOp: LT | LE | GT | GE;
equalityOp: EQ | NEQ;
unaryPrefixOp: MINUS | BANG | TILDE | STAR | REF;
unaryPostfixOp: DOT QUESTION; // .? for optional chaining

// LEXER RULES
// -----------
/* Keywords */
IF: 'if';
ELSE: 'else';
MATCH: 'match';
FOR: 'for';
WHILE: 'while';
LOOP: 'loop';
IN: 'in';
RETURN: 'return';
BREAK: 'break';
CONTINUE: 'continue';
LET: 'let';
MUT: 'mut';
REF: 'ref';
FN: 'fn';
STRUCT: 'struct';
ENUM: 'enum';
TRAIT: 'trait';
IMPL: 'impl';
TYPE: 'type';
MODULE: 'module';
IMPORT: 'import';
USE: 'use';
AS: 'as';
PUB: 'pub';
CONST: 'const';
WHERE: 'where';
ASSERT: 'assert';
EXTERN: 'extern';
CRATE: 'crate';
SUPER: 'super';
SELF: 'self';
UNIT: '()';
NEVER: 'never';

TENSOR: 'tensor';
ZEROS: 'zeros';
ONES: 'ones';
RAND: 'rand';

/* Primitive types */
I8: 'i8';
I16: 'i16';
I32: 'i32';
I64: 'i64';
F32: 'f32';
F64: 'f64';
BOOL: 'bool';
CHAR: 'char';
STR: 'str';

/* Identifiers */
IDENTIFIER: [a-zA-Z_][a-zA-Z0-9_]*;

/* Literals */
INT_LITERAL: [0-9]+;
FLOAT_LITERAL: [0-9]* '.' [0-9]+ ([eE][+-]?[0-9]+)?;
BOOL_LITERAL: 'true' | 'false';
CHAR_LITERAL: '\'' (~['\\] | ESCAPE_SEQ) '\'';
STR_LITERAL: '"' (~["\\] | ESCAPE_SEQ)* '"';
NULL_LITERAL: 'null';

fragment ESCAPE_SEQ: '\\' ([btnfr"'\\] | [0-7][0-7]? | 'x'[0-9a-fA-F][0-9a-fA-F]);

/* Operators */
DOT: '.';
COMMA: ',';
SEMI: ';';
COLON: ':';
ASSIGN: '=';
ARROW: '->';
FAT_ARROW: '=>';
RANGE: '..';
PIPE: '|';
BAR: '|';
UNDERSCORE: '_';
STAR: '*';
SLASH: '/';
PERCENT: '%';
PLUS: '+';
MINUS: '-';
LT: '<';
LE: '<=';
GT: '>';
GE: '>=';
EQ: '==';
NEQ: '!=';
AND: '&&';
OR: '||';
BANG: '!';
TILDE: '~';
BIT_AND: '&';
BIT_OR: '|';
BIT_XOR: '^';
REF: '&';
POUND: '#';
QUESTION: '?';

MUL_DOT: '.*';
ADD_DOT: '.+';
SUB_DOT: '.-';
DIV_DOT: './';
SHL: '<<';
SHR: '>>';

/* Punctuation */
LPAREN: '(';
RPAREN: ')';
LBRACK: '[';
RBRACK: ']';
LBRACE: '{';
RBRACE: '}';
HASHBANG: '#!';

/* Comments */
LINE_COMMENT: '//' ~[\r\n]* -> skip;
BLOCK_COMMENT: '/*' .*? '*/' -> skip;
DOC_COMMENT: '///' ~[\r\n]* -> skip;
INNER_DOC: '!/' ~[\r\n]* -> skip;

/* Whitespace */
WS: [ \t\r\n\u000C]+ -> skip;
