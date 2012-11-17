###
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


  #Deletes the specified object.
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


  #Exports the currently designed FSM to a PNG image.
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

  find_object_at_position: (x, y) ->

    #first, look for a transition at the given position
    for transition in @transitions
      if transition.contains_point(x,y)
        return transition

    #next, check for a node at the given position
    for state in @states
      if state.contains_point(x, y)
        return state
    
    #if we didn't find either a matching link or node, return null
    null


  #Handle HTML5 file drop events; this allows the user to drag a file into the designer,
  #loading their FSM.
  handle_drop: (e) ->

    #prevent the browser from trying to load/display the file itself
    e.stopPropagation() 
    e.preventDefault()

    #if we haven't recieved exactly one file, abort
    return if e.dataTransfer.files.length != 1

    #load the recieved file
    @load_from_file(e.dataTransfer.files[0])


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


  #Saves a FSM file using a Data URI.
  #This method is not preferred, but will be used if Flash cannot be found.
  save_file_data_uri: ->
    
    #get a serialization of the FSM's state, for saving
    content = @serialize_state()
    
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



  #Return a serialization of the FSMDesginer, appropriate for saving
  serialize: ->
    JSON.stringify(@get_state()) 

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















