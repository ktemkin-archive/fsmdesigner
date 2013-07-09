###
  
 [Hey, this is CoffeeScript! If you're looking for the original source,
  look in "cross_browser_utils.coffee", not "cross_browser_utils.js".]

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

class exports.CrossBrowserUtils

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

