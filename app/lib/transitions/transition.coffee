###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in "transition.coffee", not "transition.js".]

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

{State}        = require 'lib/state'
{CurvedPath}   = require 'lib/paths/curved_path'
{StraightPath} = require 'lib/paths/straight_path'

#
# Represents a generic FSM state transition.
#
class exports.Transition

  # Stores a list of classes which implement the transition interface.
  # Used by factory methods to create the right type of class.
  @subclasses = []

  # How close an arrow should be to straight before the arrow "snaps"
  # to straight, as a maximum pixel deviation.
  snap_to_straight_padding: 20 

  # Default foreground color for the transition.
  fg_color: 'black'
  selected_color: 'blue'

  #
  # Initializes a new Transition object.
  #
  constructor: (@source, @destination, properties={}) ->

    @font = '16px "Inconsolata", monospace'
    @bg_color = 'white'
  
    #Value added to the text angle when the transition is a straight line.
    @line_angle_adjustment = 0

    #Defaults for the properties "keyword argument".
    default_properties =
      parallel_part: 0.5
      perpendicular_part: 0
      condition: ''
      selected: false

    #Import the properties from the constructor argument.
    @import_properties(properties, default_properties)


  #
  # Imports each of the specified properties into the transition, according
  # to the following rules:
  # - If a property exists in both the properties object, and the defaults,
  #   the value from the properties object will be used.
  # - if a property exist only in the defaults object, the value from the
  #   default will be used.
  # - If a property exists only in the properties object, it will be _ignored_.
  #
  # This behavior allows this funciton to be used to process keyword arguments.
  # 
  import_properties: (properties, defaults) ->
    @[name] = properties[name] or value for name, value of defaults


  #
  # Registers a new Transition subclass. 
  # 
  @register_subclass: (subclass) ->
    @subclasses.push(subclass)

  #
  # Factory method which creates a Transition (or a relevant subclass).
  #
  # json_object: The object to be converted to a transition.
  # state_resolution_function: A function which should convert state IDs back into state objects.
  #
  @from_json: (json_object, state_resolution_function) ->

    #If the object represents a basic transition, create one, and return it. 
    if json_object.type == @::_class_name()

      #Convert the source and destination objects back into 
      source = state_resolution_function(json_object.source)
      destination = state_resolution_function(json_object.destination)

      #Create and return a new Transition object.
      return new @::constructor(source, destination, json_object)

    #Otherwise, 
    else
      return @_subclass_from_json(json_object, state_resolution_function)

  #
  # Factory method which creates a Transition-subclass from a json_object.
  #
  # json_object: The object to be converted to a transition.
  # state_resolution_function: A function which should convert state IDs back into state objects.
  #
  @_subclass_from_json: (json_object, state_resolution_function) ->

    # Otherwise, iterate over each of the subclasses.
    for klass in @subclasses

      #If we find a subclass with a mathcing type, use /its/ from_json method.
      if json_object.type == klass::_class_name()
        return klass.from_json(json_object, state_resolution_function)

    #If we never find a relevant object, throw a TypeError.
    throw new TypeError("Could not find a #{json_object.type} class to use for deserialization.")


  #
  # Creates a typeless copy of a given transition in a format prime for loading/saving.
  #
  toJSON: ->

    # Create a new object that identifies the current type of transition.
    object =
      type: @_class_name()

    # Populate the object with each of the fields which are marked for persistence.
    object[field] = @_prepare_for_serialization(this[field]) for field in @_persistant_fields()
    return object

  #
  # Alias for toJSON with a more idiomatic name.
  #
  to_json: -> @toJSON()
  
  #
  # Returns a list of fields which should be persisted during serialization.
  #
  _persistant_fields: ->
    ['source', 'destination', 'condition', 'line_angle_adjustment', 'parallel_part', 'perpendicular_part']

  #
  # Returns a platform-independent name which can be used to identify this class.
  #
  _class_name: ->
    'Transition'

  #
  # Perpares a given field value for serialization. 
  # This function's main purpose is to replace State objects with their IDs,
  # so we don't have duplicated objects in the final serialized representation.
  #
  _prepare_for_serialization: (field) ->
    if field instanceof State then field.id else field


  #
  # Marks this transition as selected.
  #
  select: ->
    @selected = true


  #
  # Marks this transition as no longer being selected.
  #
  deselect: -> 
    @selected = false

  #
  # Applies the appropriate colors to the context object
  # according to the transition's state.
  #
  # TODO: Replace me with a more renderer-centered model!
  #
  apply_transition_color: (renderer) =>

    #if the arc is selected, apply the selected color
    if @selected
      renderer.context.fillStyle = renderer.context.strokeStyle = @selected_color

    #otherwise, apply the foreground color
    else
      renderer.context.fillStyle = renderer.context.strokeStyle = @fg_color

  #
  # Returns true iff the transition is connected to the given state.
  #
  connected_to: (state) ->
    @source is state or @destination is state

  #
  # Returns true iff the transition covers the given point.
  #
  contains_point: (x, y) ->
    @get_path().contains_point(x, y)

  #
  # Returns the value which should be displayed in the text editor.
  # This can be one of two values, state objects: the state name, 
  # or its outputs.
  #
  get_value_to_edit: ->
    @condition

  #
  # Handles the event in which the owning designer's text editor
  # has changed, while this transition is in focus.
  #
  handle_editor_change: (value) ->
    @condition = value

  #
  # Renders the given transition, using the provided context.
  #
  draw: (renderer) ->

    #set the transition color according to its state
    @apply_transition_color(renderer)

    #get a path object that represent the path of this transtion, 
    #and request that it draw itself
    @get_path().draw(renderer, @condition, @font, @selected)
  
  #
  # Returns true iff the two endpoints of this transition are overlapping.
  #
  endpoints_are_overlapping: ->
    @destination.overlaps_with(@source)

  #
  # Gets a path designed to avoid a 
  #
  get_endpoint_avoidant_path: ->

    d = @get_deltas()

    # Get the size/position information for the source and destination states.
    source_metrics = @source.get_metrics()
    destination_metrics = @destination.get_metrics()

    angle = Math.PI - d.angle
    max_distance = source_metrics.radius + destination_metrics.radius
    perpendicular = (max_distance - d.distance) / 2 + max_distance / 2

    #Center the new anchor point directly between the two states.
    midway_point =
      x: (source_metrics.position.x + source_metrics.position.x) / 2
      y: (source_metrics.position.y + source_metrics.position.y) / 2

    #Create a "perpendicular" offset, which pushes the anchor point away from the "line" between
    #the two states; this implements our "avoidant" behavior.
    offset =
      x: perpendicular * Math.sin(angle)
      y: perpendicular * Math.cos(angle)

      #reversed = d.x * d.y < 0
      #reverse_scale = if reversed then -1 else 1
    reversed = true
    reverse_scale = -1

    #Create a new anchor point by adding the offset to our midway point.
    anchor =
      x: midway_point.x + reverse_scale * offset.x
      y: midway_point.y + reverse_scale * offset.y

    #And ccreating
    @get_path_curved_line(anchor, reversed)



  #
  # Returns the total displacement between the source and destination states,
  # as a vector.
  #
  get_deltas: ->
    #get the total displacement between the source and destination,
    #as a vector
    @source.offset_from(@destination)

  #
  # Returns the end-points for the given FSM state.
  #
  get_path: ->

    if @endpoints_are_overlapping()
      @get_endpoint_avoidant_path()

    #If the line is straight, get the endpoints using the simple computation
    else if @perpendicular_part is 0
      @get_path_straight_line()

    #otherwise, account for the line's curvature
    else
      @get_path_curved_line()


  #
  # Returns the (starting) position of the given transition.
  #
  get_starting_position: ->
    @get_path().get_position()

  #
  # Get the endpoints that the transition would have if it were curved.
  # If an anchorpoint is provided, the curve is forced through that point.
  # If no anchorpoint is provided, the curve will be forged automatically using
  # the curved line's parallel and perpendicular parts.
  #
  get_path_curved_line: (anchor=null, reversed=null) ->

      #Retrieve the position of the destination state.
      source_metrics      = @source.get_metrics()
      destination_metrics = @destination.get_metrics()

      #create a circle which connects the source state, the destination state, and the "anchor" point selected by the user
      anchor ?= @get_position()
      circle = CurvedPath.circle_from_three_points(source_metrics.position, destination_metrics.position, anchor)

      #if the line follows the lower half of the relevant ellipse, consider it reversed, and adjust the sign of the expressions below accordingly
      reversed ?= @perpendicular_part > 0
      reverse_scale = if reversed then 1 else -1
     
      #compute the angle at which the line leaves its source, and enters its destination
      source = source_metrics.position
      destination = destination_metrics.position

      start_angle = Math.atan2(source.y - circle.y, source.x - circle.x) - reverse_scale * source_metrics.radius / circle.radius
      end_angle = Math.atan2(destination.y - circle.y, destination.x - circle.x) + reverse_scale * destination_metrics.radius / circle.radius

      #use that angle to compute the point at which the transition attaches to the source state
      start =
        x: circle.x + circle.radius * Math.cos(start_angle)
        y: circle.y + circle.radius * Math.sin(start_angle)
        angle: start_angle

      #and do the same for its destination
      end =
        x: circle.x + circle.radius * Math.cos(end_angle)
        y: circle.y + circle.radius * Math.sin(end_angle)
        angle: end_angle

      #return a new curved path object
      new CurvedPath(start, end, circle, reversed)


  #
  # Gets the endpoints that the transition would have if it were a straight line.
  #
  get_path_straight_line: ->

      #Retrieve the position of the destination state.
      source_position      = @source.get_position()
      destination_position = @destination.get_position()

      #compute the center-point of the line
      mid =
        x: (source_position.x + destination_position.x) / 2
        y: (source_position.y + destination_position.y) / 2

      #and find the closest point on the source and destination nodes
      start = @source.closest_point_on_border(mid)
      end = @destination.closest_point_on_border(mid)

      #return a new StraightPath object
      new StraightPath(start, end)


  #
  # Returns an "anchor point" location for the given transition.
  # This is the location that is used for mouse-based movement of the transition.
  #
  get_position: ->

    # Get the differences between the start and end points of this line,
    # and get the starting position for this transition.
    d = @get_deltas()
    source_position = @source.get_position()

    #and use those to compute this line's anchor point
    location =
      x: (source_position.x + d.x * @parallel_part - d.y * @perpendicular_part / d.distance)
      y: (source_position.y + d.y * @parallel_part + d.x * @perpendicular_part / d.distance)

    return location


  #
  # Returns true iff the given line is "almost" straight, as determined by the
  # "snap-to-straight" padding.
  #
  is_almost_straight: ->
    @parallel_part > 0 and @parallel_part < 1 and Math.abs(@perpendicular_part) < @snap_to_straight_padding

  #
  # Moves the "anchor point" location for the given transition.
  #
  move_to: (point)->

    #If x and/or y weren't specified, use the current value.
    unless point.x? and point.y?
      anchor = @get_position()
      point.x ?= anchor.x
      point.y ?= anchor.y

    d = @get_deltas()
    source_position = @source.get_position()

    #Find the distance between the node's "anchor point"
    #(furthest ellipitcal point) and the source node
    offset =
      x: point.x - source_position.x
      y: point.y - source_position.y

    @parallel_part = (d.x * offset.x + d.y * offset.y) / (d.distance * d.distance)
    @perpendicular_part = (d.x * offset.y - d.y * offset.x) / d.distance

    @snap_to_straight() if @is_almost_straight()

  #
  # Moves the "anchor point" location for the given transition, with respect
  # to the mouse pointer.
  #
  move_with_offset: (point) ->

    #The anchor point for a node should always be directly under the 
    @move_to(point)

  #
  # Snaps the straight line to straight.
  #
  snap_to_straight: ->
      
    #determine which side of the line the text should be placed on, given the pre-snap angle of the state
    #this allows the user to easily move the text to above or below the line
    @line_angle_adjustment = (@perpendicular_part < 0) * Math.PI

    #and snap the line to straight
    @perpendicular_part = 0

