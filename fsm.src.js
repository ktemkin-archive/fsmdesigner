/*
 
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
*/

/***
 * FSMDesigner Class 
 ***/

function FSMDesigner(canvas) {

  /**
   * General Config
   */
  this.snapToPadding = 20; // pixels
  this.hitTargetPadding = 20; // pixels
  this.undo_history_size = 32;
  
  this.canvas = canvas;
  this.originalClick = null;
  this.cursorVisible = true;
  this.selectedObject = null; // either a Link or a Node
  this.currentLink = null; // a Link
  this.movingObject = false;
  this.inOutputMode = false; //determines if we're in edit-output mode

  this.textEntryTimeout = null;
  this.textEnteredRecently = false;
  this.textUndoDelay = 2000;

  this.nodes = [];
  this.links = [];
  this.undo_stack = [];
  this.redo_stack = [];

  //Stores whether the FSM is in "node creation" mode.
  this.modalBehavior = FSMDesigner.ModalBehaviors.POINTER;
  
  //Register the events associated with the given FSM designer.
  var _this = this;
  this.canvas.onmousedown = function(e) { _this.handlemousedown(e); };
  this.canvas.ondblclick = function(e) { _this.handledoubleclick(e); };
  this.canvas.onmousemove = function(e) { _this.handlemousemove(e); };
  this.canvas.onmouseup = function(e) { _this.handlemouseup(e); };
  this.canvas.addEventListener('drop', function(e) { _this.handledrop(e) }, false);

  //FIXME: replace these with addEventListener
  document.onkeypress = function(e) { _this.handlekeypress(e) };
  document.onkeydown = function(e) { _this.handlekeydown(e) };
  document.onkeyup = function(e) { _this.handlekeyup(e) };
}

FSMDesigner.ModalBehaviors = {
  POINTER: 'pointer',
  CREATE: 'create'
};

FSMDesigner.KeyCodes = {
  BACKSPACE: 8,
  SHIFT: 16,
  DELETE: 46,
  UNDO: 26,
  REDO: 25,
  z: 122,
  Z: 90
}

FSMDesigner.prototype.handledrop = function(e) {

  e.stopPropagation();
  e.preventDefault();

  if(e.dataTransfer.files.length != 1) {
    return;
  }

  //Load the system state from the dropped file.
  this.loadFromFile(e.dataTransfer.files[0]);

}

FSMDesigner.prototype.exportPNG = function() {
  
  //Temporarily deslect the active element, so it doesn't show as highlighted
  //in the exported copy.
  var oldSelectedObject = this.selectedObject;
  this.selectedObject = null;

  //Capture a PNG from the canvas.
  this.draw();
  var pngData = canvas.toDataURL('image/png');

  //And send the image to be captured, in a new tab.
  window.open(pngData, '_blank');
  window.focus();

  //Reset the selection.
  this.selectedObject = oldSelectedObject;
  this.draw();
}

/**
 *  Load a FSM diagram from the file specified.
 */
FSMDesigner.prototype.loadFromFile = function(file) {

  this.saveUndoStep();

  //Create a new FileReader object...
  var reader = new FileReader();

  //And use it to read the file's contents.
  var _this = this;
  reader.onload = function(file) { _this.recreateState(file.target.result); };
  reader.readAsText(file);

}


/**
 *  Determines if two designer "undo" states are equivalent.
 *  (No relation to nodes.)
 */
FSMDesigner.stepsEquivalent = function(a, b) {
  //HACK FIXME rewrite me!
  return JSON.stringify(a) == JSON.stringify(b);
}

FSMDesigner.prototype.saveFileHTML5 = function() {

  //Serialize the current state...
  var fileContents = JSON.stringify(this.createBackup()); 

  //And convert it to a HTML5 "Data URI".
  var uriContent = "data:application/x-fsm," + encodeURIComponent(fileContents);

  //Ask the user's browser to download it.
  document.location.href = uriContent;

}

/**
 * Return the data which should be saved to a file
 */
FSMDesigner.prototype.getDataToSave = function() {
  return JSON.stringify(this.createBackup());
}

/**
 * Saves an "undo step", which marks a point at which the user is capable of returning to by pressing undo.
 */
FSMDesigner.prototype.saveUndoStep = function() {

  var state = this.createBackup();
  var last_state = this.undo_stack[this.undo_stack.length - 1];

  //If the undo-step doesn't make any change, don't bother committing it.
  if(FSMDesigner.stepsEquivalent(state, last_state)) {
    return;
  }

  //If we're about to exceed the undo history size, 
  //get rid of the least recent undo.
  if(this.undo_stack.length >= this.undo_history_size) {
      this.undo_stack.shift();
  }

  //Push a backup onto the undo stack.
  this.undo_stack.push(state);
}

/**
 * Saves a "redo step", which marks a point at which the user is capable of returning to by pressing redo.
 * This will most likely only need to be called by the undo() function; or functions which emulate it.
 */
FSMDesigner.prototype.saveRedoStep = function() {
  //If we're about to exceed the undo history size, 
  //get rid of the least recent undo.
  if(this.redo_stack.length >= this.redo_history_size) {
      this.redo_stack.shift();
  }

  //Push a backup onto the undo stack.
  this.redo_stack.push(this.createBackup());
}

/**
 * Undo a user action.
 */
FSMDesigner.prototype.undo = function() {

  //If there's nothing to undo, abort!
  if(this.undo_stack.length == 0) {
    return;
  }

  //Push the current state onto the Redo stack...
  this.saveRedoStep();

  //Undo the last change...
  this.recreateState(this.undo_stack.pop());

  //And redraw.
  this.draw();
}

/**
 * Re-do a user action.
 */
FSMDesigner.prototype.redo = function() {

  //If there's nothing to re-do, abort.
  if(this.redo_stack.length == 0) {
    return;
  }

  //Push the current state onto the undo stack...
  this.saveUndoStep();

  //Redo the last change...
  this.recreateState(this.redo_stack.pop());

  //And redraw.
  this.draw();
}

/**
 * Clears the entire design, creating a blank canvas.
 */
FSMDesigner.prototype.clear = function(noSave) 
{
  //Unless we've been instructed not to save, save an undo step.
  if(!noSave) {
    this.saveUndoStep();
  }

  this.nodes = []
  this.links = []
  this.selectedObject = null;
  this.currentTarget = null;
  this.draw();
}


/**
 *  Attempt to find the object which owns the given position.
 */
FSMDesigner.prototype.selectObject = function(x, y) {

  //Check each of the nodes for the given point.
  for (var i = 0; i < this.nodes.length; i++) {
    if (this.nodes[i].containsPoint(x, y)) {
      return this.nodes[i];
    }
  }

  //Check each of the transition arcs for a given point.
  for (var i = 0; i < this.links.length; i++) {
    if (this.links[i].containsPoint(x, y)) {
      return this.links[i];
    }
  }

  //If we didn't find anything, return null.
  return null;
}

/**
 *  Removes the provided object from the FSM.
 */
FSMDesigner.prototype.deleteObject = function(object) {
  this.deleteNode(object);
  this.deleteLink(object);
}

/**
 *  Deletes the given node.
 */
FSMDesigner.prototype.deleteNode = function(node, noRedraw) {

    //Find the node to be deleted...
    var i = this.nodes.indexOf(node);

    //If we found it, delete it.
    if(i != -1) {

      //save state before the deletion 
      if(!noRedraw) {
        this.saveUndoStep(); 
      }

      //If this node was the currently selected object, unselect it.
      if(this.selectedObject == node) {
        this.selectedObject = null;
      }
      
      //Remove the given node...
      this.nodes.splice(i--, 1);

      //Remove any links are attached to this node.
      for(var j = 0; j < this.links.length; j++) {
        if(this.links[j].connectedTo(node)) {
          
          //Delete the link... 
          this.deleteLink(this.links[j], true);

          //Since we've modified the list, we now need to check the current element again.
          j--;
        }
      }

      //... and redraw.
      if(!noRedraw) {
        this.draw();
      }
    }
}

/**
 *  Deletes the link specified. 
 *  If the second parameter is "true", this function won't redraw afterwards.
 */
FSMDesigner.prototype.deleteLink = function(link, noRedraw) {

  //Find the link to be deleted.
  var i = this.links.indexOf(link);

  //If we found the it, delete it.
  if(i != -1) {

      //save state before the deletion 
      if(!noRedraw) {
        this.saveUndoStep(); 
      }

      //If this link was the currently selected object, unselect it.
      if(this.selectedObject == link) {
        this.selectedObject = null;
      }

      //Remove the given link, and redraw.
      this.links.splice(i--, 1);

      //Unless we've been instructed not to redraw, redraw.
      if(!noRedraw) {
        this.draw();
      }
  }

}

FSMDesigner.prototype.handlekeydown = function (e) {

  //Get the key-code of the key that was most recently pressed.
  var key = crossBrowserKey(e);

  //If the user has just pressed the shift key, switch to "create" mode.
  if (key == FSMDesigner.KeyCodes.SHIFT) {
    this.modalBehavior = FSMDesigner.ModalBehaviors.CREATE;
  } 
  //If we're not looking for a modifier key, and this canvas doesn't have focus,
  //allow this event handler to propogate to the other handlers.
  else if (!this.hasFocus()) {
    return true;
  } 
  //If we have a selected object, handle keyPressed events accordingly.
  else if (this.selectedObject != null) {

    //If the backspace key has been pressed, handle the removal of a single character.
    if (key == FSMDesigner.KeyCodes.BACKSPACE) { 

      //Save an undo step, if necessary.
      this.handleTextUndoStep();

      //If we're in output-entry mode, and the given node has text to remove...
      if(this.inOutputMode && this.selectedObject.outputs) {
        //Do so:
        this.selectedObject.outputs = this.selectedObject.outputs.substr(0, this.selectedObject.outputs.length - 1);
      } 
      //When we're not in output mode, handle the same case.
      else if(!this.inOutputMode && this.selectedObject.text) {
        this.selectedObject.text = this.selectedObject.text.substr(0, this.selectedObject.text.length - 1);
      }

      //Update text and re-draw.
      resetCaret();
      this.draw();

    }
    //If the user has pressed delete, delete the selected object.
    else if (key == FSMDesigner.KeyCodes.DELETE) { 
      this.deleteObject(this.selectedObject);
    }
  }

  // backspace is a shortcut for the back button, but do NOT want to change pages
  // FIXME? Should this be somewhere else?
  if (key == FSMDesigner.KeyCodes.BACKSPACE) { 
    return false;
  }
};

FSMDesigner.prototype.handlekeyup = function(e) {
  var key = crossBrowserKey(e);

  if (key == FSMDesigner.KeyCodes.SHIFT) {
    this.modalBehavior = FSMDesigner.ModalBehaviors.POINTER;
  }
};

FSMDesigner.prototype.handleTextUndoStep = function () {

  //Create a reference to the current object, which will be closed over in the
  //timeout call below.
  var _this = this;

  //Create a function which "turns off" the text entry timeout after a period of time.
  var cancelTimeout = function () { _this.textEnteredRecently = _this.textEntryTimeout = null;  }

  //If the user has entered text recently, re-set the "entered text recently" timer,
  //and skip seeting an Undo Step.
  if(this.textEntryTimeout) {
    clearTimeout(this.textEntryTimeout);
  }
  //Otherwise, save an undo step.
  else {
    this.saveUndoStep();
  }

  //Set up a timer, which will keep track of whether text has been entered recently.
  this.textEnteredRecently = true;
  this.textEntryTimeout = setTimeout(cancelTimeout, this.textUndoDelay);
}

FSMDesigner.prototype.handlekeypress = function(e) {

  var key = crossBrowserKey(e);

  if (!this.hasFocus()) {
    // don't read keystrokes when other things have focus
    return true;
  } 
  //TODO: replace these with key codes
  else if (key >= 0x20 && key <= 0x7E && !e.metaKey && !e.altKey && !e.ctrlKey && this.selectedObject != null && 'text' in this.selectedObject) {

    //Save an undo step, if necessary.
    this.handleTextUndoStep(); 

    //FIXME modalbehavior
    if(this.inOutputMode) {
        this.selectedObject.outputs += String.fromCharCode(key);
    } else {
        this.selectedObject.text += String.fromCharCode(key);
    }

    resetCaret();
    this.draw();

    // don't let keys do their actions (like space scrolls down the page)
    return false;
  }
  // If we've pressed CTRL+Z, undo the most recent action
  else if ((key == FSMDesigner.KeyCodes.z && e.ctrlKey && !e.shiftKey) || (key == FSMDesigner.KeyCodes.UNDO && !e.shiftKey)) {
    this.undo()
  }
  // If we've pressed CTRL+Y, undo the most recent action
  else if ((key == FSMDesigner.KeyCodes.Y && e.ctrlKey)
            || (key == FSMDesigner.KeyCodes.REDO) 
            || (key == FSMDesigner.KeyCodes.z && e.ctrlKey && e.shiftKey) 
            || (key == FSMDesigner.KeyCodes.UNDO && e.shiftKey)) {
    this.redo()
  }
  else if (key == 8) {
    // backspace is a shortcut for the back button, but do NOT want to change pages
    // TODO: move elsewhere?
    return false;
  }
};

/** 
 * Draws the active FSMDesginer using the current context.
 */ 
FSMDesigner.prototype.drawUsing = function (c) {
  c.clearRect(0, 0, this.canvas.width, this.canvas.height);
  c.save();
  c.translate(0.5, 0.5);

  //Draw each of the nodes in the current FSMDesigner.
  for (var i = 0; i < this.nodes.length; i++) {
    this.nodes[i].draw(c);
  }

  //Draw each of the links in the FSM Designer.
  for (var i = 0; i < this.links.length; i++) {
    this.links[i].draw(c);
  }

  //If we have a link-in-progress, draw it.
  if (this.currentLink != null) {
    this.currentLink.draw(c);
  }

  c.restore();
}


FSMDesigner.prototype.draw = function () {
  var context = this.canvas.getContext('2d');



  //TODO extract me to somewhere else
  context.canvas.width = window.innerWidth;
  context.canvas.height = window.innerHeight - document.getElementById("toolbar").offsetHeight;
  context.canvas.style.width = window.innerWidth + 'px';
  context.canvas.style.height = (window.innerHeight - document.getElementById('toolbar').offsetHeight) + 'px';

  //Perform the core modification...
  this.drawUsing(context);

  // And autosave.
  this.saveBackup();
}

FSMDesigner.prototype.saveBackup = function () {
  if (!localStorage || !JSON) {
    return;
  }

  localStorage['fsm'] = JSON.stringify(this.createBackup());
}


FSMDesigner.prototype.createBackup = function () {
  var backup = {
    'nodes': [],
    'links': []
  };

  //Back up each node in the current FSM.
  for (var i = 0; i < this.nodes.length; i++) {
    
    var node = this.nodes[i];
    var backupNode = {
      'x': node.x,
      'y': node.y,
      'text': node.text,
      'outputs': node.outputs,
      'isAcceptState': node.isAcceptState,
      'radius': node.radius
    };

    backup.nodes.push(backupNode);
  }

  //Back up each link in the current FSM.
  for (var i = 0; i < this.links.length; i++) {
    var link = this.links[i];
    var backupLink = null;
    if (link instanceof SelfLink) {
      backupLink = {
        'type': 'SelfLink',
        'node': this.nodes.indexOf(link.node),
        'text': link.text,
        'anchorAngle': link.anchorAngle
      };
    } else if (link instanceof StartLink) {
      backupLink = {
        'type': 'StartLink',
        'node': this.nodes.indexOf(link.node),
        'text': link.text,
        'deltaX': link.deltaX,
        'deltaY': link.deltaY
      };
    } else if (link instanceof Link) {
      backupLink = {
        'type': 'Link',
        'nodeA': this.nodes.indexOf(link.nodeA),
        'nodeB': this.nodes.indexOf(link.nodeB),
        'text': link.text,
        'lineAngleAdjust': link.lineAngleAdjust,
        'parallelPart': link.parallelPart,
        'perpendicularPart': link.perpendicularPart
      };
    }
    if (backupLink != null) {
      backup.links.push(backupLink);
    }
  }
  return backup;
}

FSMDesigner.prototype.recreateState = function (backup) {
  
  //If no backup was provided, try to restore the "local storage" copy.
  if(backup == null) {
    try {

        //If this browser doesn't suppor the localStorage or JSON extensions, abort.
        if (!localStorage || !JSON) {
            return false;
        }

        //Otherwise, load the value of the existing backup.
        backup = JSON.parse(localStorage['fsm']);

    } catch(e) {
      localStorage['fsm'] = '';
    }
  }

  //If we were given a string, interpret it as a JSON string.
  if(typeof backup == 'string') {
    try {
      backup = JSON.parse(backup);
    }
    catch(e) {}
  }

  if(!backup) {
    return;
  }

  //Clear the existing canvas.
  this.clear(true);
 
  //Restore each of the nodes.
  for (var i = 0; i < backup.nodes.length; i++) {
    var backupNode = backup.nodes[i];
    var node = new Node(backupNode.x, backupNode.y, this);
    node.isAcceptState = backupNode.isAcceptState;
    node.text = backupNode.text;
    node.outputs = backupNode.outputs;
    node.radius = backupNode.radius;
    this.nodes.push(node);
  }

  //Restore each of the links.
  for (var i = 0; i < backup.links.length; i++) {
    var backupLink = backup.links[i];
    var link = null;
    if (backupLink.type == 'SelfLink') {
      link = new SelfLink(this.nodes[backupLink.node], null, this);
      link.anchorAngle = backupLink.anchorAngle;
      link.text = backupLink.text;
    } else if (backupLink.type == 'StartLink') {
      link = new StartLink(this.nodes[backupLink.node], null, this);
      link.deltaX = backupLink.deltaAboutX;
      link.deltaY = backupLink.deltaY;
      link.text = backupLink.text;
    } else if (backupLink.type == 'Link') {
      link = new Link(this.nodes[backupLink.nodeA], this.nodes[backupLink.nodeB], this);
      link.parallelPart = backupLink.parallelPart;
      link.perpendicularPart = backupLink.perpendicularPart;
      link.text = backupLink.text;
      link.lineAngleAdjust = backupLink.lineAngleAdjust;
    }
    if (link != null) {
      this.links.push(link);
    }
  }

  //Draw the newly-reconstructed state.
  this.draw();
}

//FIXME remove
function canvasHasFocus() {
  return (document.activeElement || document.body) == document.body;
}


FSMDesigner.prototype.hasFocus = function () {

  //TODO: place me somewhere else; register a binding for this!
  if(document.getElementById('helppanel').style.visibility == "visible") {
    return false;
  }

  //TODO: generalize?
  return (document.activeElement || document.body) == document.body;
}

/**
 * Handle mouse-up events.
 */
FSMDesigner.prototype.handlemouseup = function(e) {

    //Ignore the mouse when a dialog is open.
    if(this.dialogOpen()) {
      return;
    }

    this.movingObject = false;

    if (this.currentLink != null) {
      //If we've just "dropped" a temporary link, convert it to a normal link.
      if (!(this.currentLink instanceof TemporaryLink)) {

        //Save the state before the modification
        this.saveUndoStep();

        //Change the selected object...
        this.selectedObject = this.currentLink;

        //And, since we've switched to a new object, reset the "text entered" timer.
        this.textEnteredRecently = false;


        this.links.push(this.currentLink);
        resetCaret();
      }
      this.currentLink = null;
      this.draw();
    }
  };

FSMDesigner.prototype.dialogOpen = function() {
  return document.getElementById('helppanel').style.visibility == "visible";
}


FSMDesigner.prototype.handlemousemove = function(e) {

    //Ignore the mouse when a dialog is open.
    if(this.dialogOpen()) {
      return;
    }

    var mouse = crossBrowserRelativeMousePos(e);

    if (this.currentLink != null) {
      var targetNode = this.selectObject(mouse.x, mouse.y);
      if (!(targetNode instanceof Node)) {
        targetNode = null;
      }

      if (this.selectedObject == null) {
        if (targetNode != null) {
          this.currentLink = new StartLink(targetNode, this.originalClick, this);
        } else {
          this.currentLink = new TemporaryLink(this.originalClick, mouse);
        }
      } else {
        if (targetNode == this.selectedObject) {
          this.currentLink = new SelfLink(this.selectedObject, mouse, this);
        } else if (targetNode != null) {
          this.currentLink = new Link(this.selectedObject, targetNode, this);
        } else {
          this.currentLink = new TemporaryLink(this.selectedObject.closestPointOnCircle(mouse.x, mouse.y), mouse);
        }
      }
      this.draw();
    }

    if (this.movingObject) {
      this.selectedObject.setAnchorPoint(mouse.x, mouse.y);
      if (this.selectedObject instanceof Node) {
        this.handleSnap();
      }
      this.draw();
    }
  };

/**
 * If appropriate, snap the given node into alignment with another node.
 */
FSMDesigner.prototype.handleSnap = function() {

  node = this.selectedObject;

  for (var i = 0; i < this.nodes.length; i++) {
    if (this.nodes[i] == node) continue;

    if (Math.abs(node.x - this.nodes[i].x) < this.snapToPadding) {
      node.x = this.nodes[i].x;
    }

    if (Math.abs(node.y - this.nodes[i].y) < this.snapToPadding) {
      node.y = this.nodes[i].y;
    }
  }
}


/**
 * Double-click handler for the FSM Designer.
 */
FSMDesigner.prototype.handledoubleclick = function(e) {

  //TODO: abstract to event queue
  handleModalBehavior();

  var mouse = crossBrowserRelativeMousePos(e);
  this.selectedObject = this.selectObject(mouse.x, mouse.y);
  this.textEnteredRecently = false;
  this.inOutputMode = false; //FIXME
  if (this.selectedObject == null) {
    this.saveUndoStep();
    this.selectedObject = new Node(mouse.x, mouse.y, this);
    this.nodes.push(this.selectedObject);
    resetCaret();
    this.draw();
  } 
  else if (this.selectedObject instanceof Node) {
    this.inOutputMode = true; //FIXME
    this.draw();
  }

  //Prevent text selection after double clicks, which plague chrome.
  if(document.selection && document.selection.empty) {
        document.selection.empty();
  } else if(window.getSelection) {
        var sel = window.getSelection();
        sel.removeAllRanges();
  }
};

/**
 * Handle mouse-down events for the FSMDesigner. 
 */
FSMDesigner.prototype.handlemousedown = function(e) {

    //Ignore the mouse when a dialog is open.
    if(this.dialogOpen()) {
      return;
    }

    var mouse = crossBrowserRelativeMousePos(e);

    this.selectedObject = this.selectObject(mouse.x, mouse.y);

    this.movingObject = false;
    this.inOutputMode = false;
    this.textEnteredRecently = false;
    this.originalClick = mouse;

    if (this.selectedObject != null) {
      if (this.modalBehavior == FSMDesigner.ModalBehaviors.CREATE && this.selectedObject instanceof Node) {
        this.currentLink = new SelfLink(this.selectedObject, mouse, this);
      } else {
        this.saveUndoStep();
        this.movingObject = true;
        this.deltaMouseX = this.deltaMouseY = 0;
        if (this.selectedObject.setMouseStart) {
          this.selectedObject.setMouseStart(mouse.x, mouse.y);
        }
      }
      resetCaret();
    } else if (this.modalBehavior == FSMDesigner.ModalBehaviors.CREATE) {
      this.currentLink = new TemporaryLink(mouse, mouse);
    }

    this.draw();

    if (this.hasFocus()) {
      // disable drag-and-drop only if the canvas is already focused
      return false;
    } else {
      // otherwise, let the browser switch the focus away from wherever it was
      resetCaret();
      return true;
    }
  };


/*
FSMDesigner.prototype.font_fallback = function() {
    this.nodeOutputFont = '18px, monospace';
    this.nodeFont = '20px, sans-serif';
    this.linkFont = '20px, monospace';
    this.draw();
}
*/


function Link(a, b, designer) {

  //apply link defaults to this object
  Link.setDefaults(this);

  this.parent = designer;
  this.nodeA = a;
  this.nodeB = b;
  this.text = '';
  this.lineAngleAdjust = 0; // value to add to textAngle when link is straight line

  // make anchor point relative to the locations of nodeA and nodeB
  this.parallelPart = 0.5; // percentage from nodeA to nodeB
  this.perpendicularPart = 0; // pixels from line between nodeA and nodeB
}

Link.setDefaults = function(linkObject) {
  /**
   * Link (/Transition/Arc) Configuration
   */
  linkObject.font = '16px "Inconsolata", monospace'
  linkObject.fgColor = "black";
  linkObject.bgColor = "white";
  linkObject.selectedColor = "blue";
}

/**
 *  Returns true iff the given link is connected to the node, on either side.
 */
Link.prototype.connectedTo = function (node) {
  return (this.nodeA == node || this.nodeB == node);
}

Link.prototype.getAnchorPoint = function() {
  var dx = this.nodeB.x - this.nodeA.x;
  var dy = this.nodeB.y - this.nodeA.y;
  var scale = Math.sqrt(dx * dx + dy * dy);
  return {
    'x': this.nodeA.x + dx * this.parallelPart - dy * this.perpendicularPart / scale,
    'y': this.nodeA.y + dy * this.parallelPart + dx * this.perpendicularPart / scale
  };
};

Link.prototype.setAnchorPoint = function(x, y) {
  var dx = this.nodeB.x - this.nodeA.x;
  var dy = this.nodeB.y - this.nodeA.y;
  var scale = Math.sqrt(dx * dx + dy * dy);
  this.parallelPart = (dx * (x - this.nodeA.x) + dy * (y - this.nodeA.y)) / (scale * scale);
  this.perpendicularPart = (dx * (y - this.nodeA.y) - dy * (x - this.nodeA.x)) / scale;
  // snap to a straight line
  if (this.parallelPart > 0 && this.parallelPart < 1 && Math.abs(this.perpendicularPart) < this.parent.snapToPadding) {
    this.lineAngleAdjust = (this.perpendicularPart < 0) * Math.PI;
    this.perpendicularPart = 0;
  }
};

Link.prototype.getEndPointsAndCircle = function() {
  if (this.perpendicularPart == 0) {
    var midX = (this.nodeA.x + this.nodeB.x) / 2;
    var midY = (this.nodeA.y + this.nodeB.y) / 2;
    var start = this.nodeA.closestPointOnCircle(midX, midY);
    var end = this.nodeB.closestPointOnCircle(midX, midY);
    return {
      'hasCircle': false,
      'startX': start.x,
      'startY': start.y,
      'endX': end.x,
      'endY': end.y
    };
  }
  var anchor = this.getAnchorPoint();
  var circle = circleFromThreePoints(this.nodeA.x, this.nodeA.y, this.nodeB.x, this.nodeB.y, anchor.x, anchor.y);
  var isReversed = (this.perpendicularPart > 0);
  var reverseScale = isReversed ? 1 : -1;
  var startAngle = Math.atan2(this.nodeA.y - circle.y, this.nodeA.x - circle.x) - reverseScale * this.nodeA.radius / circle.radius;
  var endAngle = Math.atan2(this.nodeB.y - circle.y, this.nodeB.x - circle.x) + reverseScale * this.nodeB.radius / circle.radius;
  var startX = circle.x + circle.radius * Math.cos(startAngle);
  var startY = circle.y + circle.radius * Math.sin(startAngle);
  var endX = circle.x + circle.radius * Math.cos(endAngle);
  var endY = circle.y + circle.radius * Math.sin(endAngle);
  return {
    'hasCircle': true,
    'startX': startX,
    'startY': startY,
    'endX': endX,
    'endY': endY,
    'startAngle': startAngle,
    'endAngle': endAngle,
    'circleX': circle.x,
    'circleY': circle.y,
    'circleRadius': circle.radius,
    'reverseScale': reverseScale,
    'isReversed': isReversed
  };
};

Link.applySelectColors = function (linkObject, c) {
  //If the current object is selected, set the stroke color accordingly.
  if(linkObject.parent.selectedObject == linkObject) {
    c.fillStyle = c.strokeStyle = linkObject.selectedColor;
  } else {
    c.fillStyle = c.strokeStyle = linkObject.fgColor;
  }
}

Link.prototype.draw = function(c) {
  var stuff = this.getEndPointsAndCircle();

  Link.applySelectColors(this, c);

  // draw arc
  c.beginPath();
  if (stuff.hasCircle) {
    c.arc(stuff.circleX, stuff.circleY, stuff.circleRadius, stuff.startAngle, stuff.endAngle, stuff.isReversed);
  } else {
    c.moveTo(stuff.startX, stuff.startY);
    c.lineTo(stuff.endX, stuff.endY);
  }
  c.stroke();
  // draw the head of the arrow
  if (stuff.hasCircle) {
    drawArrow(c, stuff.endX, stuff.endY, stuff.endAngle - stuff.reverseScale * (Math.PI / 2));
  } else {
    drawArrow(c, stuff.endX, stuff.endY, Math.atan2(stuff.endY - stuff.startY, stuff.endX - stuff.startX));
  }
  // draw the text
  if (stuff.hasCircle) {
    var startAngle = stuff.startAngle;
    var endAngle = stuff.endAngle;
    if (endAngle < startAngle) {
      endAngle += Math.PI * 2;
    }
    var textAngle = (startAngle + endAngle) / 2 + stuff.isReversed * Math.PI;
    var textX = stuff.circleX + stuff.circleRadius * Math.cos(textAngle);
    var textY = stuff.circleY + stuff.circleRadius * Math.sin(textAngle);
    drawText(c, this.text, textX, textY, textAngle, this.parent.selectedObject == this, this.font);
  } else {
    var textX = (stuff.startX + stuff.endX) / 2;
    var textY = (stuff.startY + stuff.endY) / 2;
    var textAngle = Math.atan2(stuff.endX - stuff.startX, stuff.startY - stuff.endY);
    drawText(c, this.text, textX, textY, textAngle + this.lineAngleAdjust, this.parent.selectedObject == this, this.font);
  }
};

Link.prototype.containsPoint = function(x, y) {
  var stuff = this.getEndPointsAndCircle();
  if (stuff.hasCircle) {
    var dx = x - stuff.circleX;
    var dy = y - stuff.circleY;
    var distance = Math.sqrt(dx*dx + dy*dy) - stuff.circleRadius;
    if (Math.abs(distance) < this.parent.hitTargetPadding) {
      var angle = Math.atan2(dy, dx);
      var startAngle = stuff.startAngle;
      var endAngle = stuff.endAngle;
      if (stuff.isReversed) {
        var temp = startAngle;
        startAngle = endAngle;
        endAngle = temp;
      }
      if (endAngle < startAngle) {
        endAngle += Math.PI * 2;
      }
      if (angle < startAngle) {
        angle += Math.PI * 2;
      } else if (angle > endAngle) {
        angle -= Math.PI * 2;
      }
      return (angle > startAngle && angle < endAngle);
    }
  } else {
    var dx = stuff.endX - stuff.startX;
    var dy = stuff.endY - stuff.startY;
    var length = Math.sqrt(dx*dx + dy*dy);
    var percent = (dx * (x - stuff.startX) + dy * (y - stuff.startY)) / (length * length);
    var distance = (dx * (y - stuff.startY) - dy * (x - stuff.startX)) / length;
    return (percent > 0 && percent < 1 && Math.abs(distance) < this.parent.hitTargetPadding);
  }
  return false;
};

function Node(x, y, designer) {

  /** 
   * Node defaults.
   * TODO: Abstract to somewhere else.
   */
  this.parent = designer
  this.radius = 55;
  this.outline = 2;
  this.fgColor = "black";
  this.bgColor = "white";
  this.selectedColor = "blue";
  this.font = '16px "Droid Sans", sans-serif'
  this.outputPadding = 14; //pixels
  this.outputFont = '20px "Inconsolata", monospace'
  this.outputColor = "#101010";


  this.x = x;
  this.y = y;
  this.mouseOffsetX = 0;
  this.mouseOffsetY = 0;
  this.isAcceptState = false;
  this.text = '';
  this.outputs = '';

  
}

Node.prototype.setMouseStart = function(x, y) {
  this.mouseOffsetX = this.x - x;
  this.mouseOffsetY = this.y - y;
};

Node.prototype.setAnchorPoint = function(x, y) {
  this.x = x + this.mouseOffsetX;
  this.y = y + this.mouseOffsetY;
};

Node.prototype.draw = function(c) {

  c.lineWidth = this.outline;

  // draw the circle
  c.beginPath();
  c.arc(this.x, this.y, this.radius, 0, 2 * Math.PI, false);
  c.fillStyle=this.bgColor;
  c.fill();
  c.strokeStyle= (this.parent.selectedObject === this && !this.parent.inOutputMode) ? this.selectedColor : this.fgColor;
  c.stroke();

  // draw the state name
  c.fillStyle = (this.parent.selectedObject === this && !this.parent.inOutputMode) ? this.selectedColor : this.fgColor;
  drawText(c, this.text, this.x, this.y, null, this.parent.selectedObject == this && !this.parent.inOutputMode, this.font);

  //draw the state's moore outputs
  c.fillStyle= (this.parent.selectedObject === this && this.parent.inOutputMode) ? this.selectedColor : this.outputColor;
  drawText(c, this.outputs, this.x, this.y + this.radius + this.outputPadding, null, this.parent.selectedObject == this && this.parent.inOutputMode, this.outputFont);
  c.fillStyle= (this.parent.selectedObject === this) ? this.selectedColor : this.fgColor;

  // draw a double circle for an accept state
  if (this.isAcceptState) {
    c.beginPath();
    c.arc(this.x, this.y, this.radius - 6, 0, 2 * Math.PI, false);
    c.stroke();
  }

};

Node.prototype.closestPointOnCircle = function(x, y) {
  var dx = x - this.x;
  var dy = y - this.y;
  var scale = Math.sqrt(dx * dx + dy * dy);
  return {
    'x': this.x + dx * this.radius / scale,
    'y': this.y + dy * this.radius / scale
  };
};

Node.prototype.containsPoint = function(x, y) {
  return (x - this.x)*(x - this.x) + (y - this.y)*(y - this.y) < this.radius*this.radius;
};

function SelfLink(node, mouse, designer) {

  this.parent = designer;

  //get the defaults from the link object:
  Link.setDefaults(this);

  this.node = node;
  this.anchorAngle = 0;
  this.mouseOffsetAngle = 0;
  this.text = '';

  if (mouse) {
    this.setAnchorPoint(mouse.x, mouse.y);
  }
}

/**
 *  Returns true iff the given link is connected to the given node.
 */
SelfLink.prototype.connectedTo = function (node) {
  return (this.node == node);
}

SelfLink.prototype.setMouseStart = function(x, y) {
  this.mouseOffsetAngle = this.anchorAngle - Math.atan2(y - this.node.y, x - this.node.x);
};

SelfLink.prototype.setAnchorPoint = function(x, y) {
  this.anchorAngle = Math.atan2(y - this.node.y, x - this.node.x) + this.mouseOffsetAngle;
  // snap to 90 degrees
  var snap = Math.round(this.anchorAngle / (Math.PI / 2)) * (Math.PI / 2);
  if (Math.abs(this.anchorAngle - snap) < 0.1) this.anchorAngle = snap;
  // keep in the range -pi to pi so our containsPoint() function always works 
  if (this.anchorAngle < -Math.PI) this.anchorAngle += 2 * Math.PI;
  if (this.anchorAngle > Math.PI) this.anchorAngle -= 2 * Math.PI;
};

SelfLink.prototype.getEndPointsAndCircle = function() {
  var circleX = this.node.x + 1.5 * this.node.radius * Math.cos(this.anchorAngle);
  var circleY = this.node.y + 1.5 * this.node.radius * Math.sin(this.anchorAngle);
  var circleRadius = 0.75 * this.node.radius;
  var startAngle = this.anchorAngle - Math.PI * 0.8;
  var endAngle = this.anchorAngle + Math.PI * 0.8;
  var startX = circleX + circleRadius * Math.cos(startAngle);
  var startY = circleY + circleRadius * Math.sin(startAngle);
  var endX = circleX + circleRadius * Math.cos(endAngle);
  var endY = circleY + circleRadius * Math.sin(endAngle);
  return {
    'hasCircle': true,
    'startX': startX,
    'startY': startY,
    'endX': endX,
    'endY': endY,
    'startAngle': startAngle,
    'endAngle': endAngle,
    'circleX': circleX,
    'circleY': circleY,
    'circleRadius': circleRadius
  };
};

SelfLink.prototype.draw = function(c) {
  var stuff = this.getEndPointsAndCircle();

  Link.applySelectColors(this, c);

  // draw arc
  c.beginPath();
  c.arc(stuff.circleX, stuff.circleY, stuff.circleRadius, stuff.startAngle, stuff.endAngle, false);
  c.stroke();
  // draw the text on the loop farthest from the node
  var textX = stuff.circleX + stuff.circleRadius * Math.cos(this.anchorAngle);
  var textY = stuff.circleY + stuff.circleRadius * Math.sin(this.anchorAngle);
  drawText(c, this.text, textX, textY, this.anchorAngle, this.parent.selectedObject == this, this.font);
  // draw the head of the arrow
  drawArrow(c, stuff.endX, stuff.endY, stuff.endAngle + Math.PI * 0.4);
};

SelfLink.prototype.containsPoint = function(x, y) {
  var stuff = this.getEndPointsAndCircle();
  var dx = x - stuff.circleX;
  var dy = y - stuff.circleY;
  var distance = Math.sqrt(dx*dx + dy*dy) - stuff.circleRadius;
  return (Math.abs(distance) < this.parent.hitTargetPadding);
};

function StartLink(node, start, designer) {
  this.parent = designer;

  Link.setDefaults(this);

  this.node = node;
  this.deltaX = 0;
  this.deltaY = 0;
  this.text = '';

  if (start) {
    this.setAnchorPoint(start.x, start.y);
  }
}

StartLink.prototype.connectedTo = function(node) {
  return (this.node == node);
}

StartLink.prototype.setAnchorPoint = function(x, y) {

  if(!this.node) {
    return;
  }

  this.deltaX = x - this.node.x;
  this.deltaY = y - this.node.y;

  if (Math.abs(this.deltaX) < this.parent.snapToPadding) {
    this.deltaX = 0;
  }

  if (Math.abs(this.deltaY) < this.parent.snapToPadding) {
    this.deltaY = 0;
  }
};

StartLink.prototype.getEndPoints = function() {
  var startX = this.node.x + this.deltaX;
  var startY = this.node.y + this.deltaY;
  var end = this.node.closestPointOnCircle(startX, startY);
  return {
    'startX': startX,
    'startY': startY,
    'endX': end.x,
    'endY': end.y
  };
};

StartLink.prototype.draw = function(c) {

  //If we're not connected to a node, abort!
  if(!this.node) {
    return;
  }
  
  var stuff = this.getEndPoints();

  Link.applySelectColors(this, c);

  // draw the line
  c.beginPath();
  c.moveTo(stuff.startX, stuff.startY);
  c.lineTo(stuff.endX, stuff.endY);
  c.stroke();

  // draw the text at the end without the arrow
  var textAngle = Math.atan2(stuff.startY - stuff.endY, stuff.startX - stuff.endX);
  drawText(c, this.text, stuff.startX, stuff.startY, textAngle, this.parent.selectedObject == this, this.linkFont);

  // draw the head of the arrow
  drawArrow(c, stuff.endX, stuff.endY, Math.atan2(-this.deltaY, -this.deltaX));
};

StartLink.prototype.containsPoint = function(x, y) {

  //If we don't have a node, then we can't have any points.
  if(!this.node) {
    return false;
  }

  var stuff = this.getEndPoints();
  var dx = stuff.endX - stuff.startX;
  var dy = stuff.endY - stuff.startY;
  var length = Math.sqrt(dx*dx + dy*dy);
  var percent = (dx * (x - stuff.startX) + dy * (y - stuff.startY)) / (length * length);
  var distance = (dx * (y - stuff.startY) - dy * (x - stuff.startX)) / length;
  return (percent > 0 && percent < 1 && Math.abs(distance) < this.parent.hitTargetPadding);
};

function TemporaryLink(from, to) {
  this.from = from;
  this.to = to;
}

TemporaryLink.prototype.draw = function(c) {

  // draw the line
  c.beginPath();
  c.moveTo(this.to.x, this.to.y);
  c.lineTo(this.from.x, this.from.y);
  c.stroke();

  // draw the head of the arrow
  drawArrow(c, this.to.x, this.to.y, Math.atan2(this.to.y - this.from.y, this.to.x - this.from.x));
};

// draw using this instead of a canvas and call toLaTeX() afterward
function ExportAsLaTeX() {
  this._points = [];
  this._texData = '';
  this._scale = 0.1; // to convert pixels to document space (TikZ breaks if the numbers get too big, above 500?)

  this.toLaTeX = function() {
    return '\\documentclass[12pt]{article}\n' +
      '\\usepackage{tikz}\n' +
      '\n' +
      '\\begin{document}\n' +
      '\n' +
      '\\begin{center}\n' +
      '\\begin{tikzpicture}[scale=0.2]\n' +
      '\\tikzstyle{every node}+=[inner sep=0pt]\n' +
      this._texData +
      '\\end{tikzpicture}\n' +
      '\\end{center}\n' +
      '\n' +
      '\\end{document}\n';
  };

  this.beginPath = function() {
    this._points = [];
  };
  this.arc = function(x, y, radius, startAngle, endAngle, isReversed) {
    x *= this._scale;
    y *= this._scale;
    radius *= this._scale;
    if (endAngle - startAngle == Math.PI * 2) {
      this._texData += '\\draw [' + this.strokeStyle + '] (' + fixed(x, 3) + ',' + fixed(-y, 3) + ') circle (' + fixed(radius, 3) + ');\n';
    } else {
      if (isReversed) {
        var temp = startAngle;
        startAngle = endAngle;
        endAngle = temp;
      }
      if (endAngle < startAngle) {
        endAngle += Math.PI * 2;
      }
      // TikZ needs the angles to be in between -2pi and 2pi or it breaks
      if (Math.min(startAngle, endAngle) < -2*Math.PI) {
        startAngle += 2*Math.PI;
        endAngle += 2*Math.PI;
      } else if (Math.max(startAngle, endAngle) > 2*Math.PI) {
        startAngle -= 2*Math.PI;
        endAngle -= 2*Math.PI;
      }
      startAngle = -startAngle;
      endAngle = -endAngle;
      this._texData += '\\draw [' + this.strokeStyle + '] (' + fixed(x + radius * Math.cos(startAngle), 3) + ',' + fixed(-y + radius * Math.sin(startAngle), 3) + ') arc (' + fixed(startAngle * 180 / Math.PI, 5) + ':' + fixed(endAngle * 180 / Math.PI, 5) + ':' + fixed(radius, 3) + ');\n';
    }
  };
  this.moveTo = this.lineTo = function(x, y) {
    x *= this._scale;
    y *= this._scale;
    this._points.push({ 'x': x, 'y': y });
  };
  this.stroke = function() {
    if (this._points.length == 0) return;
    this._texData += '\\draw [' + this.strokeStyle + ']';
    for (var i = 0; i < this._points.length; i++) {
      var p = this._points[i];
      this._texData += (i > 0 ? ' --' : '') + ' (' + fixed(p.x, 2) + ',' + fixed(-p.y, 2) + ')';
    }
    this._texData += ';\n';
  };
  this.fill = function() {
    if (this._points.length == 0) return;
    this._texData += '\\fill [' + this.strokeStyle + ']';
    for (var i = 0; i < this._points.length; i++) {
      var p = this._points[i];
      this._texData += (i > 0 ? ' --' : '') + ' (' + fixed(p.x, 2) + ',' + fixed(-p.y, 2) + ')';
    }
    this._texData += ';\n';
  };
  this.measureText = function(text, font) {
    var c = canvas.getContext('2d');
    if(font !== null) {
      c.font = font
    } else {
      c.font = nodeFont
    }
    return c.measureText(text);
  };
  this.advancedFillText = function(text, originalText, x, y, angleOrNull) {
    if (text.replace(' ', '').length > 0) {
      var nodeParams = '';
      // x and y start off as the center of the text, but will be moved to one side of the box when angleOrNull != null
      if (angleOrNull != null) {
        var width = this.measureText(text).width;
        var dx = Math.cos(angleOrNull);
        var dy = Math.sin(angleOrNull);
        if (Math.abs(dx) > Math.abs(dy)) {
          if (dx > 0) { nodeParams = '[right] '; x -= width / 2; }
          else { nodeParams = '[left] '; x += width / 2; }
        } else {
          if (dy > 0) { nodeParams = '[below] '; y -= 10; }
          else { nodeParams = '[above] '; y += 10; }
        }
      }
      x *= this._scale;
      y *= this._scale;
      this._texData += '\\draw (' + fixed(x, 2) + ',' + fixed(-y, 2) + ') node ' + nodeParams + '{$' + originalText.replace(/ /g, '\\mbox{ }') + '$};\n';
    }
  };

  this.translate = this.save = this.restore = this.clearRect = function(){};
}

// draw using this instead of a canvas and call toSVG() afterward
function ExportAsSVG() {
  this.fillStyle = 'black';
  this.strokeStyle = 'black';
  this.lineWidth = 1;
  this.font = '12px Arial, sans-serif';
  this._points = [];
  this._svgData = '';
  this._transX = 0;
  this._transY = 0;

  this.toSVG = function() {
    return '<?xml version="1.0" standalone="no"?>\n<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n\n<svg width="800" height="600" version="1.1" xmlns="http://www.w3.org/2000/svg">\n' + this._svgData + '</svg>\n';
  };

  this.beginPath = function() {
    this._points = [];
  };
  this.arc = function(x, y, radius, startAngle, endAngle, isReversed) {
    x += this._transX;
    y += this._transY;
    var style = 'stroke="' + this.strokeStyle + '" stroke-width="' + this.lineWidth + '" fill="none"';

    if (endAngle - startAngle == Math.PI * 2) {
      this._svgData += '\t<ellipse ' + style + ' cx="' + fixed(x, 3) + '" cy="' + fixed(y, 3) + '" rx="' + fixed(radius, 3) + '" ry="' + fixed(radius, 3) + '"/>\n';
    } else {
      if (isReversed) {
        var temp = startAngle;
        startAngle = endAngle;
        endAngle = temp;
      }

      if (endAngle < startAngle) {
        endAngle += Math.PI * 2;
      }

      var startX = x + radius * Math.cos(startAngle);
      var startY = y + radius * Math.sin(startAngle);
      var endX = x + radius * Math.cos(endAngle);
      var endY = y + radius * Math.sin(endAngle);
      var useGreaterThan180 = (Math.abs(endAngle - startAngle) > Math.PI);
      var goInPositiveDirection = 1;

      this._svgData += '\t<path ' + style + ' d="';
      this._svgData += 'M ' + fixed(startX, 3) + ',' + fixed(startY, 3) + ' '; // startPoint(startX, startY)
      this._svgData += 'A ' + fixed(radius, 3) + ',' + fixed(radius, 3) + ' '; // radii(radius, radius)
      this._svgData += '0 '; // value of 0 means perfect circle, others mean ellipse
      this._svgData += +useGreaterThan180 + ' ';
      this._svgData += +goInPositiveDirection + ' ';
      this._svgData += fixed(endX, 3) + ',' + fixed(endY, 3); // endPoint(endX, endY)
      this._svgData += '"/>\n';
    }
  };
  this.moveTo = this.lineTo = function(x, y) {
    x += this._transX;
    y += this._transY;
    this._points.push({ 'x': x, 'y': y });
  };
  this.stroke = function() {
    if (this._points.length == 0) return;
    this._svgData += '\t<polygon stroke="' + this.strokeStyle + '" stroke-width="' + this.lineWidth + '" points="';
    for (var i = 0; i < this._points.length; i++) {
      this._svgData += (i > 0 ? ' ' : '') + fixed(this._points[i].x, 3) + ',' + fixed(this._points[i].y, 3);
    }
    this._svgData += '"/>\n';
  };
  this.fill = function() {
    if (this._points.length == 0) return;
    this._svgData += '\t<polygon fill="' + this.fillStyle + '" stroke-width="' + this.lineWidth + '" points="';
    for (var i = 0; i < this._points.length; i++) {
      this._svgData += (i > 0 ? ' ' : '') + fixed(this._points[i].x, 3) + ',' + fixed(this._points[i].y, 3);
    }
    this._svgData += '"/>\n';
  };
  this.measureText = function(text) {
    var c = canvas.getContext('2d');
    c.font = nodeFont
    return c.measureText(text);
  };
  this.fillText = function(text, x, y) {
    x += this._transX;
    y += this._transY;
    if (text.replace(' ', '').length > 0) {
      this._svgData += '\t<text x="' + fixed(x, 3) + '" y="' + fixed(y, 3) + '" font-family="Times New Roman" font-size="20">' + textToXML(text) + '</text>\n';
    }
  };
  this.translate = function(x, y) {
    this._transX = x;
    this._transY = y;
  };

  this.save = this.restore = this.clearRect = function(){};
}

var greekLetterNames = [ 'Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon', 'Zeta', 'Eta', 'Theta', 'Iota', 'Kappa', 'Lambda', 'Mu', 'Nu', 'Xi', 'Omicron', 'Pi', 'Rho', 'Sigma', 'Tau', 'Upsilon', 'Phi', 'Chi', 'Psi', 'Omega' ];

function convertLatexShortcuts(text) {
  // html greek characters
  for (var i = 0; i < greekLetterNames.length; i++) {
    var name = greekLetterNames[i];
    text = text.replace(new RegExp('\\\\' + name, 'g'), String.fromCharCode(913 + i + (i > 16)));
    text = text.replace(new RegExp('\\\\' + name.toLowerCase(), 'g'), String.fromCharCode(945 + i + (i > 16)));
  }

  // subscripts
  for (var i = 0; i < 10; i++) {
    text = text.replace(new RegExp('_' + i, 'g'), String.fromCharCode(8320 + i));
  }

  return text;
}

function textToXML(text) {
  text = text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  var result = '';
  for (var i = 0; i < text.length; i++) {
    var c = text.charCodeAt(i);
    if (c >= 0x20 && c <= 0x7E) {
      result += text[i];
    } else {
      result += '&#' + c + ';';
    }
  }
  return result;
}

function drawArrow(c, x, y, angle) {
  var dx = Math.cos(angle);
  var dy = Math.sin(angle);
  c.beginPath();
  c.moveTo(x, y);
  c.lineTo(x - 8 * dx + 5 * dy, y - 8 * dy - 5 * dx);
  c.lineTo(x - 8 * dx - 5 * dy, y - 8 * dy + 5 * dx);
  c.fill();
}


function drawText(c, originalText, x, y, angleOrNull, isSelected, font) {
  text = convertLatexShortcuts(originalText);
  c.font = font
  var width = c.measureText(text, font).width;

  // center the text
  x -= width / 2;

  // position the text intelligently if given an angle
  if (angleOrNull != null) {
    var cos = Math.cos(angleOrNull);
    var sin = Math.sin(angleOrNull);
    var cornerPointX = (width / 2 + 5) * (cos > 0 ? 1 : -1);
    var cornerPointY = (10 + 5) * (sin > 0 ? 1 : -1);
    var slide = sin * Math.pow(Math.abs(sin), 40) * cornerPointX - cos * Math.pow(Math.abs(cos), 10) * cornerPointY;
    x += cornerPointX - sin * slide;
    y += cornerPointY + cos * slide;
  }

  // draw text and caret (round the coordinates so the caret falls on a pixel)
  if ('advancedFillText' in c) {
    c.advancedFillText(text, originalText, x + width / 2, y, angleOrNull);
  } else {
    x = Math.round(x);
    y = Math.round(y);
    c.fillText(text, x, y + 6);
    if (isSelected && caretVisible && canvasHasFocus() && document.hasFocus()) {
      x += width;
      c.beginPath();
      c.moveTo(x, y - 10);
      c.lineTo(x, y + 10);
      c.stroke();
    }
  }
}

var caretTimer;
var caretVisible = true;

function resetCaret() {
  clearInterval(caretTimer);
  caretTimer = setInterval('caretVisible = !caretVisible; redrawAll()', 500);
  caretVisible = true;
}


var designers = [];

function redrawAll() {
  for(var i = 0; i < designers.length; ++i) {
    designers[i].draw();
  }
}

function register_new_designer(designer) {
  designers.push(designer);
}


function load_fonts() {
     //Load fonts before continuing...
     WebFontConfig = {
        google: { families: [ 'Droid+Sans:400,700:latin' ] },
        active: function() { redrawAll(); setTimeout(redrawAll, 1000); }
        /* inactive: font_fallback */
      };
      (function() {
        var wf = document.createElement('script');
        wf.src = ('https:' == document.location.protocol ? 'https' : 'http') +
          '://ajax.googleapis.com/ajax/libs/webfont/1/webfont.js';
        wf.type = 'text/javascript';
        wf.async = 'true';
        var s = document.getElementsByTagName('script')[0];
        s.parentNode.insertBefore(wf, s);
      })()
}

function manualOpenFallback() {
    document.getElementById('staging').style.visibility = 'visible';
}

function handleOpen(designer, e) {

  //If we can't read files ourselves, ignore any change in this file's value.
  if(typeof(FileReader) == 'undefined') {
    return;
  }

  //If we didn't get exactly one file, abort.
  if(e.target.files.length != 1) {
    return;
  }

  //Open the file, and import its result.
  designer.loadFromFile(e.target.files[0]); 

}

window.onload = function() {

    load_fonts();

    //TODO: abstract to another file?
    canvas = document.getElementById('canvas');
    designer = new FSMDesigner(canvas);
    designer.recreateState();
    designer.draw();
    register_new_designer(designer);

    //TOOD: abstract to another file
    document.getElementById('btnNew').onclick = function () { designer.clear() };
    document.getElementById('btnUndo').onclick = function () { designer.undo() };
    document.getElementById('btnRedo').onclick = function () { designer.redo() };

    window.onresize = function () { redrawAll(); };

    var options = {
      swf: 'lib/downloadify.swf',
      downloadImage: 'img/download.gif',
      width: document.getElementById('btnSaveDummy').offsetWidth,
      height: document.getElementById('btnSaveDummy').offsetHeight,
      append: true,
      transparent: true,
      filename: 'FiniteStateMachine.fsmd',
      data: function () { return designer.getDataToSave(); }
    };

    /** 
     * File save/download set-up.
     */

    Downloadify.create('btnSave', options);
    //document.getElementById('btnSaveDummy').style.marginRight = -1 * document.getElementById('btnSave').offsetWidth + "px";
    document.getElementById('btnSaveDummy').style.zIndex = -100;
    document.getElementById('btnSave').style.zIndex = 100;

    //Fall back to HTML5 on systems that don't support Flash.
    document.getElementById('btnSaveDummy').onclick = function () { designer.saveFileHTML5() };

    /**
     * File open set-up.
     */
    document.getElementById('btnOpen').onclick = function () { handleOpenButton(); };
    document.getElementById('fileOpen').onchange = function(e) { handleOpen(designer, e); };
    document.getElementById('cancelOpen').onclick = function() { closeOpenDialog(); };

    /**
     * File export set-up.
     */ 
    document.getElementById('btnSavePNG').onclick = function() { designer.exportPNG(); };

    /**
     * Help buttons.
     */ 
    document.getElementById('btnHelp').onclick = function() { toggleHelp(); };
    document.getElementById('btnDismissHelp').onclick = function() { toggleHelp(); };

    //If we've never seen this "user" before, show the help splash.
    if(localStorage['seenFSMDesigner'] == undefined) {
      document.getElementById('btnHelp').click();
      localStorage['seenFSMDesigner'] = 'yes';
    }
};

function handleOpenButton() {

  //If we have access to HTML5's file upload capabilities, use them to handle the file on the client-side.
  if(typeof(FileReader) != 'undefined') {
    document.getElementById('fileOpen').click(); 
  }
  //Otherwise, shown an "open" form.
  else {
    manualOpenFallback(); 
  }
}

function toggleHelp() {
  var panel = document.getElementById('helppanel');

  if(panel.style.visibility == "visible") {
    panel.style.opacity = 0;
    setTimeout(function() { panel.style.visibility = "hidden" }, 0.2 * 1000);
  } else {
    panel.style.visibility = "visible";
    panel.style.opacity = 1;
  }

}

function closeOpenDialog() {
    var dialog = document.getElementById('staging');
    dialog.style.visibility = "hidden";
}

//FIXME
function handleModalBehavior() {
  if(document.getElementById('helppanel').style.visibility == "visible") {
    toggleHelp();
  }
  if(document.getElementById('staging').style.visibility == "visible") {
    closeOpenDialog();
  }
}


function crossBrowserKey(e) {
  e = e || window.event;
  return e.which || e.keyCode;
}

function crossBrowserElementPos(e) {
  e = e || window.event;
  var obj = e.target || e.srcElement;
  var x = 0, y = 0;
  while(obj.offsetParent) {
    x += obj.offsetLeft;
    y += obj.offsetTop;
    obj = obj.offsetParent;
  }
  return { 'x': x, 'y': y };
}

function crossBrowserMousePos(e) {
  e = e || window.event;
  return {
    'x': e.pageX || e.clientX + document.body.scrollLeft + document.documentElement.scrollLeft,
    'y': e.pageY || e.clientY + document.body.scrollTop + document.documentElement.scrollTop
  };
}

function crossBrowserRelativeMousePos(e) {
  var element = crossBrowserElementPos(e);
  var mouse = crossBrowserMousePos(e);
  return {
    'x': mouse.x - element.x,
    'y': mouse.y - element.y
  };
}

function output(text) {
  var element = document.getElementById('output');
  element.style.display = 'block';
  element.value = text;
}


//FIXME
function saveAsSVG() {
  var exporter = new ExportAsSVG();
  var oldSelectedObject = selectedObject;
  selectedObject = null;
  drawUsing(exporter);
  selectedObject = oldSelectedObject;
  var svgData = exporter.toSVG();
  output(svgData);
  // Chrome isn't ready for this yet, the 'Save As' menu item is disabled
  // document.location.href = 'data:image/svg+xml;base64,' + btoa(svgData);
}

//FIXME
function saveAsLaTeX() {
  var exporter = new ExportAsLaTeX();
  var oldSelectedObject = selectedObject;
  selectedObject = null;
  drawUsing(exporter);
  selectedObject = oldSelectedObject;
  var texData = exporter.toLaTeX();
  output(texData);
}

function det(a, b, c, d, e, f, g, h, i) {
  return a*e*i + b*f*g + c*d*h - a*f*h - b*d*i - c*e*g;
}

function circleFromThreePoints(x1, y1, x2, y2, x3, y3) {
  var a = det(x1, y1, 1, x2, y2, 1, x3, y3, 1);
  var bx = -det(x1*x1 + y1*y1, y1, 1, x2*x2 + y2*y2, y2, 1, x3*x3 + y3*y3, y3, 1);
  var by = det(x1*x1 + y1*y1, x1, 1, x2*x2 + y2*y2, x2, 1, x3*x3 + y3*y3, x3, 1);
  var c = -det(x1*x1 + y1*y1, x1, y1, x2*x2 + y2*y2, x2, y2, x3*x3 + y3*y3, x3, y3);
  return {
    'x': -bx / (2*a),
    'y': -by / (2*a),
    'radius': Math.sqrt(bx*bx + by*by - 4*a*c) / (2*Math.abs(a))
  };
}

function fixed(number, digits) {
  return number.toFixed(digits).replace(/0+$/, '').replace(/\.$/, '');
}



