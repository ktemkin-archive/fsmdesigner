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

class CrossBrowserUtils

  @true_event: (e) ->
    e or window.event

  #
  # Finds the position of the element which triggered the given event.
  #
  @element_position: (e) ->

    #Find the true event object for the given event.
    e = CrossBrowserUtils.true_event()

    #find the element which triggered the event
    element = e.target or e.srcElement
    
    x = 0
    y = 0

    #While this object is relative to another object, attempt
    #to find the element's location _relative_ to that parent.
    #This will eventually find the element's position relative to the document-
    #its true, absolute position.
    while element.offsetParent
      x += element.offsetLeft
      y += element.offsetTop
      element = element.offsetParent

    position =
      x: x
      y: y

  #
  # Finds the position of the mouse pointer, at the time that an event _e_ is fired.
  #
  @mouse_position: (e) ->

    #Find the true event object for the given event.
    e = CrossBrowserUtils.true_event()

    #Find the mouse position via whichever method is supported:
    #- Directly, if provided, or
    #- Relative to the document.
    mouse_position =
      x: e.pageX or e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft
      y: e.pageY or e.clientY + document.body.scrollTop + document.documentElement.scrollTop

  @relative_mouse_position: (e) ->

    #Get the position of both the element and mouse...
    element = CrossBrowserUtils.element_position(e)
    mouse = CrossBrowserUtils.mouse_position(e)

    #And use them to find the relative position of the mouse pointer.
    relative_position =
      x: mouse.x - element.x
      y: mouse.y - element.y

  @key_code: (e) ->
    
    #Find the true event object for the given event.
    e = CrossBrowserUtils.true_event()

    #Return whichever of the two fields was populated.
    e.which or e.keyCode



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
  
  original_click: null
  caret_visible: true
  caret_time: 500
  selected: null # either a Link or a Node
  current_transition: null  #a Link
  moving_object: false
  in_output_mode: false #determines if we're in edit-output mode
  
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
      'mousemove':   (e) => @handle_mousemove(e)
      'mouseup':     (e) => @handle_mouseup(e)
      'mousedown':   (e) => @handle_mousedown(e)
      'dblclick':    (e) => @handle_doubleclick(e)
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

  @convert_latex_shorthand: (text) ->
    text #FIXME TODO #FIXME

  #
  # Creates a new state at the given x, y location.
  #
  create_state_at_location: (x, y, dont_draw=false) ->

    console.log "Creating state at #{x} #{y}!"

    #save the system's state before the creation of the new node
    @save_undo_step()

    #create a new state, and select it
    @selected = new State(x, y, @)

    #add the new state to our internal collection of states
    @states.push(@selected)

    #reset the text entry caret
    @reset_caret()

    #draw the FSM with the new state
    unless dont_draw
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
          if target_state is @selected new SelfTransition(@selected, @, mouse)

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
      radius: state.radius

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

    #XXX FIXME XXX
    @handle_resize()

    #use it to render the FSM
    @draw_using(context)

    #and autosave the FSM
    @autosave()

  #
  # Renders a string of text on the given canvas.
  #
  @draw_text: (context, text, x, y, is_selected, font, angle=null) ->

    #pre-process the text, converting latex shorthands into renderable text
    text = FSMDesigner.convert_latex_shorthand(text)

    #apply the font to the drawing context
    context.font = font

    #ask the rendering engine to compute the text's width, given the font
    text_size = context.measureText(text, font)

    #center the text, given the computed width
    x -= text_size.width / 2 

    #if an angle was provided, apply Evan Wallace's positioning hueristic
    if angle?
      cos = Math.cos(angle)
      sin = Math.sin(angle)
      corner_point_x = (text_size.width / 2 + 5) * (if cos > 0 then 1 else -1)
      corner_point_y = (10 + 5) * (if sin > 0 then 1 else -1)
      slide = sin * Math.pow(Math.abs(sin), 40) * corner_point_x - cos * Math.pow(Math.abs(cos), 10) * corner_point_y
      x += corner_point_x - sin * slide
      y += corner_point_y - cos * slide

    #round the text co-ordinates to the nearest pixel; this ensures that the caret always
    #falls aligned with a pixel, and thus always has the correct width of 1px
    x = Math.round(x)
    y = Math.round(y)

    #render the text
    context.fillText(text, x, y + 6)

    #if this is the selected object, render the caret
    if is_selected and @caret_visible and @hasFocus() and doucment.hasFocus()

      #draw the caret
      c.beginPath()
      c.moveTo(x + text_size.width, y - text_size.height / 2)
      c.lineTo(x + text_size.width, y + text_size.height / 2)
      c.stroke()
      

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
    #@handle_modal_behavior()

    #get the mouse's position relative to the canvas
    mouse = CrossBrowserUtils.relative_mouse_position(e)

    #select the object at the given position
    @selected = @find_object_at_position(mouse.x, mouse.y)

    #as we've now selected a different object, reset the text undo timer
    @reset_text_entry()

    #exit output entry mode
    @in_output_mode = false

    #if we don't have a currently selected object, create a new state at the current location
    if not @selected?
      console.log mouse
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
    key = CrossBrowserUtils.key_code(e)

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
    key = CrossBrowserUtils.key_code(e)

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
    key = CrossBrowserUtils.key_code(e)

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
    mouse = CrossBrowserUtils.relative_mouse_position(e)

    #reset the current modal flags:
    @moving_object = false
    @in_output_mode = false
    @original_click = false
    @reset_text_entry()

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
  handle_mouseup: (e) ->

    #ignore mouse releases when a dialog is open
    return if @dialog_open

    #since we've released the mouse, we're not longer moving an object
    @moving_object = false

    #If we're in the middle of creating a transition,
    if @current_transition?

      #and that transition is a placeholder, convert it to a normal link
      if not @current_transition instanceof TransitionPlaceholder

        #save an undo point
        @save_undo_step()

        #select the newly-created object
        @selected = @current_link

        #Since we've switched to a new object, reset text entry.
        @rndeset_text_entry()

        #add the given link to the FSM
        @transitions.push(@current_link)

        #reset the caret
        @reset_caret()

    @current_transition = null
    @draw()



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
    key = CrossBrowserUtils.key_code(e)
    key >= 0x20 and key <= 0x7E and not e.metaKey and not e.altKey and not e.ctrlKey

  #
  #Returns true iff the given keypress should trigger a redo event.
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
  #Returns true iff the given keypress should trigger an undo event
  #
  @keypress_represents_undo: (e) ->

    #get the keycode for the key that was pressed
    key = CrossBrowserUtils.key_code(e)

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

  #
  # Resets the state of the text-entry caret for this FSMDesigner.
  #
  reset_caret: ->

    #Cancel any existing caret-creation interval...
    clearInterval(@caret_timer)

    #... and request that the caret toggle, when appropriate.
    @caret_timer = setInterval((=> @toggle_caret()), @caret_time)

    #Ensure the caret starts off visible.
    @caret_visible = true

  #
  # Handles resizing of the parent window
  # Automatically rescales the canvas's context to match the new size of the canvas.
  #
  handle_resize: ->
  
    #get the canvas's 2D drawing "context"
    context = @canvas.getContext('2d')

    #TODO: ABSTRACT ME AWAAAAY
    context.canvas.width = window.innerWidth
    context.canvas.height = window.innerHeight - document.getElementById("toolbar").offsetHeight
    context.canvas.style.width = window.innerWidth + 'px'
    context.canvas.style.height = (window.innerHeight - document.getElementById('toolbar').offsetHeight) + 'px'

  #
  #Saves a FSM file using a Data URI.
  #This method is not preferred, but will be used if Flash cannot be found.
  #
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
    state = @dehydrate()

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
    @redo_stack.push(@dehydrate())

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
    JSON.stringify(@dehydrate()) 

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

  #
  # Toggles the visibility of the caret.
  #
  toggle_caret: ->
    @caret_visible = not @caret_visible
    @draw()

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

#
# Represents a generic FSM state transition.
#
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
  # Applies the appropriate colors to the context object
  # according to the transition's state.
  #
  apply_transition_color: (context) ->

    #if the arc is selected, apply the selected color
    if @parent.selected is this
      context.fillStyle = context.strokeStyle = @selected_color

    #otherwise, apply the foreground color
    else
      context.fillStyle = context.strokeStyle = @fg_color


  #
  # Returns true iff the transition is connected to the given state.
  #
  connected_to: (state) ->
    @source is state or @destination is state


  contains_point: (x, y) ->
    @get_path().contains_point(x, y)

    

  #
  # Draws an arrow using the active color
  # on the provided context.
  #
  @draw_arrow: (context, x, y, angle) ->

    #compute the x and y portions of the arrow
    dx = Math.cos(angle)
    dy = Math.sin(angle)

    #draw the arrowhead
    #TODO: These magic numbers are what worked for Evan Wallace.
    #Abstract them away!
    context.beginPath()
    context.moveTo(x, y)
    context.lineTo(x - 8 * dx + 5 * dy, y - 8 * dy - 5 * dx)
    context.lineTo(x - 8 * dx - 5 * dy, y - 8 * dy + 5 * dx)
    context.fill()

  #
  # Renders the given transition, using the provided context.
  #
  draw_using: (context) ->

    #set the transition color according to its state
    @apply_transition_color(context)

    #get a path object that represent the path of this transtion, 
    #and request that it draw itself
    @get_path().draw_using(context, @text, @font, @is_selected())
    

  #
  # Returns the total displacement between the source and destination states,
  # as a vector.
  #
  get_deltas: ->
    #get the total displacement between the source and destination,
    #as a vector
    displacement =
      x: @destination.x - @source.x
      y: @destination.y - @source.y 
      scale: Math.sqrt(dx * dx + dy * dy)

    return displacement

  #
  # Returns the end-points for the given FSM state.
  #
  get_path: ->

    #If the line is straight, get the endpoints using the simple computation
    if @perpendiclar_part == 0
      @get_path_straight_line()

    #otherwise, account for the line's curvature
    else
      @get_path_curved_line()


  #
  # Get the endpoints that the transition would have if it were curved.
  #
  get_path_curved_line: ->

      #create a circle which connects the source state, the destination state, and the "anchor" point selected by the user
      anchor = @get_location()
      circle = circle_from_three_points(@source.x, @source.y, @destination.x, @destination.y, anchor.x, anchor.y)

      #if the line follows the lower half of the relevant ellipse, consider it reversed, and adjust the sign of the expressions below accordingly
      reversed = @perpendiclar_part > 0
      reverse_scale = if reversed then 1 else -1
     
      #compute the angle at which the line leaves its source, and enters its destination
      start_angle = Math.atan2(@source.y - circle.y, @source.x - circle.x) - reverse_scale * @source.radius / circle.radius
      end_angle = Math.atan2(@destination.y - circle.y, @destination.x - circle.x) - reverse_scale * @destination.radius / circle.radius

      #use that angle to compute the point at which the transition attaches to the source state
      start =
        x: circle.x + circle.radius * Math.cos(start_angle)
        y: circle.y + circle.radius * Math.cos(start_angle)
        angle: start_angle

      #and do the same for its destination
      end =
        x: circle.x + circle.radius * Math.cos(end_angle)
        y: circle.y + circle.radius * Math.cos(end_angle)
        angle: end_angle

      #return a new curved path object
      new CurvedPath(start, end, circle, reversed)


  #
  # Gets the endpoints that the transition would have if it were a straight line.
  #
  get_path_straight_line: ->

      #compute the middle points of the ellipse
      midX = (@source.x + @destination.y) / 2
      midY = (@source.y + @destination.y) / 2

      #and find the closest point on the source and destination nodes
      start = @source.closest_point_on_circle(midX, midY)
      end = @destination.closest_point_on_circle(midX, midY)

      #return a new StraightPath object
      new StraightPath(start, end)

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
  # Returns true iff this object is selected.
  #
  is_selected: =>
    @parent.selected is this

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

    #if this is almost straight, snap to straight
    if @is_almost_straight()
      @snap_to_straight()

  #
  # Snaps the straight line to straight.
  #
  snap_to_straight: ->
      
    #determine which side of the line the text should be placed on, given the pre-snap angle of the state
    #this allows the user to easily move the text to above or below the line
    @line_angle_adjustment = (@perpendicular_part < 0) * Math.PI

    #and snap the line to straight
    @perpendicular_part = 0


#
# Special case "self-loop" transition, which represents a condition under which the FSM remains in the same state.
#
class SelfTransition extends Transition

  constructor: (source, parent, created_at=null) ->

    #create the basic transition from this object
    super(source, source, parent)

    #Default radius for this transition, as a proportion of the owning node's radius.
    @scale = 0.75

    #Default drawn circumference for this circle, as a proportion of the circumference 
    #of the circle this transition is curved around.
    @circumference_stroke = 0.8

    #Determine the maximum offset angle which should be considered aligned to a "right" angle.
    @snap_to_right_angle_radians = 0.1

    #Initially, assume that the self-loop is attached directly above the given state.
    @anchor_angle = 0

    #?
    @mouse_offset_angle = 0

    #If we have information about the point at which this node was created,
    #use it to set the arc's location.
    if created_at?
      @move_to(created_at.x, created_at.y)

 
    #
    # Move the self-loop to the position closest to the given x, y coordinates.
    #
    move_to:  (x, y) ->

      #find the difference between the center of the origin node
      #and the given point
      dx = x - @source.x
      dy = y - @source.y

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
      @angle = angle

    #
    # Returns the path that best renders the given transition.
    #
    get_path: ->

      #Get the diameter scale, which is equal to twice the scale used to determine the radius.
      diameter_scale = @scale * 2

      #Determine the location and radius for the loop's rendering circle.
      circle =
        x: @source.x + @diameter_scale * @source.radius * Math.cos(@anchor_angle)
        y: @source.y + @diameter_scale * @source.radius * Math.sin(@anchor_angle)
        radius: @scale * @source.radius

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


#
# Represents a "reset transition", which enters a state from the "background".
#
class ResetTransition extends Transition

  #
  # Creates a new reset-transition.
  #
  constructor: (destination, parent, position=null) ->

    #Create a transition which has no source, but has a known destination.
    super(null, destination, parent)

    #Assume an origin of zero, unless otherwise specified.
    #Note that origin is _relative_ to the destination state- this allows reset nodes
    #to move with their target state.
    @origin = 
      x: 0 
      y: 0

    #If we know the starting position, anchor this transition there.
    if position?
      @anchor_at(position.x, position.y)

  #
  # Anchors the transition at the given point.
  #
  anchor_at: (x, y) ->

    #Compute the offset relative to the target node.
    @origin.x = x - @destination.x
    @origin.y = y - @destination.y

    #TODO: handle snap?
  
  get_path: ->

    #Compute the start point for the given transition by
    #applying the origin offset.
    start = 
      x: @destination.x + @origin.x
      y: @destination.y + @origin.y

    #And find the end point by finding the closest point
    #on the target state.
    end = @destination.closest_point_on_circle(start.x, start.y)

    #Create a new straight path from the origin to the node.
    new StraightPath(start, end)

class TransitionPlaceholder

  constructor: (@start, @end) ->

  #
  # A transition placeholder is always composed of a straight path from the start to the end.
  #
  get_path: ->
    new StraightPath(start, end)

  #
  # Renders the transition placeholder.
  # 
  draw_using: (context) ->
    @get_path().draw_using(context)


#
# Low-level representation of an arrow's path.
# Used for rendering of state transitions.
#
class StraightPath

  #
  # Creates a new straight path, used to indicate the visible "path" of a transition.
  #
  constructor: (@start, @end) ->

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
  draw_using: (context, text=null, font=null, is_selected = false) ->

    #draw the basic straight line
    context.beginPath()
    context.moveTo(@start.x, @start.y)
    context.lineTo(@end.x, @end.y)
    context.stroke()

    #draw the head of the arrow on the end of the line
    Transition.draw_arrow(context, @end.x, @end.y, @get_arrow_angle()) 

    #If no text was provided, return.
    return unless text?

    #compute the position of the arrow's transition condition
    text_location =
      x: (@start.x + @end.x) / 2
      y: (@start.y + @end.y) / 2
      angle: Math.atan2(@end.x - @start.x, @start.y - @end.y)

    #and render the text
    FSMDesigner.drawText(context, text, text_location.x, text_location.y, is_selected, font, text_location.angle)

  #
  # Compute the angle for the arrowhead at the end of this path.
  #
  get_arrow_angle: ->
    arrow_angle = Math.atan2(@end.y - @start.x, @end.x - @start.y)



class CurvedPath

  constructor: (@start, @end, @circle, @reversed) ->

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
      angle = Math.atan(dx, dy)
     
      #if the line is reversed, switch the start and end angles
      if @reversed
        start_angle = @end.angle
        end_angle = @start.angle

      #otherwise, use them directly
      else
        start_angle = @start.angle
        end_angle = @end.angle

      #if the end angle is less than the start angle, normalize it by adding 360 degrees
      if end_angle < start_angle
        end_angle += Math.PI * 2

      #if the angle is less than the start angle, normalize it by adding 360 degrees
      if angle < start_angle
        angle += Math.PI * 2

      #if the angle less than the end angle, normalize it by adding 360
      else if angle > end_angle
        angle -= Math.PI * 2

      #if the angle is between the start and end angle, it's a match
      return angle > start_angle and angle < end_angle

  #
  # Renders the given transition as a curved line across
  # the provided path.
  #
  draw_using: (context, text, font, is_selected = false) ->

    #draw the core arc that makes up the transition line
    context.beginPath()
    context.arc(@circle.x, @circle.y, @circle.radius, @start.angle, @end.angle, @reversed)
    context.stroke()

    #draw the head of the arrow
    Transition.draw_arrow(context, @end.x, @end.y, @get_arrow_angle())
  
    #draw the transition condition text
  
    #if the start angle is less than the end angle, place the text on the opposite side of the line
    if @start.angle < @end.angle
      end_angle = @end.angle + Math.PI / 2
    else
      end_angle = @end.angle

    #compute the angle at which the text should be rendered, relative to the line
    text_angle = (@start.angle + end_angle) / 2 + (@reversed * Math.PI)

    #and convert that into an x/y position for the center of the text
    text_location =
      x: @circle.X + @circle.radius * Math.cos(text_angle)
      y: @circle.X + @circle.radius * Math.sin(text_angle)
      angle: text_angle

    #finally, draw the text
    FSMDesigner.drawText(context, text, text_location.x, text_location.y, is_selected, font,  text_location.angle)

  #
  # Compute the angle for the arrowhead at the end of this path.
  #
  get_arrow_angle: ->
    @end.angle - if @reversed then -1 * (Math.PI / 2) else (Math.PI / 2)


#
# Represents a generic circular path, such as the path which could be used to generate a self-loop.
#
class CircularPath

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
    distance >= (radius - tolerance) and distance <= (radius + tolerance)

  #
  # Renders the given transition as a circle across the provided path.
  #
  draw_using: (context, text, font, is_selected = false) ->

    #Draw the core circle that makes up the transition line.
    context.beginPath()
    context.arc(@circle.x, @circle.y, @circle.radius, @start.angle, @end.angle, false)
    context.stroke()

    #Draw the head of the arrow.
    Transition.draw_arrow(context, @end.x, @end.y, @end.angle + Math.PI * @stroke_circumference / 2)

    #Find the furthest point from the state...
    text_location =
      x: @circle.x + @circle.radius * Math.cos(@anchor_angle)
      y: @circle.y + @circle.radius * Math.sin(@anchor_angle)

    #... and render the text, there.
    FSMDesigner.drawText(context, text, text_location.x, text_location.y, @anchor_angle, font, is_selected)


class State

  constructor: (@x, @y, @parent) ->

    #Default values for a new state.
    #(Abstract these somewhere else for easy config?)
    
    #Node radius, in pixels.
    @radius = 55
    @accept_radius = 50

    #Node outline, in pixels.
    @outline = 2

    #Node foreground, background, and "selected" colors, as accepted by CSS.
    @fg_color = 'black'
    @bg_color = 'white'
    @selected_color = 'blue'

    #Node font, as accepted by CSS.
    @font = '16px "Droid Sans", sans-serif'

    #Output padding, font, and color.
    @output_padding = 14
    @output_font = '20px "Inconsolata", monospace'
    @output_color = '#101010'
    
    #Set the "grab point", which is the internal point at
    #which the node is being grabbed. Used for mouse-based movement.
    @grab_point =
      x: 0
      y: 0

    @is_accept_state = false

    #Node label, and output value.
    @text = ''
    @outputs = ''

  #
  # 
  #
  closest_point_on_circle: (x, y) ->

    #Create a triangle with three legs:
    #-A hypotenuse, which connects the given point to the center of the circle, and
    #-Two legs, which represent the X and Y components of the hypotenuse. 
    dx = x - @x
    dy = y - @y
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
      x: @x + x_leg
      y: @y + y_leg

    #And return that point.
    return point

  #
  # Returns true iff the given point exists within the node's circle.
  #
  contains_point: (x, y, tolerance = 0) ->
    
    #compute the distances between the x/y coordinates
    dx = x - @x
    dy = y - @y

    #square each of the distances, and add them to find the length of the hypotenuse ("distance from the center")-squared
    #(note that this implicitly finds the absolute value of the distance)
    distance = (dx * dx) + (dy * dy)

    #Return true iff the gien point is within the circle's radius.
    #(It's distance from the center squared is less than the radius squared).
    distance <= (@radius + tolerance) * (@radius + tolerance)


  #
  # Draws the given node using the provided context.
  #
  draw_using: (context) ->

    #set up the brush which will be used to draw the state
    context.lineWidth = @outline
    context.fillStyle = @bg_color
    context.strokeStyle = @get_fg_color()

    #create the state's circle
    context.beginPath()
    context.arc(@x, @y, @radius, 0, Math.PI * 2, false)
    context.fill()
    context.stroke()

    #if this is an accept state, draw a second circle
    if @is_accept_state
      context.beginPath()
      context.arc(@x, @y, @accept_radius, Math.PI * 2, false)
      context.stroke()

    #add the state's name
    context.fillStyle = @get_fg_color()
    FSMDesigner.draw_text(context, @text, @x, @y, @selected and not @in_output_mode, @font)

    #draw the state's moore outputs
    context.fillStyle = @get_fg_color(true)
    output_y = @y + @radius + @output_padding
    FSMDesigner.draw_text(context, @outputs, @x, output_y, @selected and @in_output_mode, @output_font)




  #
  # Returns the color with which this state should be drawn,
  # accounting for modifiers (e.g. selected).
  #
  get_fg_color: (is_output=false) ->
    
    #If we're in output mode, and this is an output, then use the "selected" FG color.
    if @selected() and @in_output_mode and is_output
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
  move_to: (x, y) ->
    #TODO: pull away the mouse offset!
    @x = x 
    @y = y

  #
  # Move the given state to the given X, Y coordinates,
  # accounting for the point at which the state was "grabbed".
  #
  move_with_offset: (x, y) ->
    @x = x + @grab_point.x
    @y = y + @grab_point.y


  #
  # Returns true iff the current object is selected.
  #
  selected: ->
    @parent.selected is this

  #
  # Sets the mouse offset, which identifies 
  #
  set_mouse_start: (x, y) ->
    @grab_point =
      x: @x - x
      y: @y - y


#
# Export the necessary pieces of this library.
#
window.FSMDesigner = FSMDesigner


