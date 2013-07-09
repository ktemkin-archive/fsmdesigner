###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in "transition_placeholder.coffee", not "transition_placeholder.js".]

 Finite State Machine Designer
 portions Copyright (c) Binghamton University,
 author: Kyle J. Temkin <ktemkin@binghamton.edu>

 Based on:
 Finite State Machine Designer (http://madebyevan.com/fsm/)
 portions Copyright (c) 2010 Evan Wallace

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

{StraightPath} = require 'lib/paths/straight_path'

class exports.TransitionPlaceholder

  constructor: (@start, @end) ->
    @color = 'black'

  #
  # A transition placeholder is always composed of a straight path from the start to the end.
  #
  get_path: ->
    new StraightPath(@start, @end)

  #
  # Renders the transition placeholder.
  # 
  draw: (renderer) ->

    #apply the FG color
    renderer.context.fillStyle = renderer.context.strokeStyle = @color

    #and draw along the placeholder's path
    @get_path().draw(renderer)
