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
  constructor: (@canvas, @text_field, @input_stats, @toolbar, @file_form=null) ->
  
    # Create a basic data-store for the persistant features, like autosaving.
    @datastore = new Persist.Store('FSMDesigner', {swf_path: 'flash/persist.swf'})

    # Simple event handlers for the FSMDesigner, which handle autosave.
    @designer_event_handlers =
      redraw: @handle_redraw
      resize: @handle_resize
      name_changed: @handle_name_change

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
      'btnVHDLHTML5':   @handle_vhdl_export_html5_click
      'btnHelp':        @handle_help_click
      'btnDismissHelp': @handle_dismiss_help_click

    # Add each of the button handlers to their respective buttons.
    for id, handler of button_handlers
      document.getElementById(id).addEventListener('click', handler)

    # Listen for changes to the design name.
    document.getElementById('designName').addEventListener('change', @handle_name_field_change)
  
    # Create the flash-based download buttons, if Flash is supported.
    @set_up_download_button()
    @set_up_vhdl_export_button()


  #
  # Set up a better download experience, on systems that support Flash.
  # (The HTML5 download API doesn't allow a save dialog.)
  # 
  set_up_download_button: ->
    @_replace_button_with_downloadify('btnSaveHTML5', 'btnSave', => @designer.serialize())


  #
  # Set up a better VHDL export experience, on systems that support Flash.
  # (The HTML5 download API doesn't allow a save dialog.)
  # 
  set_up_vhdl_export_button: ->
    
    #Replace the core VHDL export button... 
    @_replace_button_with_downloadify('btnVHDLHTML5', 'btnVHDL', (=> @designer.to_VHDL(@get_design_filename())), 'vhd')

    #Add events on mouse-in and mouse-out, which will show and hide the error bar.
    export_area = document.getElementById('btnVHDL')
    export_area.addEventListener('mouseover', => @show_error_bar(@designer.error_message())) #TODO: Provide error message!
    export_area.addEventListener('mouseout', => @show_error_bar(false))

  
  #
  # Shows (or hides) the error bar.
  #
  # message: If a valid string message is provided, it will be displayed on the error bar;
  #          if the message is falsey, the error bar will be hidden.
  #
  show_error_bar: (message) ->

    #If we have a message to apply, apply it.
    if message
      document.getElementById('error_message').innerHTML = message 

    #Show or hide the error bar, as appropriate.
    error_bar = document.getElementById('error_bar')
    @set_element_opacity(error_bar, if message then 1 else 0)


  #
  # Replaces a given HTML5 download button with a Downloadify instance.
  # This allows for more dynamic saving using Flash's save dialog.
  #
  _replace_button_with_downloadify: (element_to_replace, target_element, generator_function, extension='fsmd')->

    #Get a reference to the HTML5 save button we want to replace.
    download_button = document.getElementById(element_to_replace)

    # If supported, create a better download button using Downloadify.
    downloadify_options = 
      swf: 'flash/downloadify.swf'
      downloadImage: 'images/download.gif'
      width: download_button.offsetWidth
      height: download_button.offsetHeight
      append: true
      transparent: true
      filename: => "#{@get_design_filename()}.#{extension}"
      data: => generator_function()
    Downloadify.create(target_element, downloadify_options)


  #
  # Returns the active design's name.
  #
  get_design_name: ->
    @designer.get_name()


  #
  # Sets the active design's name, both in terms of the UI and the FSMDesigner.
  #
  set_design_name: (name) =>

    #Set the designer name field...
    @_set_design_name_field(name)

    #...and pass the new name to the designer.
    @designer.set_name(name)


  #
  # Internal method to set the "design name" field's value.
  #
  _set_design_name_field: (name) ->
    document.getElementById('designName').value = name


  #
  # Returns an appropriate filename for the active design.
  # TODO: Handle completely invalid names.
  #
  get_design_filename: =>
    @get_design_name().replace(/\s/g, '_').replace(/[^A-Za-z0-9_]/g, '')


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
      @designer = FSMDesigner.unserialize(last_design, @text_field, @canvas, @input_stats, window, @designer_event_handlers)
    else
      @designer = new FSMDesigner(@canvas, @text_field, @input_stats, window, @designer_event_handlers, null, @get_design_name())


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

    # Ensure that the export button is only available for valid designs.
    document.getElementById('btnVHDLHTML5').disabled = not @designer.is_valid()
    @_add_or_remove_class(document.getElementById('btnVHDLHTML5'), 'nonempty', not @designer.empty())


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
  # Handles a change in the FSMDesigner's name,
  # ensuring that the FSMDesigner "design name" field is always up-to-date.
  #
  handle_name_change: (new_name) =>
    @_set_design_name_field(new_name)

  #
  # Handles a change in "design name" text field.
  #
  handle_name_field_change: (e) =>
    @designer.set_name(e.srcElement.value, false)

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
    @_download_using_data_uri(@designer.serialize())
    



  #
  # Handles clicks of the "save to PNG" button.
  #
  handle_save_png_click: =>

    #TODO: Abstract the "new window" behavior.
    @designer.export_png()


  #
  # Handles the "export-to-VHDL" button; exports a VHDL file using a Data URI.
  # This method is not preferred, but will be used if Flash cannot be found.
  #
  handle_vhdl_export_html5_click: =>
    @_download_using_data_uri(@designer.to_VHDL(@get_design_filename()))


  #
  # Forces download of the given file's content using a Data URI.
  #
  _download_using_data_uri: (content) ->

    #convert it to a data URI
    uri_content = 'data:application/x-fsm,' + encodeURIComponent(content)
    
    #and ask the user's browser to download it
    document.location.href = uri_content



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
  # Adds or removes the given class depending on whether the provided condition is true.
  #
  _add_or_remove_class: (element, class_name, condition) ->
    if condition
      
      #Add the class, if it's not there already.
      unless element.className.indexOf(class_name) > -1
        element.className += " #{class_name} "

    else
      element.className = element.className.replace(" #{class_name} ", " ")
      

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
  # Attempts to clear the hidden file selection.
  #
  _clear_file_selection: ->
    document.getElementById('fileOpen').value = ''


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

    # Clear the internal file selector.
    @_clear_file_selection()

