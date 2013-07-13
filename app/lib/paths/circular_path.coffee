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
# Represents a generic circular path, such as the path which could be used to generate a self-loop.
#
class exports.CircularPath

  constructor: (@start, @end, @circle, @anchor_angle, @stroke_circumference) ->

  #
  # Returns true iff the given point is on the circular path.
  #
  contains_point: (x, y, tolerance = 20) ->

    #Find the total distance from the center of the loop to the x, y coordinates.
    dx = x - @circle.x
    dy = y - @circle.y
    distance = Math.abs(Math.sqrt(dx * dx + dy * dy))

    #if the distance is within our tolerance of the radius, it's on our path
    distance >= (@circle.radius - tolerance) and distance <= (@circle.radius + tolerance)

  #
  # Returns the position at which the given circle is locate.
  #
  get_position: ->
    return @start

  #
  # Renders the given transition as a circle across the provided path.
  #
  draw: (renderer, text=null, font=null, is_selected=false, show_caret=false) ->

    #Draw the core circle that makes up the transition line.
    renderer.context.beginPath()
    renderer.context.arc(@circle.x, @circle.y, @circle.radius, @start.angle, @end.angle, false)
    renderer.context.stroke()

    #Draw the head of the arrow.
    renderer.draw_arrowhead(@end.x, @end.y, @end.angle + Math.PI * @stroke_circumference / 2)

    #If we don't have text to render, abort
    return unless text? or is_selected

    #Find the furthest point from the state...
    text_location =
      x: @circle.x + @circle.radius * Math.cos(@anchor_angle)
      y: @circle.y + @circle.radius * Math.sin(@anchor_angle)

    #... and render the text, there.
    renderer.draw_text(text, text_location.x, text_location.y, is_selected, font, @anchor_angle)

