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

{FSMRenderer}      = require 'lib/renderers/fsm_renderer'
{CanvasTextEditor} = require 'lib/text_editors/canvas_text_editor'

#
# Renderer which creates HTML5 canvas representations of FSM diagrams.
# This is the primary UI for entering FSM diagrams.
#
class exports.CanvasRenderer extends FSMRenderer

  caret_height: 20
  caret_padding: 2

  text_background_padding: 2

  #
  # Initializes a new CanvasRenderer object.
  #
  constructor: (@canvas, @stroke_color='black', @fill_color='white') ->

    #Get the Canvas's 2D drawing context.
    @context = @canvas.getContext('2d')



  #
  # Clears the relevant canvas.
  #
  clear: ->
    #clear the entire canvas
    @context.clearRect(0, 0, @canvas.width, @canvas.height)

    #save the renderer.context's current settings
    @context.translate(0.5, 0.5)


  #
  # Fills the entire canvas with the given style.
  #
  fill: (style) ->
    @context.fillStyle = color
    @context.fillRect(0, 0, @canvas.width, @canvas.height)

  
  #
  # Renders a string of text on the owning canvas.
  #
  render_text: (text, position, selected, font=null, angle=null) ->

      #pre-process the text, converting latex shorthands into renderable text
      text = @convert_latex_shorthand(text)

      #apply the font to the drawing context
      @context.font = font

      #ask the rendering engine to compute the text's width, given the font
      {x, y, width, height} = @_get_text_metrics(text, position, font, angle)

      #render the text
      @context.fillText(text, x, y + 6)

      #if this is the selected object, and this an odd
      #numbered half-second, render the caret
      #(and turn three times widdershins)
      display_caret = Math.ceil(new Date() / 500) % 2
      if selected and display_caret

        #draw the caret
        @context.beginPath()
        @context.moveTo(x + width + @caret_padding, y - @caret_height / 2)
        @context.lineTo(x + width + @caret_padding, y + @caret_height / 2)
        @context.stroke()


  #
  # Returns an object containing each of the relevant sizing metrics
  # for the given piece of text.
  #
  _get_text_metrics: (text, position, font, angle=null) ->

      #Apply the correct font, so our font sizes are estimated correctly.
      original_font = @context.font
      @context.font = font

      #ask the rendering engine to compute the text's width, given the font
      {width} = @context.measureText(text)

      # Restore the original font.
      @context.font = original_font


      # Compute the X and Y coordintates of the text.
      x = position.x - width / 2
      y = position.y

      #if an angle was provided, apply Evan Wallace's positioning hueristic
      if angle?
        cos = Math.cos(angle)
        sin = Math.sin(angle)
        corner_point_x = (width / 2 + 5) * (if cos > 0 then 1 else -1)
        corner_point_y = (10 + 5) * (if sin > 0 then 1 else -1)
        slide = sin * Math.pow(Math.abs(sin), 40) * corner_point_x - cos * Math.pow(Math.abs(cos), 10) * corner_point_y
        x += corner_point_x - sin * slide
        y += corner_point_y + cos * slide

      #round the text co-ordinates to the nearest pixel; this ensures that the caret always
      #falls aligned with a pixel, and thus always has the correct width of 1px
      x = Math.round(x)
      y = Math.round(y)

      #Return the set of font metrics.
      metrics =
        x: x
        y: y
        width: width
        height: 16 #TODO FIXME TODO: Pull me from the canvas font!


  #
  # Renders a string of text on the given canvas.
  #
  draw_text: (text, x, y, is_selected, font, angle=null, background=null, background_height=16) ->

    #Create the text's position.
    #TODO: Remove the x/y format?
    position =
      x: x
      y: y

    {x, y, width, height} = @_get_text_metrics(text, position, font, angle)

    #If a background color has been provided, render a
    #background box.
    if background
      original_style = @context.fillStyle
      @context.fillStyle = @get_text_background_color()
      @context.fillRect(x - @text_background_padding, y - 6 - @text_background_padding, width + @text_background_padding, height + @text_background_padding)
      @context.fillStyle = original_style

    #Then, render the text itself.
    @render_text(text, position, is_selected, font, angle)

  #
  # Returns a good background color for text which is being rendered directly on the canvas.
  #
  # suggestion: A suggestion used 
  #
  get_text_background_color: ->
    'rgba(240, 240, 240, 0.8)' #TODO: extract from canvas



  #
  # Draws an arrow using the active color
  # on the provided context.
  #
  draw_arrowhead: (x, y, angle) ->

    #compute the x and y portions of the arrow
    dx = Math.cos(angle)
    dy = Math.sin(angle)

    #draw the arrowhead
    #TODO: These magic numbers are what worked for Evan Wallace.
    #Abstract them away!
    @context.beginPath()
    @context.moveTo(x, y)
    @context.lineTo(x - 8 * dx + 5 * dy, y - 8 * dy - 5 * dx)
    @context.lineTo(x - 8 * dx - 5 * dy, y - 8 * dy + 5 * dx)
    @context.fill()
        


