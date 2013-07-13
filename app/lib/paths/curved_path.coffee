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

class exports.CurvedPath

  constructor: (@start, @end, @circle, @reversed) ->

  #
  # Creates a circle from three points,
  # returning its centerpoint and radius.
  #
  @circle_from_three_points: (d, e, f) ->

    d_hypotenuse_squared = d.x * d.x + d.y * d.y
    e_hypotenuse_squared = e.x * e.x + e.y * e.y
    f_hypotenuse_squared = f.x * f.x + f.y * f.y

    #Compute the three parameters of the quadratic formula...
    a = CurvedPath.determinant_3x3(d.x, d.y, 1, e.x, e.y, 1, f.x, f.y, 1)
    b =
      x: -1 * CurvedPath.determinant_3x3(d_hypotenuse_squared, d.y, 1, e_hypotenuse_squared, e.y, 1, f_hypotenuse_squared, f.y, 1)
      y: CurvedPath.determinant_3x3(d_hypotenuse_squared, d.x, 1, e_hypotenuse_squared, e.x, 1, f_hypotenuse_squared, f.x, 1)
    c= -1 * CurvedPath.determinant_3x3(d_hypotenuse_squared, d.x, d.y, e_hypotenuse_squared, e.x, e.y, f_hypotenuse_squared, f.x, f.y)

    #And use it compute the circle's location.
    circle =
      x: -1 * b.x / (2 * a)
      y: -1 * b.y / (2 * a)
      radius: Math.sqrt(b.x * b.x + b.y * b.y - 4*a*c) / (2 * Math.abs(a))

    circle


  #
  # Quick, ugly calculation of the determinant of a 3x3 matrix.
  # This version is computationally simpler than the general-case determinant.
  #
  #                                               |a, b, c|
  # determinant_3x3 (a, b, c, d, e, f, g, h, i) = |d, e, f|
  #                                               |g, h, i|
  #
  @determinant_3x3: (a, b, c, d, e, f, g, h, i) -> a*e*i + b*f*g + c*d*h - a*f*h - b*d*i - c*e*g

  #
  # Returns the starting point of the given arc.
  #
  get_position: ->
    @start

  #TODO: get_metrics
  
  #
  # Returns true iff the given point is within the specified tolerance of the path.
  #
  contains_point: (x, y, tolerance = 20) ->

    #Determine the distance from the curve upon which this path is drawn.
    dx = x - @circle.x
    dy = y - @circle.y
    distance = Math.abs(Math.sqrt(dx * dx + dy * dy) - @circle.radius)

    #If the distance is greater than our tolerance, the point can't be on our path.
    if distance > tolerance
        return false
   
    #othwise, check to see if th point follows the curveature of the circle
    else

      #determine the approximate angle from the center of the circle
      angle = Math.atan2(dy, dx)
     
      #if the line is reversed, switch the start and end angles
      if @reversed
        start_angle = @end.angle
        end_angle = @start.angle

      #otherwise, use them directly
      else
        start_angle = @start.angle
        end_angle = @end.angle

      #if the end angle is less than the start angle, normalize it by adding 360 degrees
      end_angle += Math.PI * 2 if end_angle < start_angle
        
      #if the angle is less than the start angle, normalize it by adding 360 degrees
      if angle < start_angle
        angle += Math.PI * 2

      #if the angle less than the end angle, normalize it by adding 360
      else if angle > end_angle
        angle -= Math.PI * 2

      return angle > start_angle and angle < end_angle

  #
  # Renders the given transition as a curved line across
  # the provided path.
  #
  draw: (renderer, text=null, font=null, is_selected=false) ->

    #draw the core arc that makes up the transition line
    renderer.context.beginPath()
    renderer.context.arc(@circle.x, @circle.y, @circle.radius, @start.angle, @end.angle, @reversed)
    renderer.context.stroke()

    #draw the head of the arrow
    renderer.draw_arrowhead(@end.x, @end.y, @get_arrow_angle())
  
    #draw the transition condition text
    return unless text? or is_selected
  
    #if the end-angle is less than the start angle, add 360 degrees 
    end_angle =
      if @end.angle < @start.angle
        @end.angle + Math.PI * 2
      else
        @end.angle

    #compute the angle at which the text should be rendered, relative to the line
    text_angle = (@start.angle + end_angle) / 2 + (@reversed * Math.PI)

    #and convert that into an x/y position for the center of the text
    text_location =
      x: @circle.x + @circle.radius * Math.cos(text_angle)
      y: @circle.y + @circle.radius * Math.sin(text_angle)
      angle: text_angle

    #finally, draw the text
    renderer.draw_text(text, text_location.x, text_location.y, is_selected, font, text_location.angle)

  #
  # Compute the angle for the arrowhead at the end of this path.
  #
  get_arrow_angle: ->
    scale = if @reversed then 1 else -1
    @end.angle - scale * (Math.PI / 2)

