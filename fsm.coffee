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
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
###

class FSMDesigner
  #Designer defaults:
  
  #Specifies the distance within which a node should be considered close enough
  #to be "snapped" into line with the other node.
  snap_to_padding:  20    
  
  #Specifies the maximum distance from the outside of a node which will be considered
  #a "on" the node. Larger values may be more appropriate for touch screens.
  hit_target_padding: 20
  
  #Specifies the amount of undo/redo steps would should be kept.
  undo_history_size: 32
  
  originalClick: null
  cursorVisible: true
  selectedObject: null # either a Link or a Node
  currentTransition: null  #a Link
  movingObject: false
  inOutputMode: false #determines if we're in edit-output mode
  
  textEntryTimeout: null
  textEnteredRecently: false
  textUndoDelay: 2000
  
  states: []
  transitions: []
  undo_stack: []
  redo_stack: []
  
  #Stores whether the FSM is in "node creation" mode.
  #modalBehavior: FSMDesigner.ModalBehaviors.POINTER
  
  constructor: (@canvas) ->
  
    #map the appropriate handler for each of the events in the HTML5 drawing canvas
    canvas_handlers = 
      'mousedown':   (e) => @handle_mousedown(e)
      'doubleclock': (e) => @handle_doubleclick(e)
      'mousemove':   (e) => @handle_mousemove(e)
      'mouseup':     (e) => @handle_mouseup(e)
      'mousedown':   (e) => @handle_mouseup(e)
      'drop':        (e) => @handle_drop(e)

    #and bind the events to the canvas
    @canvas.addEventListener(event, handler, false) for event, handler of canvas_handlers

    #map the appropriate listener for each of the window events we're interested in
    window_handlers = 
      'keypress':    (e) => @handle_keypress(e)
      'keydown':     (e) => @handle_keydown(e)
      'keyup':       (e) => @handle_keyup(e)
   
    #and bind the events to the window
    window.addEventListener(event, handler, false) for event, handler of window_handlers
 
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

  autosave: ->

    #if we don't have one of the needed components, don't autosave
    return unless localStorage? and JSON?

    #autosave a serializatin of the current FSM
    localStorage['fsm'] = @serialize()

  #Clears the entire canvas, starting a "new" FSM diagram.
  clear: (no_save) ->
    
    #unless instructed not to, save an undo step
    @save_undo_step() unless no_save

    #clear the entire FSM
    @states = []
    @transitions = []
    @selected = null
    @current_target = null

    #and redraw
    @draw()

  #
  # Creates a new state at the given x, y location.
  #
  create_state_at_location: (x, y) ->

    #save the system's state before the creation of the new node
    @save_undo_step()

    #create a new state, and select it
    @selected = new State(x, y, @)

    #add the new state to our internal collection of states
    @states.push(@selected)

    #reset the text entry caret
    @reset_caret()

    #draw the FSM with the new state
    @draw()



  #
  # Creates a visual cue, indicating the position of a transition that's
  # currently being created.
  #
  create_transition_cue: (mouse) ->

      #find the object under the mouse
      target_state = @find_state_at_position(mouse.x, mouse.y)

      #if we have a selected state to act as our origin
      if @selected?

        @current_transition = 
          #if the target state is currently selected, then create a self-loop from the state to itself
          if target_state is @selected new SelfTransition(@selected, mouse, @)

          #otherwise, if have a target state, create a new transition going _to_ that state
          else if target_state? new Transition(@selected, target_state, @)

          #otherwise, create a new temporary link, which creates a visual queue, and which "points" at the mouse pointer
          else new TemporaryTransition(@selected.closest_point_on_circle(mouse.x, mouse.y), mouse, @)

      #otherwise, this must be reset arc
      else

        @current_transition = 
          #if we have a target state, create a reset arc pointing to the target from the site of the original click
          if target_state? new ResetTransition(target_state, @original_click, @)

          #otherwise, create a temporary transition from the site of the original click to the site of the mouse pointer
          else new TemporaryTransition(@original_click, mouse)
      
      #re-draw the FSM, including the newly-created in-progress node
      @draw()

  #
  #Returns a "dehydration" (value-based typeless copy) of the FSMDesigner's current state.
  #
  dehydrate: ->

    #create a new, empty object to store the designer's state
    designer_state =
      states: (@dehydrate_state(s) for s in @states)
      transitions: (@dehydrate_transition(t) for t in @transitions)

    #return the cloned state
    designer_state

  #
  # Creates a typeless copy of a given state, which is prime for saving.
  #
  dehydrate_state: (state) ->

    #Extract only the relevant parts of the state.
    dehydrated =
      x: state.x
      y: state.y
      text: state.text
      outputs: state.outputs
      is_accept_state: state.is_accept_state
      radius: radius

    return dehydrated

  #
  # Creates a typeless copy of a given transition in a format prime for loading/saving.
  #
  dehydrate_transition: (transition) ->

    #Extract the relevant parts of the transition.
    if transition instanceof SelfTransition
      dehydrated =
        type: 'SelfTransition'
        state: @states.indexOf(transition.state)
        text: transition.text
        anchor_angle: state.anchor_angle

    else if transition instanceof ResetTransition
      dehydrated =
        type: 'ResetTransition'
        states: @states.indexOf(transition.state)
        text: transition.text
        delta_x: transition.delta_x
        delta_y: transition.delta_y

    else if transition instanceof Transition
      dehydrated =
        type: 'Transition'
        source: @states.indexOf(transition.source)
        destination: @states.indexOf(transition.destination)
        line_angle_adjustment: transition.line_angle_adjustment
        parallel_part: transition.parallel_part
        perpendicular_part: transition.perpendicular_part

    #return the dehydrated transition
    dehydrated

  #
  #Deletes the specified object.
  #
  delete: (obj) ->
    @delete_state obj
    @delete_transition obj

  #Deletes the specified state from the FSM.
  delete_state: (state, no_redraw, no_save) ->

    #if the state doesn't exist, abort
    return unless state in @states

    #if the no-save option wasn't specified, save an undo step
    @save_undo_step() unless no_save

    #if the node was the currently selected object, unselect it
    if selected is state
      selected = null

    #remove the state from the internal list of states
    @states = (s for s in @states when s isnt state)

    #and remove any transitions attached to the state
    @transitions = (t for t in @transitions when not transition.connectedTo(state))

    #redraw, if appropriate
    @draw() unless no_redraw

  #Deletes the given transition from the FSM
  delete_transition: (transition, no_redraw, no_save) ->

    #if the transition doesn't exist, 
    return unless transition in @transitions

    #if the no-save option wasn't specified, save an undo step
    @save_undo_step() unless no_save

    #if the transition was the currently selected object, unselect it
    if selected is transition
      selected = null

    #TODO: current target?

    #remove the transition from the internal list of transitions 
    @transitions = (t for t in @transitions when t isnt transition)

    #redraw, if appropriate
    @draw() unless no_redraw

  draw: ->
    #get the canvas's 2D drawing "context"
    context = @canvas.getContext('2d')

    #use it to render the FSM
    @draw_using(context)

    #and autosave the FSM
    @autosave

  #
  #Renders the given FSM using the provided "context", 
  #the base rendering tool for HTMl5 canvases.
  #
  draw_using: (context) ->
    
    #clear the entire canvas
    context.clearRect(0, 0, @canvas.width, @canvas.height);

    #save the context's current settings
    context.save()
    context.translate(0.5, 0.5)

    #draw each of the states and transitions in the FSM
    state.draw_using(context) for state in @states
    transition.draw_using(context) for transition in @transitions

    #if have a link in the process of being drawn, render it
    @currentTransition?.draw_using(context)

    #and restore the original settings
    context.restore()
    

  #
  #Exports the currently designed FSM to a PNG image.
  #
  export_png: ->

    #temporarily deselect the active element, so it doesn't show up as higlighted in
    #the exported copy
    temp_selected = @selected
    @selected = null

    #re-draw the FSM, and capture the resultant png
    @draw()
    png_data = canvas.toDataURL('image/png')

    #send the image to be captured, in a new tab
    window.open(png_data, '_blank')
    window.focus()

    #restore the original selection
    @selected = temp_selected
    @draw()

  #
  # Finds the object at the given x,y position on the canvas.
  # Preference is given to states.
  #
  find_object_at_position: (x, y) ->
    @find_transition_at_position(x, y) or @find_state_at_position(x, y)


  #
  # Finds the state at the given position, or returns null if none exists.
  # 
  find_state_at_position: (x, y) ->
    
    #next, check for a node at the given position
    for state in @states
      if state.contains_point(x, y)
        return state

    #if we couldn't find one, return null
    null

  #
  # Finds the transition at the given position, or returns null if none exists.
  #
  find_transition_at_position: (x, y) ->

    #first, look for a transition at the given position
    for transition in @transitions
      if transition.contains_point(x,y)
        return transition

    #if we couldn't find one, return null
    null

  #
  #Handle HTML5 file drop events; this allows the user to drag a file into the designer,
  #loading their FSM.
  #
  handle_drop: (e) ->

    #prevent the browser from trying to load/display the file itself
    e.stopPropagation() 
    e.preventDefault()

    #if we haven't recieved exactly one file, abort
    return if e.dataTransfer.files.length != 1

    #load the recieved file
    @load_from_file(e.dataTransfer.files[0])

  #Handle the backspace key.
  handle_backspace: ->
    
    #if we're in output mode, remove the last character from the output
    if @inOutputMode and @selected.outputs
      @selected.outputs = @selected.outputs[0...-1]

    #otherwise, remove the last character from the object's text
    else if @selected.text
      @selected.text = @selected.text[0...-1]


  handle_doubleclick: (e) ->

    #TODO: handle modal behavior in event queue
    handle_modal_behavior()

    #get the mouse's position relative to the canvas
    mouse = cross_browser_relative_mouse_position(e)

    #select the object at the given position
    @selected = @find_object_at_position(mouse.x, mouse.y)

    #as we've now selected a different object, reset the text undo timer
    @reset_text_extry()

    #exit output entry mode
    @in_output_mode = false

    #if we don't have a currently selected object, create a new state at the current location
    if not @selected?
      @create_state_at_location(mouse.x, mouse.y)

    #otherwise, if we're clicking on a State
    else if @selected instanceof State
      @in_output_mode = true
    
    #draw the updated FSM
    @draw()

    #TODO: prevent text selection in chrome?


  #Handle keypresses on the FSM Designer.
  handle_keydown: (e) ->

    #get the keycode of the key that triggered this handler
    key = cross_browser_key(e)

    #if the user has just pressed the shift key, switch modes accordingly
    if key is FSMDesigner.KeyCodes.SHIFT
      @modalBehavior = FSMDesigner.ModalBehaviors.CREATE
      
    #if the designer doesn't have focus, then abort
    return unless @hasFocus()

    #if the key was the backspace key
    if key is FSMDesigner.KeyCodes.BACKSPACE

      #save an undo step, if necessary
      @save_text_undo_step()

      #handle the backspace key for the selecetd item
      @handle_backspace()

      #update the position of the caret, and re-draw
      @reset_caret()
      @draw()

      #return false, indicating that the browser should not perform the normal
      #"back" action
      return false

    #if the user has pressed delete, deleted the selected object
    if key is FSMDesigner.KeyCodes.DELETE
      @delete_object(@selected)

  #
  #Handle key-press events- which are composed of both a key-down and a key-up.
  #
  handle_keypress: (e) ->
    
    #if this designer doesn't have focus, ignore the keypress
    return unless @has_focus()

    #get the keycode of the key that triggered this event
    key = cross_browser_key(e)

    #if we have a printable key, handle text entry
    if FSMDesigner.keypress_is_printable(e) 
      @handle_text_entry(key)
      return false

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
    key = cross_browser_key(e)

    #if the event was the shift key being released, switch back to normal "pointer" mode
    if key is FSMDesigner.KeyCodes.SHIFT
      @modalBehavior = FSMDesigner.ModalBehaviors.POINTER

  #
  # Handle mouse-down ("click") events.
  #
  handle_mousedown: (e) ->

    #if there's a dialog open, ignore mouse clicks
    return if @dialog_open

    #get the mouse position, relative to the canvas
    mouse = cross_browser_relative_mouse_position(e)

    #reset the current modal flags:
    @moving_object = false
    @in_output_mode = false
    @original_click = false
    @reset_text_extry()

    #find an object at the given position, if one exists
    @selected = @find_object_at_position(mouse.x, mouse.y)

    #if we've just selected an object
    if @selected?

      #if we've selected a state, and we're in transition creation mode, create a new self-link
      if @modal_behavior is FSMDesigner.ModalBehaviors.CREATE and @selected instanceof State
        @current_transition = new SelfTransition(@selected, mouse, @)

      #otherwise, if we're in pointer mode, move into "object movement" mode
      else if @modal_behavior is FSMDesigner.ModalBehaviors.POINTER
        @start_moving_selected()

      #otherwise, create a new temporary reset-arc which both starts and ends at the current location
      else if @modal_behavior is FSMDesigner.ModalBehaviors.CREATE
        @current_transition = TemporaryTransition(mouse, mouse)

      #re-draw the modified FSM
      @draw()

      #if the canvas is focused, prevent mouse events from propagating
      #(this prevents drag-and-drop from moving us to another window)
      return false if @hasFocus()

      #reset the caret, and allow events to propagate
      @reset_caret()
      return true


  #
  # Handle mouse movement events.
  #
  handle_mousemove: (e) ->

    #ignore mouse movements when a dialog is open
    return if @dialog_open

    #get the position of the mouse, relative to the canvas
    mouse = cross_browser_relative_mouse_position(e)

    #if we're in the middle of creating a transition, render a visual cue indicating the
    #transition to be created
    if @current_transition?
      @create_transition_cue(mouse)

    #if we're in the middle of moving an object, handle its movement
    if @moving_object?
      @handle_object_move(move)


  #
  # Handles movement of the currently selected object.
  #
  handle_object_move: (mouse) ->

    #perform the actual move
    @selected.move_to(mouse.x, mouse.y)

    #if this is a state, handle "snapping", if necessary
    if @selected instanceof State
      @handle_state_snap()

    #re-draw the active FSM
    @draw()
 
  #
  # Handles automatic alignment of states.
  #
  handle_state_snap: ->

    #for each state in the FSM
    for state in states
      
      #never try to snap a state to itself
      continue if state is @selected

      #get the distance between the selected object and the given state
      distance = state.distance_from(@selected)

      #if the selected object is close enough to the given state,
      #align it horizontally with the given state
      if(Math.abs(distance.x) < @snap_to_padding)
        @selected.x = state.x

      #if the selected object is close enough to the given state,
      #align it vertically with the given state
      if(Math.abs(distance.y) < @snap_to_padding)
        @selected.y = state.yu




  #
  # Handles node-based text entry.
  #
  handle_text_entry: (key) ->

    #if we don't have a selected object, abort
    return unless @selected?

    #save an undo step, if needed
    @save_text_undo_step()

    #if we're in output mode, and the currently selected object exists and has an output property,
    #append the key to the output expression
    if @in_output_mode and @selected.outputs?
      @selected.outputs += String.fromCharCode(key)

    #otherwise, append the key to the output
    else 
      @selected.text += String.fromCharCode(key)

    #reset the designer's caret position, and re-draw
    @reset_caret()
    @draw()

  #TODO: re-write
  hasFocus: ->
    return false if document.getElementById('helppanel').style.visibility is 'visible'
    return document.activeElement or document.body is document.body
  

  #
  #Returns true iff the given key represents a printable character
  #
  @keypress_is_printable: (e) ->
    
    #return true iff the key is in the alpha-numeric range, and none of the modifiers are pressed
    key = cross_browser_key(e)
    key >= 0x20 and key <= 0x7E and not e.metaKey and not e.altKey and not e.ctrlKey

  #
  #Returns true iff the given keypress should trigger a redo event.
  #
  @keypress_represents_redo: (e) ->

    #get the keycode for the key that was pressed
    key = cross_browser_key(e)
    
    #return true iff one of our accepted redo combinations is present
    (key is FSMDesigner.KeyCodes.Y and e.ctrlKey) or                  #pure CTRL+Y
      (key is FSMDesigner.KeyCodes.REDO) or                           #WebKit's interpretation of CTRL+Y
      (key is FSMDesigner.KeyCodes.z and e.ctrlKey && e.shiftKey) or  #pure Shift+Ctrl+Z
      (key is FSMDesigner.KeyCodes.UNDO && e.shiftKey)                #WebKit's interpretation of CTRL+Z, plus shift


  #
  #Returns true iff the given keypress should trigger an undo event
  #
  @keypress_represents_undo: (e) ->

    #get the keycode for the key that was pressed
    key = cross_browser_key(e)

    #return true iff one our accepted undo combinations is present
    (key is FSMDesigner.KeyCodes.z and e.ctrlKey and not e.shiftKey) or #pure CTRL+Z (but not CTRL+Shift+Z)
      (key is FSMDesigner.KeyCodes.UNDO and not e.shiftKey)             #WebKit's interpretation of CTRL+Z (but not CTRL+Shift+Z)


  #Loads a file from an HTML5 file object
  load_from_file: (file) ->

    #save an undo-step right 
    @save_undo_step()

    #create a new File Reader, and instruct it to
    #1) read the file's contents, and 
    #2) pass the result to @recreate_state
    reader = new FileReader()
    reader.onload = (file) -> @unserialize(file.target.result)
    reader.readAsText(file)


  #Re-do the most recently undone action.
  redo: ->
    #if there's nothing on the redo stack, abort
    return if @redo_stack.length == 0
    
    #otherwise, re-do the most recently undone action
    @save_undo_step()
    @recreate_state(@redo_stack.pop())
    @draw()

  #
  # Creates a new FSMDesigner from a dehydrated copy.
  # To replace the current FSMDesigner with the contents of a dehydrated copy, use
  # "replace_with_rehydrated".
  #
  @rehydrate: (dehydrated, canvas) ->

    #create a new FSMDesigner object
    designer = new FSMDesigner(canvas)

    #and replace its contents with a rehydrated copy of the original
    designer.replace_with_rehydrated(dehydrated)

    #return the newly created copy
    designer

  #
  # Re-creates a given state from a dehydrated copy.
  #
  rehydrate_state: (dehydrated) ->

    #create a new state object at the same location as the dehydrated state
    state = new State(dehydrated.x, dehydrated.y, this)

    #and set the appropriate properties
    state.is_accept_state = dehydrated.is_accept_state
    state.text = dehydrated.text
    state.outputs = dehydrated.outputs
    state.radius = dehydrated.radius

    #return the newly recreated state
    state

  #
  # Re-creates a given state from a dehydrated copy.
  #
  rehydrate_transition: (dehydrated) ->

    transition = null

    #recreate one of various transitions, depending on type
    switch dehydrated.type

      when 'SelfTransition', 'SelfLink'
        #Transitions a dehydrated with the _index_ of the state they connect to.
        #Convert that back into a state...
        state = @states[dehydrated.state or dehydrated.node]

        #... and use that to create the transition.
        transition = new SelfTransition(state, null, this)
        transition.anchor_angle = dehydrated.anchor_angle or dehydrated.anchorAngle
        transition.text = dehydrated.text
        
      when 'StartTransition', 'StartLink'
        #Transitions a dehydrated with the _index_ of the state they connect to.
        #Convert that back into a state...
        state = @states[dehydrated.state or dehydrated.node]

        #... and use that to create the transition.
        transition = new StartTransition(@states[state], null, this)
        transition.delta_x = dehydrated.delta_x or dehydrated.deltaX
        transition.delta_y = dehydrated.delta_y or dehydrated.deltaY
        transition.text = dehydrated.text

      when 'Transition', 'Link'
        #Transitions a dehydrated with the _index_ of the states they connect to.
        #Convert that back into a state...
        source = @states[dehydrated.source or dehydrated.nodeA]
        destination = @states[dehydrated.destination or dehydrated.nodeB]

        #... and use that to create the transition.
        transition = new Transition(source, destination, this)
        transition.parallel_part = dehydrated.parallel_part or dehydrated.parallelPart
        transition.perpendicular_part = dehydrated.perpendicular_part or dehydrated.perpendicularPart
        transition.text = dehydrated.text
        transition.line_angle_adjustment = dehydrated.line_angle_adjustment or dehydrated.lineAngleAdjust

    #return the newly re-created transition
    transition

  #
  # Replaces the current FSM designer with a re-creation ("rehydration") 
  # of a dehydrated state.
  #
  replace_with_rehydrated: (dehyrated) ->

    #Clear the existing FSM.
    @clear(true)

    #Allow the state to specify either the newer state/transition form, or the deprecated node/link form.
    states = dehydrated.states or dehydrated.nodes
    transitions = dehydrated.transitions or dehydrated.nodes

    #Restore each of the states and transitions:
    @states = (@rehydrate_state(s) for s in states)
    @transitions = (@rehydrate_transition(t) for t in transitions)

    #Draw the newly-reconstructed state.
    @draw()

  #
  # Resets text entry status; should be called when switching text entry fields.
  #
  reset_text_entry: ->

    #if a text-entry timeout exists, clear it
    if @text_entry_timeout?
      clearTimeout(@text_entry_timeout)
      @text_entry_timeout = null


  #Saves a FSM file using a Data URI.
  #This method is not preferred, but will be used if Flash cannot be found.
  save_file_data_uri: ->
    
    #get a serialization of the FSM's state, for saving
    content = @serialize()
    
    #convert it to a data URI
    uri_content = 'data:application/x-fsm,' + encodeURIComponent(content)
    
    #and ask the user's browser to download it
    document.location.href = uri_content


  #Saves an undo step; recording the designer's state before an undoable action.
  #Should be called before any non-trivial change.
  save_undo_step: ->

    #get a deep copy of the current state
    state = @get_state()

    #and get the most recent undo step
    last_state = @undo_stack[-1..]

    #if the new step makes no sigificant change, don't add it to the undo stack
    return if FSMDesigner.states_equivalent(state, last_state)

    #if we're about to exceed the undo history limit, 
    #get rid of the least recent undo
    if @undo_stack.length >= @undo_history_size
      @undo_stack.shift()

    #push the new snapshot undo the undo stack
    @undo_stack.push(state)

  #Saves a redo step; recoding the designer's state before an undo.
  save_redo_step: ->

    #if we're about to exceed the redo hitory limit, get read of the least recent redo
    if @redo_stack.length >= @redo_history_size
      @redo_stack.shift()

    #push the system's state onto the redo stack
    @redo_stack.push(@get_state)

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
  #Return a serialization of the FSMDesginer, appropriate for saving
  #
  serialize: ->
    JSON.stringify(@get_state()) 

  #
  # Put the deisgner into object movement mode.
  #
  start_moving_selected: ->

    #save an undo step before the change in movement 
    @save_undo_step()

    #enable movement mode
    @moving_object = true

    #set the initial distance from the click site to zeor
    @delta_mouse_x = @delta_mouse_y = 0

    #if the object supports it, notify it of the location from which it is
    #being moved
    @selected.set_mouse_start?(mouse.x, mouse.y)

    #reset the text-entry caret
    @reset_caret()

  #Performs an "undo", undoing the most recent user action.
  undo: ->

    #if there's nothing to undo, abort
    return if this.undo_stack.length == 0 

    #otherwise, save a redo step, undo the last change,
    #and redraw
    @save_redo_step()
    @recreate_state(@undo_stack.pop())
    @draw()


  #Return true if two "undo" states contain the same value.
  @states_equivalent: (a, b) ->
    JSON.stringify(a) == JSON.stringify(b)


class Transition

  constructor: (@source, @destination, @parent) ->

    @font = '16px "Inconsolata", monospace'
    @fg_color = 'black'
    @bg_color = 'white'
    @selected_color = 'blue'
    @text = ''
  
    #Value added to the text angle when the transition is a straight line.
    @line_angle_adjustment = 0

    #The default "shape" of the line.
    @parallel_part = 0.5
    @perpendicular_part = 0

    @snap_to_straight_padding = @parent.snap_to_padding

  #
  # Returns true iff the transition is connected to the given state.
  #
  connected_to: (state) ->
    @source is state or @destination is state

  get_deltas: ->
    #get the total displacement between the source and destination,
    #as a vector
    displacement =
      x: @destination.x - @source.x
      y: @destination.y - @source.y 
      scale: Math.sqrt(dx * dx + dy * dy)

    return displacement

  #
  # Returns an "anchor point" location for the given transition.
  # This is the location that is used for mouse-based movement of the transition.
  #
  get_location: ->

    #get the differences between the start and end points of this line
    d = @get_deltas()

    #and use those to compute this line's anchor point
    location =
      x: (@source.x + d.x * @parallel_part - d.y * @perpendicular_part / d.scale)
      y: (@source.y + d.y * @parallel_part + d.x * @perpendicular_part / d.scale)

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
  move_to: ->

    d = @get_deltas()

    #compute the two points in the ellipse given the new anchor point
    offset_x = x - @source.x
    offset_y = y - @source.y
    @parallel_part = (d.x * offset_x + d.y * offset_y) / (d.scale * d.scale)
    @perpendicular_part = (d.x * offset_y + d.y * offset_x) / d.scale

    #if this is almost straight
    if @is_accept_straight()
      @snap_to_straight()


  snap_to_straight: ->
      
    #determine which side of the line the text should be placed on, given the pre-snap angle of the state
    #this allows the user to easily move the text to above or below the line
    @line_angle_adjustment = (@perpendicular_part < 0) * Math.PI

    #and snap the line to straight
    @perpendicular_part = 0

















