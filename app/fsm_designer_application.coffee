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

{FSMDesigner} = require 'lib/fsm_designer'

class exports.FSMDesignerApplication

  #
  # Perform the core JS start-up, once the window is ready.
  #
  constructor: (@canvas, @text_field, @toolbar, @file_form=null) ->
  
    # Create a basic data-store for the persistant features, like autosaving.
    @datastore = new Persist.Store('FSMDesigner', {swf_path: 'flash/persist.swf'})

    # Simple event handlers for the FSMDesigner, which handle autosave.
    @designer_event_handlers =
      redraw: @handle_redraw
      resize: @handle_resize

    # Sets up the local toolbar events.
    @set_up_toolbar()

    # Set up the "load file in place" event, which should trigger 
    # when a file is selected to be opened via the HTML5 file dialog.
    document.getElementById('fileOpen').onchange = @handle_file_selection
    document.getElementById('cancelOpen').addEventListener('click', @handle_cancel_open_click) 

    # Innitially, don't process any UI event.
    @active_ui_event = null

    # If we haven't seen this user before, show the help panel.
    @show_help() unless @datastore.get('seen')

  #
  # Sets up the handlers for all of the toolbar buttons.
  #
  set_up_toolbar: ->

    button_handlers =
      'btnNew':         @handle_new_click
      'btnUndo':        @handle_undo_click
      'btnRedo':        @handle_redo_click
      'btnOpen':        @handle_open_click
      'btnSaveHTML5':   @handle_save_html5_click
      'btnSavePNG':     @handle_save_png_click
      'btnHelp':        @handle_help_click
      'btnDismissHelp': @handle_dismiss_help_click

    # Add each of the button handlers to their respective buttons.
    for id, handler of button_handlers
      document.getElementById(id).addEventListener('click', handler)
  
    # Create the flash-based download button, if Flash is supported.
    @set_up_download_button()


  #
  # Set up a better download experience, on systems that support Flash.
  # (The HTML5 download API doesn't allow a save dialog.)
  # 
  set_up_download_button: ->

    #Get a reference to the HTML5 save button we want to replace.
    download_button = document.getElementById('btnSaveHTML5')

    # If supported, create a better download button using Downloadify.
    downloadify_options = 
      swf: 'flash/downloadify.swf'
      downloadImage: 'images/download.gif'
      width: download_button.offsetWidth
      height: download_button.offsetHeight
      append: true
      transparent: true
      filename: 'FiniteStateMachine.fsmd'
      data: => @designer.serialize()
    Downloadify.create('btnSave', downloadify_options)

  #
  # Show the help panel.
  #
  show_help: ->

    # Show the help panel...
    helpPanel = document.getElementById('helpPanel')
    @set_element_opacity(helpPanel, 1)

    # ... and mark it as seen.
    @datastore.set('seen', true)



  #
  # Start the Application.
  #
  run: =>
    # Attempt to fetch data regarding the last design, if it exists.
    last_design = @datastore.get('autosave')
        
    # If we were able to get a last design, re-create the FSM designer from the last serialized input.
    if last_design?
      @designer = FSMDesigner.unserialize(last_design, text_field, canvas, window, @designer_event_handlers)
    else
      @designer = new FSMDesigner(canvas, text_field,  window, @designer_event_handlers)

  #
  # Handles redraw events. Redraws are queued periodically,
  # and on the event of a change; so they make a good time to autosave.
  #
  handle_redraw: (designer) =>

    # Ensure this function isn't called until the deisgner has fully loaded.
    return if not @designer?

    # Auto-save the current FSM.
    @datastore.set('autosave', @designer.serialize())

    # Ensure the undo/redo buttons accurately reflect whether the user can undo and redo.
    document.getElementById('btnUndo').disabled = not @designer.can_undo()
    document.getElementById('btnRedo').disabled = not @designer.can_redo()


  #
  # Handles resizing of the owning window.
  #
  handle_resize: (canvas) =>
  
    # Resize the canvas' internal rendering sizes....
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight - @toolbar.offsetHeight - @toolbar.offsetTop
  
    # ... and ensure the canvas matches those sizes.
    canvas.style.width = canvas.width + 'px'
    canvas.style.height = canvas.height + 'px'

  
  #
  # Handles a click on the new button.
  #
  handle_new_click: =>
    @designer.clear()


  #
  # Handles a click of the undo button.
  #
  handle_undo_click: =>
    @designer.undo()


  #
  # Handles a click of the redo button.
  #
  handle_redo_click: =>
      @designer.redo()


  #
  # Handles the "Save" button; saves a FSM file using a Data URI.
  # This method is not preferred, but will be used if Flash cannot be found.
  #
  handle_save_html5_click: =>
    
    #get a serialization of the FSM's state, for saving
    content = @designer.serialize()
    
    #convert it to a data URI
    uri_content = 'data:application/x-fsm,' + encodeURIComponent(content)
    
    #and ask the user's browser to download it
    document.location.href = uri_content

  handle_save_png_click: =>
    @designer.export_png()


  #
  # Handles clicks of the "open" toolbar button.
  #
  handle_open_click: =>

    # If we have access to the HTML5 file api
    if FileReader?
      document.getElementById('fileOpen').click()
    else
      @show_file_open_fallback()

  #
  # Fallback to server-side file opening, as the current browser
  # doesn't support it.
  #
  show_file_open_fallback: ->
    @set_element_opacity(@file_form, .95)

  #
  # Sets the file dialog's opacity.
  #
  set_element_opacity: (element, value, autohide=true) ->
    return unless element?

    # Set the opacity of the file dialog...
    element.style.opacity = value 
    element.style.filter  = "alpha(opacity=#{value * 100})"

    #If autohide is on, hide the form if it's not visible.
    #(This prevent it from being made interactable)
    return unless autohide

    @schedule_ui_event =>
      element.style.display = if value > 0 then 'block' else 'none'

  #
  # Handles cancellation of the file open dialog.
  #
  handle_cancel_open_click: (e) =>
    @set_element_opacity(@file_form, 0)


  #
  # Handle clicks on the "help" button.
  #
  handle_help_click: (e) =>
    helpPanel = document.getElementById('helpPanel')
    @set_element_opacity(helpPanel, 1)


  #
  # Handles clicks on the "dismiss help" button.
  #
  handle_dismiss_help_click: (e) =>
    helpPanel = document.getElementById('helpPanel')
    @set_element_opacity(helpPanel, 0)

  #
  # Schedule a UI event, displacing any 
  #
  schedule_ui_event: (event, timeout=100) =>
    clearTimeout(@active_ui_event) if @active_ui_event?
    setTimeout(event, timeout)

  
  #
  # Handle selection of a file in 
  # 
  handle_file_selection: (e) =>

    # If we don't have the HTML5 file api, don't handle this event.
    return unless FileReader?

    # Return unless the user has selected exactly one file.
    return unless e?.target?.files?.length == 1

    # Open the relevant file.
    @designer.load_from_file(e.target.files[0])

