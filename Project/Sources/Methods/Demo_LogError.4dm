//%attributes = {"invisible":true}
// Diagnostics for headless runs: record the error that stopped the method.
#DECLARE($mode : Variant; $code : Variant; $text : Variant)

var $file : 4D.File
$file:=File("/tmp/spooler-console-error.log")
var $made : Boolean
$made:=$file.parent.create()
$file.setText(String($mode)+" | "+String($code)+" | "+String($text))
