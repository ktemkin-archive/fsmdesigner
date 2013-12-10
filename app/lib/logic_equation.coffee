###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in "file.coffee", not "file.js".]

 QuickLogic Combinational Logic Designer
 Copyright (c) Binghamton University,
 author: Kyle J. Temkin <ktemkin@binghamton.edu>

 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:

 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
###

Parser = require 'lib/grammars/boolean'

#
# Generic class that handles basic operations on Logic Equations.
#
class exports.LogicEquation

  #
  # Defines each of the Boolean Algebra operations
  # supported.
  #
  @supported_operations:
    '|': (a, b) -> a | b
    '^': (a, b) -> a ^ b
    '&': (a, b) -> a & b
    '!': (a)    -> a

  #
  # Defines a set of transformations which convert 
  #
  @vhdl_operations:
    '|': (a, b) -> "(#{a} or #{b})"
    '^': (a, b) -> "(#{a} xor #{b})"
    '&': (a, b) -> "(#{a} and #{b})"
    '!': (a)    -> "not #{a}"


  #
  # Initializes a new LogicEquation object.
  #
  constructor: (@expression) ->

    #Parse the Logic Equation using PEG.js.
    [command, @output, @parse_tree] = Parser.parse(@expression)

    #Extract all of the input names from the given parse tree.
    @read_input_names_from(@parse_tree)


  #
  # Populates all of the LogicEquation's internal input names
  # from the given parse tree.
  #
  read_input_names_from: (parse_tree) =>

    #If we don't have an existing list of inputs, create one.
    @inputs ||= []

    #Recursive case: if we have an array...
    if parse_tree instanceof Array

      #... extract all of its input names. Note that we skip the first
      #element, as this element is the function being applied.
      @read_input_names_from(item) for item in parse_tree[1..]

    #Otherwise, this must be a base case, and we can add the input directly. 
    else
      #Add the input, unless it exists already.
      @inputs.push(parse_tree) unless parse_tree in @inputs

  #
  # Converts the logic equation into a VHDL assignment statement.
  #
  to_VHDL: =>
    "#{@output} <= #{@to_VHDL_expression(@parse_tree)};"


  #
  # Converts the given logic expression into a VHDL logic expression.
  # TODO: DRY up.
  #
  to_VHDL_expression: (expression = @parse_tree) =>

    #Recursive case: We've been passed an s-expression.
    if expression instanceof Array

      #Break the s-expression into the operator, and its arguments.
      [operator, args...] = expression

      #If possible, replace the operator with a VHDL conversion function.
      operator = @constructor.look_up_operator(operator, @constructor.vhdl_operations)

      #Evaluate each of the arguments.
      args = (@to_VHDL_expression(arg) for arg in args)

      #Perform the operation on each of its arguments,
      #and return the result
      return operator(args...)

    #Base case: if we can't evaluate the tree further, return it diretly.
    else
      return expression
    



  #
  # Evaluates the equation, and determines the value of its output
  # given a set of inputs. Evaluates a parse tree (s-expression).
  #
  evaluate: (inputs, parse_tree=@parse_tree) =>

    #Recursive case: We've been passed an s-expression.
    if parse_tree instanceof Array

      #Break the s-expression into the operator, and its arguments.
      [operator, args...] = parse_tree

      #If possible, replace the operator with a JavaScript definition.
      operator = @constructor.look_up_operator(operator)

      #Evaluate each of the arguments.
      args = (@evaluate(inputs, arg) for arg in args)

      #Perform the operation on each of its arguments,
      #and return the result
      return operator(args...)

    #Base case: if we have one of the inputs, replace it with its value.
    else if parse_tree of inputs
      return inputs[parse_tree]

    #Base case: if we can't evaluate the tree further, return it diretly.
    else
      return parse_tree


  #
  # Attempts to look up a given s-expression operator,
  # replacing it with a JavaScript equivalent.
  #
  @look_up_operator: (operator, source=@supported_operations) =>
    return source[operator] if operator of source
    return operator

  #
  # Generates a truth table for the given
  #
  truth_table: (inputs=@inputs) =>

    rows = []

    #Evaluate the function for every possible input condition.
    for input in @possible_input_combinations(inputs)
      rows.push([input, @evaluate(input)])

    #Return an object containing the truth table's inputs,
    #the current function's output, and each of the relevant rows.
    table =
      inputs: inputs
      output: @output
      rows: rows


  #
  # Generates an array of all possible input combinations,
  # in binary order.
  #
  possible_input_combinations: (inputs=@inputs) =>
    
    combinations = []

    #Determine the total amount of combinations to be created...
    possible_minterms = Math.pow(2, inputs.length)

    #...and create a single input combination for each possible minterm.
    for i in [0...possible_minterms]
      combinations.push(@_generate_minterm_input(i, inputs))

    combinations


  #
  # Generates the input set which would make
  # a given minterm True.
  #
  # For example, _generate_minterm_input(['a', 'b'], 3)
  # would return {a: true, b: true}.
  #
  _generate_minterm_input: (number, inputs=@inputs) ->

    result = {}
  
    #Convert the given number to binary...
    binary_number = @_zero_pad_minterm(number.toString(2), inputs.length)

    #Populate the input for each bit of the binary number.
    for input, index in inputs
      result[input] = if (binary_number.charAt(index) == '1') then '1' else '0'

    result


  #
  # Zero pads the given minterm to the requisite length
  #
  _zero_pad_minterm: (number, width) ->
    return number if number.length >= width
    return (new Array(width - number.length + 1)).join('0') + number


      



  


