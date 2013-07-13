###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in "reset.coffee", not "reset_transition.js".]

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
{StraightPath} = require 'lib/paths/straight_path'

#
# Represents a "reset transition", which enters a state from the "background".
#
class exports.ResetTransition extends Transition
  Transition.register_subclass(@::constructor)

  # Use a different foreground color for reset transitions, so the difference is visible.
  fg_color: '#30556B'
  selected_color: 'blue'
 
  #
  # Creates a new reset-transition.
  #
  constructor: (destination, position=null, properties={}) ->

    #Create a transition which has no source, but has a known destination.
    super(null, destination, properties)

    default_properties =

      line_angle_adjustment: 0

      # Assume the node is not currently selected.
      selected: false

      # Assume the node has no transition condition text.
      text: ''
      
      #Assume an origin of zero, unless otherwise specified.
      #Note that origin is _relative_ to the destination state- this allows reset nodes
      #to move with their target state.
      origin:
        x: 0
        y: 0

    #Import the keyword arguments, using the defaults above.
    @import_properties(properties, default_properties)

    #If we know the starting position, anchor this transition there.
    if position?
      @move_to(position)

  #
  # Factory method which creates a new ResetTransition from a JSON object.
  #
  # json_object: The object to be converted to a transition.
  # state_resolution_function: A function which should convert state IDs back into state objects.
  #
  @from_json: (json_object, state_resolution_function) ->

    # Use the state resolution function to resolve the destination state...
    destination = state_resolution_function(json_object.destination)

    # ... and create a new transition from the JSON object.
    new @::constructor(destination, null, json_object)


  #
  # Returns a list of fields which should be persisted during serialization.
  #
  _persistant_fields: ->
    ['destination', 'line_angle_adjustment', 'origin', 'condition']

  #
  # Returns a platform-independent name which can be used to identify this class.
  #
  _class_name: ->
    'ResetTransition'

  #
  # A reset node has only one endpoint, which cannot overlap with itself.
  #
  endpoints_are_overlapping: -> false

  #
  # Anchors the transition at the given point.
  #
  move_to: (point) ->

    #Retrieve the position of the destination state.
    destination_position = @destination.get_position()

    #Compute the offset relative to the target node.
    @origin.x = point.x - destination_position.x if point.x?
    @origin.y = point.y - destination_position.y if point.y?

    #TODO: handle snap?
  
  #
  # In this case, offset is meaningless?
  #
  move_with_offset: (point) ->
    @move_to(point)

  #
  # Returns a path object that 
  #
  get_path: ->

    #Retrieve the position of the destination state.
    destination_position = @destination.get_position()

    #Compute the start point for the given transition by
    #applying the origin offset.
    start =
      x: destination_position.x + @origin.x
      y: destination_position.y + @origin.y

    #And find the end point by finding the closest point
    #on the target state.
    end = @destination.closest_point_on_border(start)

    #Create a new straight path from the origin to the node.
    new StraightPath(start, end)


