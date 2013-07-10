<?php

/**
 * Upload helper for Internet Explorer 8/9, and other non-standards-compliant browsers.
 */

//If we failed to upload a file, display an error condition.
if($_FILES['fileOpen']["error"] != UPLOAD_ERR_OK) {
  header('location:index.html');
} 
//Otherwise, use the file to set the contents of local storage, and continue...
else {
    echo '<script src="javascripts/vendor.js" ></script>';
    echo '<script type="text/javascript">';
    echo '   var datastore = new Persist.Store("FSMDesigner", {swf_path: "flash/persist.swf"})';
    echo '   datastore.set("autosave", \''.file_get_contents($_FILES['fileOpen']['tmp_name']).'\');';
    echo '   document.location.replace("index.html");';
    echo '</script>';
}

