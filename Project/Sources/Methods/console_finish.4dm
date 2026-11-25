//%attributes = {"invisible":true}
// Called via CALL FORM from receive() after the bootstrap values were applied.
// The current cycle paints them; this runs in the next cycle, so the capture
// shows the filled form instead of an empty window.

var $path : Text
$path:=Form.__screenshotPath

If ($path#"")
	var $picture : Picture
	FORM SCREENSHOT($picture)
	var $file : 4D.File
	var $made : Boolean
	$file:=File($path; fk posix path)
	$made:=$file.parent.create()
	WRITE PICTURE FILE($file.platformPath; $picture)
End if 

ACCEPT
QUIT 4D
