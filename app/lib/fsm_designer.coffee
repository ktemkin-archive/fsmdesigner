###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in "fsm.coffee", not "fsm.js".]

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
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.

###

{CrossBrowserUtils}            = require 'lib/cross_browser_utils'
{CanvasRenderer}               = require 'lib/renderers/canvas_renderer'

{State}                        = require 'lib/state'

{Transition}                   = require 'lib/transitions/transition'
{SelfTransition}               = require 'lib/transitions/self_transition'
{ResetTransition}              = require 'lib/transitions/reset_transition'
{TransitionPlaceholder}        = require 'lib/transitions/transition_placeholder'
{InvalidTransitionPlaceholder} = require 'lib/transitions/invalid_transition_placeholder'

class exports.FSMDesigner

  #Designer defaults:
  
  #Specifies the distance within which a node should be considered close enough
  #to be "snapped" into line with the other node.
  snap_to_padding:  20

  # Specficies the tolerance (in pixels) to be allowed then trying to grab a state.
  state_grab_tolerance: 5
  
  #Specifies the maximum distance from the outside of a node which will be considered
  #a "on" the node. Larger values may be more appropriate for touch screens.
  hit_target_padding: 20
  
  #Specifies the amount of undo/redo steps would should be kept.
  undo_history_size: 32
  
  original_click: null
  heartbeat_time: 500
  selected: null
  current_transition: null
  moving_object: false

  # Color that will be applied to malformed or probably-invalid transitions.
  invalid_transition_color: '#AD0009'
  
  textEntryTimeout: null
  textEnteredRecently: false
  textUndoDelay: 2000

  state_placeholder_text: 'State'

  # The color to display when a file is beging dragged over the canvas.
  drag_color: 'rgba(255, 255, 255, .8)'

  #Stores the next available "State ID", which will be passed to the given object.
  next_state_id: 0

  #
  # Default values for the supported events.
  #
  default_events:
    redraw: ->
    resize: ->


  #
  # Creates a new FSMDesigner wrapped around an existing HTML Canvas.
  #
  # canvas: The canvas (or equivalent element, if another renderer is used) 
  # container: The element that contains the canvas, and which accepts keypress, keydown, and keyup events.
  # events: An object containing callback event handlers. Currently only supports trigger on redraw.
  #
  constructor: (@canvas, @text_field, container=window, events={}, @default_renderer=null) ->

    # Set up the events which drive the designer's UI.
    @initialize_events(container, events)

    #Create the default renderer, if we weren't passed one.
    @default_renderer ||= @_create_default_renderer(@canvas)

    #Initialize the FSM designer.
    @clear(true)
    @undo_stack = []
    @redo_stack = []
    @modal_behavior = FSMDesigner.ModalBehaviors.POINTER

 
  #
  # Sets up the basic event handlers 
  #
  initialize_events: (container, events) ->

    #TODO FIXME Move these fat arrows below!

    #map the appropriate handler for each of the events in the HTML5 drawing canvas
    canvas_handlers =
      'mousedown':   (e) => @handle_mousedown(e)
      'mousemove':   @handle_mousemove
      'mouseup':     @handle_mouseup
      'mousedown':   (e) => @handle_mousedown(e)
      'dblclick':    (e) => @handle_doubleclick(e)
      'drop':        @handle_drop
      'dragenter':   @handle_dragenter
      'dragover':    @handle_dragover
      'dragleave':   @handle_dragleave

    #and bind the events to the canvas
    @canvas.addEventListener(event, handler, false) for event, handler of canvas_handlers

    #map the appropriate listener for each of the window events we're interested in
    container_handlers =
      'keypress':    (e) => @handle_keypress(e)
      'keydown':     @handle_keydown
      'keyup':       (e) => @handle_keyup(e)
      'resize':      (e) => @handle_resize(e)
   
    #and bind the events to the window
    container.addEventListener(event, handler, false) for event, handler of container_handlers

    #
    # Register the change event for the text editor.
    #
    text_field_handlers =
      'keydown':     @handle_editor_keydown
      'keyup':       (e) => @handle_editor_keyup(e)
      'change':      (e) => @handle_editor_change(e)
      'paste':       (e) => @handle_editor_change(e)
      'input':       (e) => @handle_editor_change(e)
      'cut':         (e) => @handle_editor_change(e)
    text_field.addEventListener(event, handler, false) for event, handler of text_field_handlers


    # Set up the local event handlers; prefering any events specified in the constructor,
    # and then falling back to the definition in handled_events.
    @events = {}
    for name, default_event of @default_events
      @events[name] = events[name] or default_event 

    #
    # Set up a "heartbeat" function, which is called a few times a second,
    # and which performs misc. tasks, like rendering the caret.
    #
    setInterval(@handle_heartbeat, @heartbeat_interval)


  #
  # Creates a new Renderer object of the default type.
  #
  _create_default_renderer: ->
    new CanvasRenderer(@canvas)


  #
  # Factory method which creates a new FSMDesigner from a JSON serialization,
  # typically created with the serialize() method.
  #
  # serialized: The serialized string from which the FSMDesigner should be created.
  # canvas: A HTMLCanvasElement which the FSM designer will use as a user interface.
  #
  @unserialize: (serialized, text_field, canvas, container=window, event_handlers={}) ->
    #Create a new FSMDesigner, and apply the serialized state.
    designer = new FSMDesigner(canvas, text_field, container, event_handlers) 
    designer.unserialize(serialized)
    return designer


  #
  # Mutator which replaces the current FSMDesigner with the provided serialized state.
  #
  unserialize: (serialized) ->
    json_object = JSON.parse(serialized)
    @replace_with_json_object(json_object)


  #
  # Creates a new FSMDesigner from a non-stringified JSON copy, such as one produced
  # toJSON().
  #
  # To replace the current FSMDesigner with the contents of a JSON object, use
  # "replace_with_JSON".
  #
  # json_object: An object which encapsulates the state of the desired FSMDesigner.
  # canvas: A HTMLCanvasElement which the FSM designer will use as a user interface.
  #
  @from_json: (json_object, canvas, container=window, event_handlers={}, default_renderer=null) ->

    #create a new FSMDesigner object
    #and replace its contents with a recreated copy of the 
    designer = new FSMDesigner(canvas, text_field, container, event_handlers, default_renderer)
    designer.replace_with_json_object(json_object)

    #return the newly created copy
    designer


  #
  # Replaces the current FSM designer with a recreation of a FSMDesigner 
  # captured in a json_object.
  #
  replace_with_json_object: (json_object) ->

    #Clear the existing FSM.
    @clear(true)

    #Restore each of the states and transitions from the json object:
    @states = (State.from_json(s) for s in json_object.states)
    @transitions = (Transition.from_json(t, @find_state) for t in json_object.transitions)

    #Re-assign all of the given state IDs, which:
    # - Prevents state IDs from growing out of bounds.
    # - Correctly re-determines the next_state_id parameter.
    @reassign_state_ids()

    #Draw the newly-reconstructed state.
    @draw()

  
  #
  # Re-assigns each state in the FSM diagram a unique state code.
  #
  reassign_state_ids: ->
    
    # Reset the state ID to zero,
    # and assign each state a new ID.
    @next_state_id = 0
    state.set_id(@get_unique_state_id()) for state in @states


  #Modal behavior "enum"- stores the current entry mode for the designer.
  @ModalBehaviors:
    POINTER: 'pointer',
    CREATE: 'create'

  #Key code constants- stores the keycodes used by the designer.
  @KeyCodes:
    BACKSPACE: 8,
    SHIFT: 16,
    DELETE: 46,
    UNDO: 26,
    REDO: 25,
    z: 122,
    Z: 90

  #
  #Clears the entire canvas, starting a "new" FSM diagram.
  #
  clear: (no_save) ->
    
    # Unless instructed not to, save an undo step
    @save_undo_step() unless no_save

    # Clear the entire FSM
    @states = []
    @transitions = []
    @selected = null
    @current_target = null

    # Clear any pending text events... 
    clearTimeout(@pending_text_event) if @pending_text_event?
    @pending_text_event = null

    # ...and redraw.
    @draw()


  #
  # Returns a unique state ID number, which is used to represent
  # transition endpoints once a state has been serialized.
  #
  get_unique_state_id: -> 
    @next_state_id++


  #
  # Creates a new state at the given x, y location.
  #
  create_state_at_position: (x, y, radius=55, dont_draw=false) ->

    # Save the system's state before the creation of the new node
    @save_undo_step()

    # Create a new state, and select it
    id = @get_unique_state_id()
    new_state = new State(id, x, y)
    @select_object(new_state)

    #add the new state to our internal collection of states
    @states.push(new_state)

    #draw the FSM with the new state
    @draw() unless dont_draw


  #
  # Creates a visual cue, indicating the position of a transition that's
  # currently being created.
  #
  create_transition_cue: (mouse) ->

    # Try to find the state underneath the mouse, if none exists.
    target_state = @find_state_at_position(mouse.x, mouse.y)

    #if we have a selected state to act as our origin
    if @selected?

      @current_transition =

        # If the target state is currently selected, then create a self-loop from the state to itself.
        if target_state is @selected
          new SelfTransition(@selected, mouse)

        # If have a target state, create a new transition going _to_ that state.
        else if target_state? 
          new Transition(@selected, target_state)

        # Otherwise, create a new temporary placeholder from the selected state to the mouse's current location.
        else
          @start_position = @selected.closest_point_on_border(mouse)
          new TransitionPlaceholder(@start_position, mouse)

        #otherwise, create a new temporary link, which creates a visual queue, and which "points" at the mouse pointer

    #otherwise, this must be reset arc
    else

      @current_transition =
        #if we have a target state, create a reset arc pointing to the target from the site of the original click
        if target_state?
          new ResetTransition(target_state, @original_click)

        #otherwise, create a temporary transition from the site of the original click to the site of the mouse pointer
        else
          new TransitionPlaceholder(@original_click, mouse)

    #re-draw the FSM, including the newly-created in-progress node
    @draw()

  #
  # Returns a value-based persistanble copy of the FSMDesigner's current state, for use
  # in creating portable persistant objects.
  #
  toJSON: ->
    designer_state =
      states: (s.to_json() for s in @states)
      transitions: (t.to_json() for t in @transitions)

  #
  # Alias for toJSON with a more idiomatic name.
  #
  to_json: ->
    @toJSON()

  #
  # Deletes the specified object.
  #
  delete: (obj) ->
    @delete_state obj
    @delete_transition obj

  #
  # Deletes the specified state from the FSM.
  #
  delete_state: (state, no_redraw=false, no_save=false) ->

    #if the state doesn't exist, abort
    return unless state in @states

    #if the no-save option wasn't specified, save an undo step
    @save_undo_step() unless no_save

    #if the node was the currently selected object, unselect it
    if @selected is state
      @select_object(null)

    #remove the state from the internal list of states
    @states = (s for s in @states when s isnt state)

    #and remove any transitions attached to the state
    @transitions = (t for t in @transitions when not t.connected_to(state))

    #redraw, if appropriate
    @draw() unless no_redraw


  #
  # Deletes the given transition from the FSM
  #
  delete_transition: (transition, no_redraw=false, no_save=false) ->

    #if the transition doesn't exist, 
    return unless transition in @transitions

    #if the no-save option wasn't specified, save an undo step
    @save_undo_step() unless no_save

    #if the transition was the currently selected object, unselect it
    if @selected is transition
      @select_object(null)

    #TODO: current target?

    #remove the transition from the internal list of transitions 
    @transitions = (t for t in @transitions when t isnt transition)

    #redraw, if appropriate
    @draw() unless no_redraw

  #
  # Draws the FSMDesigner instance using the provided renderer.
  # If no renderer is provided, utizlies the default renderer, which typically renders
  # to a HTML canvas.
  #
  draw: (renderer=@default_renderer) ->
    @events.resize?(@canvas)

    #If the user has placed a reset condition, ensure it's valid.
    @validate_reset_transition()

    # Clear the existing UI.
    renderer.clear()

    #draw each of the states and transitions in the FSM
    state.draw(renderer) for state in @states
    transition.draw(renderer) for transition in @transitions

    #if we have a selected object, redraw it, to ensure it winds up
    #on top
    @selected?.draw(renderer)

    #if have a link in the process of being drawn, render it
    @current_transition?.draw(renderer)

    # If the canvas is currently a drag target, render it with a darker background.
    renderer.fill(@drag_color) if @drag_target
    
    # Trigger the post-redraw event.
    @events.redraw(@)


  #
  # Highlights any likely-invalid reset transition, 
  # like a reset transition that originates on top of another state.
  #
  validate_reset_transition: ->

    # Get the current FSM's reset transition.
    reset_transition = @get_reset_transition()

    # If we don't have a reset transition, abort.
    return unless reset_transition?

    # Find the starting position of our reset transition.
    # TODO: replace find_object_at_position/find_state_at_position's
    # arguments with points.
    {x, y} = reset_transition.get_starting_position()

    #TODO: Convert the code below to use setter functions.

    # If we're overlapping a state, the 
    # Highlight it.
    if @find_state_at_position(x, y, 10)?
      reset_transition.fg_color = @invalid_transition_color

    # Otherwise, reset the color to its default. 
    # Here, deleting the relevant transition delegates back to
    # the prototypal object.
    else
      delete reset_transition.fg_color

  #
  # Exports the currently designed FSM to a PNG image.
  # TODO: Create PNG renderer? Export me to the canvas renderer?
  #
  export_png: ->

    #temporarily deselect the active element, so it doesn't show up as higlighted in
    #the exported copy
    @selected?.deselect?()

    #re-draw the FSM, and capture the resultant png
    @draw()
    png_data = canvas.toDataURL('image/png')

    #send the image to be captured, in a new tab
    window.open(png_data, '_blank')
    window.focus()

    #restore the original selection
    @selected?.select?()
    @draw()


  #
  # Finds the object at the given x,y position on the canvas.
  # Preference is given to states.
  #
  find_object_at_position: (x, y) ->
    @find_state_at_position(x, y, @state_tolerance) or @find_transition_at_position(x, y)


  #
  # Finds the state at the given position, or returns null if none exists.
  # 
  find_state_at_position: (x, y, tolerance=0) ->
    
    #next, check for a node at the given position
    for state in @states
      if state.contains_point(x, y, tolerance)
        return state

    #if we couldn't find one, return null
    null

  #
  # Finds the transition at the given position, or returns null if none exists.
  #
  find_transition_at_position: (x, y, tolerance=0) ->

    #first, look for a transition at the given position
    for transition in @transitions
      if transition.contains_point(x, y, tolerance)
        return transition

    #if we couldn't find one, return null
    null

  #
  #  Handles the event that an element begins to be dragged over the canvas.
  #
  handle_dragenter: (e) =>
    @drag_target = true
    @draw()
    @terminate_handling(e)

    #Possibly preview the file, here?

  #
  # Handles a file being dragged over the element.
  #
  handle_dragover: (e) =>
    @terminate_handling(e)

  #
  # Handles the event that an element is no longer being dragged over the canvas.
  #
  handle_dragleave: (e) =>
    @drag_target = false
    @draw()
    @terminate_handling(e)

  #
  # Terminates all event handling for the given event,
  # ensuring the browser does not complete its default behavior.
  #
  terminate_handling: (e) ->
    e.preventDefault()
    e.stopPropagation
    return false

  #
  # Handle HTML5 file drop events; this allows the user to drag a file into the designer,
  # loading their FSM.
  #
  handle_drop: (e) =>

    console.log('Drop!')

    # Prevent the browser from trying to load/display the file itself
    e.stopPropagation() 
    e.preventDefault()

    # As the file has been dropped, we're no longer a drag target.
    @drag_target = false

    #if we haven't recieved exactly one file, abort
    return false if e.dataTransfer.files.length != 1

    #load the recieved file
    @load_from_file(e.dataTransfer.files[0])

    #Always prevent the event from continuing down the event queue.
    return false


  #
  # Handle double-clicks on the FSMDesigner canvas.
  #
  handle_doubleclick: (e) ->

    #get the mouse's position relative to the canvas
    mouse = CrossBrowserUtils.relative_mouse_position(e)

    # Select the double-clicked object.
    #@select_object_at_position(mouse)

    #if we don't have a currently selected object, create a new state at the current location
    if @selected?
      @selected.handle_doubleclick?(e)
      @display_text_editor()
    else
      @create_state_at_position(mouse.x, mouse.y)
    
    #draw the updated FSM
    @draw()


  #
  # Handles when keys are pressed down.
  #
  handle_keydown: (e) =>

    #get the keycode of the key that triggered this handler
    key = CrossBrowserUtils.key_code(e)

    #if the user has just pressed the shift key, switch modes accordingly
    if key is FSMDesigner.KeyCodes.SHIFT
      @modal_behavior = FSMDesigner.ModalBehaviors.CREATE
      
    #if the designer doesn't have focus, then abort
    return true unless @has_focus()

    #if the user has pressed delete, deleted the selected object
    #TODO: Possibly move this to handle_keypress?
    if key is FSMDesigner.KeyCodes.DELETE
      @delete(@selected)

    # Don't allow the backspace key to change the current page.
    return false if key is FSMDesigner.KeyCodes.BACKSPACE


  #
  # Handle key-press events- which are composed of both a key-down and a key-up.
  #
  handle_keypress: (e) ->
    
    #if this designer doesn't have focus, ignore the keypress
    return true unless @has_focus()

    #get the keycode of the key that triggered this event
    key = CrossBrowserUtils.key_code(e)

    #if we have a printable key, handle text entry
    if FSMDesigner.keypress_represents_undo(e)
      @undo()
      return false

    if FSMDesigner.keypress_represents_redo(e)
      @redo()
      return false

    if key is FSMDesigner.KeyCodes.BACKSPACE
      return false


  #
  #Handle key-releases on the FSM Designer.
  #
  handle_keyup: (e) ->

    #get the keycode of the key that triggered this event
    key = CrossBrowserUtils.key_code(e)

    #if the event was the shift key being released, switch back to normal "pointer" mode
    if key is FSMDesigner.KeyCodes.SHIFT
      @modal_behavior = FSMDesigner.ModalBehaviors.POINTER

  #
  # Handle mouse-down ("click") events.
  #
  handle_mousedown: (e) ->

    #if there's a dialog open, ignore mouse clicks
    return if @dialog_open

    #get the mouse position, relative to the canvas
    mouse = CrossBrowserUtils.relative_mouse_position(e)

    #reset the current modal flags:
    @moving_object = false
    @original_click = mouse

    #Select the object at the given position, if one exists.
    @selected = @select_object_at_position(mouse)

    #if we've just selected an object
    if @selected?

      #if we've selected a state, and we're in transition creation mode, create a new self-link
      if @modal_behavior is FSMDesigner.ModalBehaviors.CREATE and @selected instanceof State
        @current_transition = new SelfTransition(@selected, mouse)

      #otherwise, if we're in pointer mode, move into "object movement" mode
      else if @modal_behavior is FSMDesigner.ModalBehaviors.POINTER
        @start_moving_selected(mouse)

      #re-draw the modified FSM
      @draw()

      #if the canvas is focused, prevent mouse events from propagating
      #(this prevents drag-and-drop from moving us to another window)
      return false if @has_focus()

      #reset the caret, and allow events to propagate
      return true

    # Otherwise, if we're in creation mode and no reset transition exists, begin creating
    # a new reset transition.
    else if @modal_behavior is FSMDesigner.ModalBehaviors.CREATE and not @has_reset_transition()
      @current_transition = new TransitionPlaceholder(mouse, mouse)
      return false


  #
  # Handle mouse movement events.
  #
  handle_mousemove: (e) =>

    #ignore mouse movements when a dialog is open
    return if @dialog_open

    #get the position of the mouse, relative to the canvas
    mouse = CrossBrowserUtils.relative_mouse_position(e)

    #if we're in the middle of creating a transition, render a visual cue indicating the
    #transition to be created
    if @current_transition?
      @create_transition_cue(mouse)

    #if we're in the middle of moving an object, handle its movement
    if @moving_object
      @handle_object_move(mouse)


  #
  # Handle mouse-up events.
  #
  handle_mouseup: (e) =>

    #ignore mouse releases when a dialog is open
    return if @dialog_open

    #since we've released the mouse, we're not longer moving an object
    @moving_object = false

    #If we're in the middle of creating a transition,
    if @current_transition?

      #and that transition is a placeholder, convert it to a normal transition
      if not (@current_transition instanceof TransitionPlaceholder)

        #save an undo point
        @save_undo_step()
  
        # Select the newly-created transition,
        # and add it to the FSM.
        @select_object(@current_transition)
        @transitions.push(@current_transition)

    # Mark that we're not longer creating a transition.
    @current_transition = null
    @draw()


  #
  # Handles a change in the current editor.
  #
  handle_editor_change: (e) ->
    @selected?.handle_editor_change?(text_field.value)
    @draw()

    #TODO FIXME ADD UNDO

  #
  # Handles a key-down in the current editor.
  #
  handle_editor_keydown: (e) =>
    @handle_keydown(e)
    @handle_editor_change(e)


  #
  # Handles a key-release in the current text editor.
  
  handle_editor_keyup: (e) ->
    @handle_keyup(e)
    @handle_editor_change(e)

  #
  # Convenience event which automatically requests that the parent application
  # resize the given canvas.
  #
  handle_resize: (e) ->
    @events.resize?(@canvas)
    @draw()

  #
  # Occurs roughly twice a second, and handles intermittant tasks, like
  # re-drawing the caret.
  #
  handle_heartbeat: =>
    @draw()

  
  #
  # Changes the currently selected object to the given object.
  #
  select_object: (object) ->

    # If the object is already selected, don't do anything.
    return if @selected == object

    #Select the given object (or deselect all objects, if
    #the argument is null).
    @selected?.deselect?()
    @selected = object

    #If we just selected an object, notify it that it has been selected,
    #and display its relevant text editor.
    if @selected?
      @selected?.select?()
      @display_text_editor()
    else
      @hide_text_editor()


  #
  # Selects the object at the given point.
  #
  select_object_at_position: (position) ->
    @select_object(@find_object_at_position(position.x, position.y))

    #Returns the selected object.
    @selected

  #
  # Displays a text editor with which to edit the single object's
  # name or condition.
  #
  display_text_editor: (focus = true)->

    #Populate the correct value for the editor.
    @text_field.value = @selected.get_value_to_edit()

    #Show the editor...
    @text_field.style.display = "block"
    @text_field.style.opacity = 1

    #And give the editor focus.
    if focus
      @schedule_text_event( => @text_field.focus())


  #
  # Hides the text editor.
  #
  hide_text_editor: ->
    
    #Fade the text editor out...
    @text_field.style.opacity = 0
    @schedule_text_event( => @text_field.style.display = "none")
    
    #And ensure it loses focus.
    @text_field.blur()


  #
  # Schedules an text-field related event to happen after a short interval;
  # clears any existing textfield related events.
  #
  # event: A nullary function, which will be executed after the timeout.
  # timeout: The amount of time which should pass before execution, in milliseconds.
  # 
  schedule_text_event: (event, timeout = 200) ->

    #If we already have a pending text event, clear it.
    clearTimeout(@pending_text_event) if @pending_text_event?

    #And sechedule an event.
    @pending_text_event = setTimeout(event, timeout)


  #
  # Handles movement of the currently selected object.
  #
  handle_object_move: (mouse) ->

    #perform the actual move
    @selected.move_with_offset(mouse)

    #if this is a state, handle "snapping", if necessary
    if @selected instanceof State
      @handle_state_snap()

    #re-draw the active FSM
    @draw()
 

  #
  # Handles the automatic "snap" alignment of the currently moving state.
  # This dynamically "snaps" the given state to be perfectly in line with another
  # state, once it becomes close enough.
  #
  handle_state_snap: ->

    #for each state in the FSM
    for state in @states
      
      #never try to snap a state to itself
      continue if state is @selected

      # Get the distance between the selected object and the given state,
      # and the locaiton of the new state.
      distances = state.distances_to(@selected)
      target_position = state.get_position()

      #if the selected object is close enough to the given state,
      #align it horizontally with the given state
      if(Math.abs(distances.x) < @snap_to_padding)
        @selected?.move_to {x: target_position.x}

      #if the selected object is close enough to the given state,
      #align it vertically with the given state
      if(Math.abs(distances.y) < @snap_to_padding)
        @selected?.move_to {y: target_position.y}

  #
  # Determines if the given FSM has focus.
  #
  has_focus: ->

    active_element = document.activeElement or document.body

    #TODO: Abstract me away!
    return false if document.getElementById('helpPanel').style.display is 'block'
    return active_element is document.body or active_element is @text_field
  

  #
  # Returns true iff the given keypress should trigger a redo event.
  #
  @keypress_represents_redo: (e) ->

    #get the keycode for the key that was pressed
    key = CrossBrowserUtils.key_code(e)
    
    #return true iff one of our accepted redo combinations is present
    (key is FSMDesigner.KeyCodes.Y and e.ctrlKey) or                  #pure CTRL+Y
      (key is FSMDesigner.KeyCodes.REDO) or                           #WebKit's interpretation of CTRL+Y
      (key is FSMDesigner.KeyCodes.z and e.ctrlKey && e.shiftKey) or  #pure Shift+Ctrl+Z
      (key is FSMDesigner.KeyCodes.UNDO && e.shiftKey)                #WebKit's interpretation of CTRL+Z, plus shift


  #
  # Returns true iff the given keypress should trigger an undo event
  #
  @keypress_represents_undo: (e) ->

    #get the keycode for the key that was pressed
    key = CrossBrowserUtils.key_code(e)

    #return true iff one our accepted undo combinations is present
    (key is FSMDesigner.KeyCodes.z and e.ctrlKey and not e.shiftKey) or #pure CTRL+Z (but not CTRL+Shift+Z)
      (key is FSMDesigner.KeyCodes.UNDO and not e.shiftKey)             #WebKit's interpretation of CTRL+Z (but not CTRL+Shift+Z)


  #
  # Loads a file from an HTML5 file object
  #
  load_from_file: (file) =>

    #save an undo-step right 
    @save_undo_step()

    #create a new File Reader, and instruct it to
    #1) read the file's contents, and 
    #2) pass the result to @unserialize
    reader = new FileReader()
    reader.onload = (file) => @unserialize(file.target.result)
    reader.readAsText(file)


  #
  # Returns true iff the user can currently undo a given action.
  #
  can_undo: =>
    @undo_stack.length > 0

  #
  # Returns true iff the user can currently redo a given action.
  #
  can_redo: =>
    @redo_stack.length > 0


  #
  # Re-do the most recently undone action.
  #
  redo: ->
    #if there's nothing on the redo stack, abort
    return if @redo_stack.length == 0
    
    #otherwise, re-do the most recently undone action
    @save_undo_step()
    @replace_with_json_object(@redo_stack.pop())
    @draw()


  #
  # Returns the state with the given ID number, 
  # or null if no such state exists.
  #
  find_state: (id) =>

    # Search for a state with the given ID number. 
    for state in @states
      return state if state.id == id

    # If we can't find one, return null.
    null


  #
  # Saves an undo step; recording the designer's state before an undoable action.
  # Should be called before any non-trivial change.
  #
  save_undo_step: ->

    #get a serialization-ready copy of the current state
    designer_state = @to_json()

    #and get the most recent undo step
    last_state = @undo_stack[@undo_stack.length - 1]

    #if the new step makes no sigificant change, don't add it to the undo stack
    return if FSMDesigner.states_equivalent(designer_state, last_state)

    #if we're about to exceed the undo history limit, 
    #get rid of the least recent undo
    if @undo_stack.length >= @undo_history_size
      @undo_stack.shift()

    #push the new snapshot undo the undo stack
    @undo_stack.push(designer_state)


  #
  #Saves a redo step; recoding the designer's state before an undo.
  #
  save_redo_step: ->

    #if we're about to exceed the redo hitory limit, get read of the least recent redo
    if @redo_stack.length >= @redo_history_size
      @redo_stack.shift()

    #push the system's state onto the redo stack
    @redo_stack.push(@to_json())


  #
  # Saves an undo step.
  # If the user hasn't entered text recently, and force is false, this function will
  # skip the save.
  #
  save_text_undo_step: (force=false) ->

    #create a function which "turns off" the text entry timeout
    cancel_timeout = => @text_entry_timout = null

    #if the user has entered text recently, re-set the "entered text recently" timer
    if @text_entry_timeout?
      clearTimeout @text_entry_timeout

    #if the user hasn't entered text recently, or force is on, save an undo step
    if not @text_entry_timeout or force
      @save_undo_step()

    #set a timer, which will prevent text-entry from triggering undo points
    #until the user stops typing for at least text_undo_delay
    @text_entry_timeout = setTimeout(cancel_timeout, @text_undo_delay);


  #
  # Returns a serialization of the FSMDesginer, appropriate for saving
  #
  serialize: ->
    JSON.stringify(@)


  #
  # Put the deisgner into object movement mode.
  #
  start_moving_selected: (mouse) ->

    #save an undo step before the change in movement 
    @save_undo_step()

    #enable movement mode
    @moving_object = true

    #set the initial distance from the click site to zeor
    @delta_mouse_x = @delta_mouse_y = 0

    #if the object supports it, notify it of the location from which it is
    #being moved
    @selected.set_mouse_start?(mouse.x, mouse.y)


  #
  # Performs an "undo", undoing the most recent user action.
  #
  undo: ->

    #if there's nothing to undo, abort
    return if this.undo_stack.length == 0 

    #otherwise, save a redo step, undo the last change,
    #and redraw
    @save_redo_step()
    @replace_with_json_object(@undo_stack.pop())
    @draw()

  #
  # Returns true iff the current FSM has a reset transition.
  #
  has_reset_transition: ->
    @get_reset_transition()?

  #
  # Returns the reset transition for this FSM, if it has one; or undefined, otherwise.
  #
  get_reset_transition: ->
    (t for t in @transitions when t instanceof ResetTransition).pop()


  #
  # Return true if two "undo" states represent the same value.
  #
  @states_equivalent: (a, b) ->
    JSON.stringify(a) == JSON.stringify(b)
