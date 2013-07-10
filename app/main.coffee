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


{FSMDesignerApplication} = require 'fsm_designer_application'
  
#
# Initialize the application.
#
window.onload = ->

  # Get the canvas on which the designer will be rendered,
  # and the text field which will be used for user input.
  canvas     = document.getElementById('canvas')
  text_field = document.getElementById('text_field')
  toolbar    = document.getElementById('toolbar')
  file_form  = document.getElementById('staging')

  window.app = new FSMDesignerApplication(canvas, text_field, toolbar, file_form)
  app.run()
  
