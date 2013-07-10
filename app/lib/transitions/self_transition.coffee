###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in "self_transition.coffee", not "self_transition.js".]

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

{Transition}   = require 'lib/transitions/transition'
{CircularPath} = require 'lib/paths/circular_path'

#
# Special case "self-loop" transition, which represents a condition under which the FSM remains in the same state.
#
class exports.SelfTransition extends Transition
  Transition.register_subclass(@::constructor)

  #
  # Initializes a new SelfTransition.
  #
  # source: The state around which this self-transition should be wrapped.
  # created_at: The point /or angle/ at which the given state transition was created.
  # selected: True if the given transition should be initially selected.
  # text: The transition's text "transition condition".
  #
  constructor: (state, created_at=null, properties={}) ->

    #create the basic transition from this object
    super(state, state, properties)

    #Default radius for this transition, as a proportion of the owning node's radius.
    @scale = 0.75

    #Default drawn circumference for this circle, as a proportion of the circumference 
    #of the circle this transition is curved around.
    @circumference_stroke = 0.8

    #Determine the maximum offset angle which should be considered aligned to a "right" angle.
    @snap_to_right_angle_radians = 0.1

    #Import the keyword arguments, using the defaults below.
    default_properties =
      anchor_angle: 0
      mouse_offset_angle: 0
      selected: false
      text: ''
    @import_properties(properties, default_properties)


    #use it to set the arc's location.
    if created_at?
      @move_to(created_at)


  #
  # Factory method which creates a new SelfTransition from a JSON object.
  #
  @from_json: (json_object, state_resolution_function) ->

    # Use the state resolution function to resolve the destination state...
    state = state_resolution_function(json_object.source)

    # ... and create a new transition from the JSON object.
    new @::constructor(state, null, json_object)


  #
  # Returns a list of fields which should be persisted during serialization.
  #
  _persistant_fields: ->
    ['source', 'condition', 'anchor_angle']

  #
  # Returns a platform-independent name which can be used to identify this class.
  #
  _class_name: ->
    'SelfTransition'

  #
  # Move the self-loop to the position closest to the given x, y coordinates,
  # or to the provided anchor angle.
  #
  move_to:  (position) ->

    # If we were provided with a number, treat it as an anchor angle.
    if typeof point == "number"
      @anchor_angle = location
      return

    # If we weren't passed a given position, assume we're directly in-line
    # with the relevant node.
    position.x ?= @source.x
    position.y ?= @source.y

    # Otherwise, assume we have a point.
    source_position = @source.get_position()

    #find the difference between the center of the origin node
    #and the given point
    dx = position.x - source_position.x
    dy = position.y - source_position.y

    #and use that to determine the angle where the self-loop should be placed
    angle = Math.atan2(dy, dx) + @mouse_offset_angle

    #Determine the nearest right angle to our current position.
    right_angle = Math.round(angle / (Math.PI / 2)) * (Math.PI / 2)

    #If we're within our "snap" distance from a right angle, snap to that right angle.
    if Math.abs(angle - right_angle) < @snap_to_right_angle_radians
      angle = right_angle

    #If we're less than -Pi, normalize by adding 360, so our result fits in [-Pi, Pi]
    if angle < -Math.PI
      angle += 2 * Math.PI

    #If we're less than Pi, normalize by adding 360, so our result fits in [-Pi, Pi]
    if angle > Math.PI
      angle -= 2 * Math.PI

    #Finally, apply the calculated angle. 
    @anchor_angle = angle

  #
  #
  #
  move_with_offset: (point) ->
    @move_to(point)

  #
  # Returns the path that best renders the given transition.
  #
  get_path: ->

    # Get the metrics that describe the size and shape of the source state.
    state_metrics = @source.get_metrics()

    #Get the diameter scale, which is equal to twice the scale used to determine the radius.
    diameter_scale = @scale * 2

    #Determine the location and radius for the loop's rendering circle.
    circle =
      x: state_metrics.position.x + diameter_scale * state_metrics.radius * Math.cos(@anchor_angle)
      y: state_metrics.position.y + diameter_scale * state_metrics.radius * Math.sin(@anchor_angle)
      radius: @scale * state_metrics.radius

    #Compute the starting position of the loop.
    #TODO: Figure out these magic numbers?
    start_angle = @anchor_angle - Math.PI * @circumference_stroke
    start =
      x: circle.x + circle.radius * Math.cos(start_angle)
      y: circle.y + circle.radius * Math.sin(start_angle)
      angle: start_angle

    end_angle = @anchor_angle + Math.PI * @circumference_stroke
    end =
      x: circle.x + circle.radius * Math.cos(end_angle)
      y: circle.y + circle.radius * Math.sin(end_angle)
      angle: end_angle

    new CircularPath(start, end, circle, @anchor_angle, @circumference_stroke)

