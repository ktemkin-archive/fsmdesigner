###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in ".coffee" files, not "js" files.]

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

{CanvasRenderer} = require 'lib/renderers/canvas_renderer'

#
# Low-level representation of an arrow's path.
# Used for rendering of state transitions.
#
class exports.StraightPath

  #
  # Creates a new straight path, used to indicate the visible "path" of a transition.
  #
  constructor: (@start, @end) ->
  
  #
  # Return the position at which the given path starts.
  #
  get_position: ->
    @start

  #TODO: get_metrics

  #
  # Returns true iff the given point is within the specified tolerance of the path.
  #
  contains_point: (x, y, tolerance = 20) ->

    #determine the center-point, between the two circles-
    #our line must intersect this point
    dx = @end.x - @start.x
    dy = @end.y - @start.y

    #figure out the point's offset from the starting point
    offset_x = x - @start.x
    offset_y = y - @start.y

    #and figure out the length of the line
    length = Math.sqrt(dx*dx + dy*dy)

    #compute the offset difference from the line
    percent = (dx * offset_x + dy * offset_y) / (length * length)
    distance = (dx * offset_y - dy * offset_x) / length

    #and determine if the actual click was more than a tolerance away from the real line
    return percent > 0 and percent < 1 and Math.abs(distance) < tolerance


  #
  # Renders the given transition as a straight line across
  # the provided path.
  #
  draw: (renderer, text = null, font = null, is_selected = false) ->
  #
  # Returns true iff the given point is within the specified tolerance of the path.
  #
  contains_point: (x, y, tolerance = 20) ->

    #determine the center-point, between the two circles-
    #our line must intersect this point
    dx = @end.x - @start.x
    dy = @end.y - @start.y

    #figure out the point's offset from the starting point
    offset_x = x - @start.x
    offset_y = y - @start.y

    #and figure out the length of the line
    length = Math.sqrt(dx*dx + dy*dy)

    #compute the offset difference from the line
    percent = (dx * offset_x + dy * offset_y) / (length * length)
    distance = (dx * offset_y - dy * offset_x) / length

    #and determine if the actual click was more than a tolerance away from the real line
    return percent > 0 and percent < 1 and Math.abs(distance) < tolerance


  #
  # Renders the given transition as a straight line across
  # the provided path.
  #
  draw: (renderer, text = null, font = null, is_selected = false) ->

    #draw the basic straight line
    renderer.context.beginPath()
    renderer.context.moveTo(@start.x, @start.y)
    renderer.context.lineTo(@end.x, @end.y)
    renderer.context.stroke()

    #draw the head of the arrow on the end of the line
    renderer.draw_arrowhead(@end.x, @end.y, @get_arrow_angle()) 

    #If no text was provided, return.
    return unless text? or is_selected

    #compute the position of the arrow's transition condition
    text_location =
      x: (@start.x + @end.x) / 2
      y: (@start.y + @end.y) / 2
      angle: Math.atan2(@end.x - @start.x, @start.y - @end.y)

    #and render the text
    renderer.draw_text(text, text_location.x, text_location.y, is_selected, font, text_location.angle)

  #
  # Compute the angle for the arrowhead at the end of this path.
  #
  get_arrow_angle: ->
    arrow_angle = Math.atan2(@end.y - @start.y, @end.x - @start.x)


