#DECLARE($params : Object)

var $title : Text
var $window : Integer
$title:="Spooler Console"

If (Count parameters=0)
	
	// Re-running the menu entry brings the existing window to the front.
	ARRAY LONGINT($windows; 0)
	WINDOW LIST($windows)
	var $i : Integer
	For ($i; 1; Size of array($windows))
		$window:=$windows{$i}
		If (Window process($window)=1) && (Get window title($window)=$title)
			var $left; $top; $right; $bottom : Integer
			GET WINDOW RECT($left; $top; $right; $bottom; $window)
			CALL FORM($window; Formula(SET WINDOW RECT($left; $top; $right; $bottom; $window)))
			return 
		End if 
	End for 
	
	// The window must live in its own worker: it stays interactive while the
	// component's external process runs, and worker 1 is a stable rendezvous.
	CALL WORKER(1; Current method name; {})
	
Else 
	
	SET MENU BAR(1)
	
	var $console : cs.SpoolerConsole
	$console:=cs.SpoolerConsole.new()
	
	$window:=Open form window("Console"; Plain form window; Horizontally centered; Vertically centered)
	SET WINDOW TITLE($title; $window)
	
	DIALOG("Console"; $console; *)
	
End if 
