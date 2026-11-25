//%attributes = {"invisible":true}
// CLI endpoint for the "Console" form, used to capture docs/console-runtime.png.
// It fills the view model with one synchronous bootstrap (the interactive Start
// path uses the worker instead), then lets the window paint before capturing.
// Usage: --startup-method console_screenshot --user-param "/path/to/output.png"
ON ERR CALL("Demo_LogError"; ek local)

var $unused : Real
var $path : Text
$unused:=Get database parameter(User param value; $path)

var $console : cs.SpoolerConsole
$console:=cs.SpoolerConsole.new()
$console.__screenshotPath:=$path

var $payload : Object
$payload:=$console.bootstrap()
$console.receive($payload)

// Evidence that the capture really contains live values.
var $state : 4D.File
$state:=File("/tmp/capture-state.txt"; fk posix path)
$state.setText($console.statusText+Char(10)+$console.detailText+Char(10)+"queues="+String($console.queues.length))

var $window : Integer
$window:=Open form window("Console"; Plain form window; Horizontally centered; Vertically centered)
SET WINDOW TITLE("Spooler Console"; $window)
DIALOG("Console"; $console; *)

// Runs in the next event cycle, after the window has painted the values.
CALL FORM($window; Formula(console_finish))
