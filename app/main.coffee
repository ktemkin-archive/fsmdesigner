###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in "fsm.coffee", not "fsm.js".]

 Finite State Machine Designer
 portions Copyright (c) Binghamton University,
 author: Kyle J. Temkin <ktemkin@binghamton.edu>

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

#
# Handles resizing of the owning window.
#
handle_resize = (canvas) ->

  # The element above our canvas.
  above = document.getElementById("toolbar")

  # Resize the canvas' internal rendering sizes....
  canvas.width = window.innerWidth
  canvas.height = window.innerHeight - above.offsetHeight - above.offsetTop

  # ... and ensure the canvas matches those sizes.
  canvas.style.width = canvas.width + 'px'
  canvas.style.height = canvas.height + 'px'


#
# Perform the core JS start-up, once the window is ready.
#
window.onload = ->

  # Get the canvas on which the designer will be rendered,
  # and the text field which will be used for user input.
  canvas = document.getElementById('canvas')
  text_field = document.getElementById('text_field')

  # Create a basic data-store for the persistant features, like autosaving.
  datastore = new Persist.Store('FSMDesigner', {swf_path: 'flash/persist.swf'})

  # Simple event handlers for the FSMDesigner, which handle autosave.
  event_handlers =
    redraw: -> datastore.set('autosave', @serialize())
    resize: handle_resize

  # Attempt to fetch data regarding the last design, if it exists.
  last_design = datastore.get('autosave')
      
  # If we were able to get a last design, re-create the FSM designer from the last serialized input.
  if last_design?
    window.designer = FSMDesigner.unserialize(last_design, text_field, canvas, window, event_handlers)
  else
    window.designer = new FSMDesigner(canvas, text_field,  window, event_handlers)

