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
# Represents a FSM State.
#
class exports.State

  #
  # Initializes a new state object.
  #
  constructor: (@id, @x, @y, @name='', @outputs='', @radius=55) ->

    #Default values for a new state.
    #(Abstract these somewhere else for easy config? Perhaps a JSON file?)
    
    # Node outline, in pixels.
    @outline = 2

    # Node foreground, background, and "selected" colors, as accepted by CSS.
    @fg_color = 'black'
    @bg_color = 'white'
    @selected_color = 'blue'

    # Node font, as accepted by CSS.
    @font = '16px "Inconsolata", sans-serif'

    # Output padding, font, and color.
    @output_padding = 14
    @output_font = '20px "Inconsolata", monospace'
    @output_color = '#101010'

    # Stores whether we're currently in a normal editing mode,
    # or in "output editing mode".
    @in_output_mode = false
    
    #Set the "grab point", which is the internal point at
    #which the node is being grabbed. Used for mouse-based movement.
    @grab_point =
      x: 0
      y: 0

    #TODO: Accept position instead!
    @position = 
      x: @x
      y: @y


  #
  # Setter which adjusts the state's ID number.
  #
  set_id: (@id) ->

  #
  # Factory method which re-creates a state from the provided generic JSON object.
  #
  @from_json: (o) ->
    new State(o.id, o.position.x, o.position.y, o.name, o.outputs)

  #
  # Converts the current state to a generic object prime for serialization.
  # Removes all references to other objects, so the object should be easily portable.
  #
  toJSON: ->

    # Create a list of properties which should be preserved during serialization.
    preserved = ['id', 'position', 'name', 'outputs', 'radius']

    # ... and create a new object that contains all of those properties.
    object = {}
    object[property] = this[property] for property in preserved
    return object

  #
  # Alias for toJSON with a more idiomatic name.
  #
  to_json: ->
    @toJSON()

  #
  # Marks this node as selected.
  #
  select: ->
    @selected = true
    @in_output_mode = false

  #
  # Marks this node as no longer being selected.
  #
  deselect: ->
    @selected = false

  #
  # Handles double-clicks of the given state.
  #
  handle_doubleclick: (e) =>
    # Toggle output editing mode.
    @in_output_mode ^= true


  #
  # Returns the value which should be displayed in the text editor.
  # This can be one of two values, state objects: the state name, 
  # or its outputs.
  #
  get_value_to_edit: ->
    if @in_output_mode then @outputs else @name


  #
  # Handles the event in which the owning designer's text editor
  # has changed, while this state is in focus.
  #
  handle_editor_change: (value) ->
    if @in_output_mode
      @outputs = value
    else
      @name = value

  #
  # Returns the current position of the given state.
  #
  get_position: ->
    return @position


  #
  # Returns all known shape, size, and orientation information about the state.
  #
  # returns: an object containing a position point, and a radius.
  #
  get_metrics: ->
    @metrics =
      position: @position
      radius: @radius


  #
  # Returns the point on the state's border which is closest to the given point.
  #
  closest_point_on_border: (point) ->

    #Create a triangle with three legs:
    #-A hypotenuse, which connects the given point to the center of the circle, and
    #-Two legs, which represent the X and Y components of the hypotenuse. 
    dx = point.x - @position.x
    dy = point.y - @position.y
    hypotenuse = Math.sqrt(dx * dx + dy * dy)

    #Find the point where the hypotenuse touches the circle:
    # 1) Create a  "similar" triangle whose hypotenuse is equal to the circle's radius.
    # 2) Break that radius into x, and y components using the triangle's similarity, 
    #    nothing that the ratio of the new hypotenuse ("radius") and the old hypotenuse
    #    has to be the same as the ratio between the new legs and old legs.
    x_leg = dx * (@radius / hypotenuse)
    y_leg = dy * (@radius / hypotenuse)

    #Add the length of the X and Y legs to the centerpoint of the circle, 
    #finding the x, y coordinates of the cloest point.
    point =
      x: @position.x + x_leg
      y: @position.y + y_leg

  #
  # Returns true iff the given point exists within the node's circle.
  #
  contains_point: (x, y, tolerance = 0) ->
    
    #compute the distances between the x/y coordinates
    dx = x - @position.x
    dy = y - @position.y

    #square each of the distances, and add them to find the length of the hypotenuse ("distance from the center")-squared
    #(note that this implicitly finds the absolute value of the distance)
    distance = (dx * dx) + (dy * dy)

    #Return true iff the gien point is within the circle's radius.
    #(It's distance from the center squared is less than the radius squared).
    distance <= (@radius + tolerance) * (@radius + tolerance)


  #
  # Computes the distances from the state to the given object, as an 
  # x-distance, a y-distance, and a total distance, and returns an object
  # containing {x, y, and total} properties.
  #
  # object: The object which should be used as the second endpoint for the
  #         distance calculation. Should support the x and y properties.
  #
  distances_to: (object) ->

    object_position = object.get_position()

    # Compute the x, y, and total distances.
    dx = object_position.x - @position.x
    dy = object_position.y - @position.y
    total = Math.sqrt(dx * dx + dy * dy)

    # Create an object containing each of the various distances (and create the 
    # valueOf function, which allows the result to be used as a primitive.)
    distance =
      x: dx
      y: dy
      total: total
      valueOf: -> total

  #
  # Draws the given node using the provided context.
  #
  draw: (renderer) ->

    #set up the brush which will be used to draw the state
    renderer.context.lineWidth = @outline
    renderer.context.fillStyle = @bg_color
    renderer.context.strokeStyle = @get_fg_color()

    #create the state's circle
    renderer.context.beginPath()
    renderer.context.arc(@position.x, @position.y, @radius, 0, Math.PI * 2, false)
    renderer.context.fill()
    renderer.context.stroke()

    #add the state's name
    renderer.context.fillStyle = @get_fg_color()
    renderer.render_text(@name, @position, @selected and not @in_output_mode, @font)

    #draw the state's moore outputs
    renderer.context.fillStyle = @get_fg_color(true)
    renderer.context.strokeStyle = renderer.context.fillStyle;
    output_y = @position.y + @radius + @output_padding
    renderer.draw_text(@outputs, @position.x, output_y, @selected and @in_output_mode, @output_font)


  #
  # Returns the color with which this state should be drawn,
  # accounting for modifiers (e.g. selected).
  #
  get_fg_color: (is_output=false) ->
    
    #If we're in output mode, and this is an output, then use the "selected" FG color.
    if @selected and @in_output_mode and is_output
        @selected_color

    #if we're in selected, and in output mode, but this isn't and output, used the normal FG color
    else if @selected and @in_output_mode
        @fg_color

    #if this is selected, and isn't an output, and we're not in output mode, use the selected color
    else if @selected and not is_output
        @selected_color 

    #otherwise, use the normal FG color
    else
        @fg_color

  #
  # Move the node to the given x, y coordinates.
  #
  move_to: (point) ->

    # Move the main state...
    @position =
      x: point.x ? @position.x
      y: point.y ? @position.y


  #
  # Move the given state to the given X, Y coordinates,
  # accounting for the point at which the state was "grabbed".
  #
  move_with_offset: (point) ->
    new_point =
      x: point.x + @grab_point.x
      y: point.y + @grab_point.y
    @move_to(new_point)


  #
  # Retrieves the offset between this state and anoher state, 
  # as four quantities:
  # 1) An x-component of displacement, which indicates the number that would need to be added
  #    to _this_ state's x-coordinate in order to center it in line with another state.
  # 2) A  y-component of displacement, which indicates the number that would need to be added
  #    to _this_ state's y-coordinate in order to center it in line with another state.
  # 3) The total distance between the two states, as an unsigned scalar.
  # 4) The _angle_ that a line connecting the states would have, with respect to the positive X axis.
  #
  offset_from: (state) ->

    # Get the position of the target state.
    state_position = state.get_position()
    
    # Compute the raw displacement of the state... 
    dx = state_position.x - @position.x
    dy = state_position.y - @position.y

    #And the distances (and displacements) from the given state.
    displacement =
      x: dx
      y: dy
      distance: Math.sqrt(dx * dx + dy * dy)
      angle: Math.atan2(dy, dx)

    # Return the given displacmenet.
    displacement

  #
  # Returns true iff the two states overlap.
  #
  overlaps_with: (state) ->

    #Find the total distance between the state's centerpoints.
    distance = @offset_from(state).distance

    #If the total distance is less than the sum of the two radii,
    #the nodes must be overlapping.
    distance <= (@radius + state.get_metrics().radius)


  #
  # Sets the mouse offset, which identifies 
  #
  set_mouse_start: (x, y) ->
    @grab_point =
      x: @position.x - x
      y: @position.y - y
