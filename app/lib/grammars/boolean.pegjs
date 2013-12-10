/**
 * Boolean Algebra Parser for PEG.js.
 * Converts Boolean algebra into machine-parsable LISP-like S-expressions.
 */

// An expression.
equation
  = output:variable "=" expression:expression ";"? { return ['define', output, expression]}

// An alias for our 
expression "expression"
  = or_term

// A sum terms, which contains only OR operations and simpler terms.
or_term "sum term"
  = left:xor_term "+" right:or_term { return ['|', left, right]; }
  / xor_term

// An XOR-term, which is composed of only XORs and simpler terms.
xor_term "XOR term"
  = left:and_term "^" right:xor_term { return ['^', left, right] }
  / and_term

// A product term, which contains only the ANDs of simpler terms.
// Note that this also supports _implied_ AND operations.
and_term "product term"
  = left:subexpression "*"? right:and_term { return ['&', left, right] }
  / subexpression

// An potentially-inverted term, such as a literal or inverted subexpression.
subexpression "subexpression"
  = term:term "'" whitespace { return ['!', term] }
  / term

// A primary term, such as expression or inverted subexpression.
term "term"
  = variable 
  / whitespace "(" expression:expression ")" whitespace { return expression; }

//Our basic variables.
variable "variable"
  = whitespace characters:[A-Za-z0-9\[\]_]+ whitespace { return characters.join(""); }

//A collection of whitespace characters, which shouldn't matter to our expressions.
whitespace "whitespace character(s)"
  = [ ]*

