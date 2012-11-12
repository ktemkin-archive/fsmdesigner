<?php

/**
 * Quick (temporary) stub for generating VHDL from post-data.
 */

//If we haven't been passed a FSM, redirect the user to the main page.
if(empty($_POST['fsm'])) {
    header('location: index.html');
}

header('Content-Type: application/octet-stream');
header('Content-Disposition: attachment; filename=FiniteStateMachine.vhd');

//create a temporary file for the FSM
$file = tempnam('/tmp', 'genhdl');

//and fill it with the given FSM
file_put_contents($file, $_POST['fsm']);

//Run the FSM converter on the file.
exec('fsmconv -f fsmd "'.$file.'"', $output);

//create the VHDL file's contents
$vhdl = implode("\n", $output);

header('Content-Disposition: attachment; filename=FiniteStateMachine.vhd');
header('Connection: close');

echo $vhdl;

//delete the temporary file
unlink($file);
