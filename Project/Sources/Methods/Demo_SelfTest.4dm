//%attributes = {"invisible":true}
// Headless driver: exercises the same SpoolerConsole paths the form uses and
// writes a JSON report. --user-param accepts either the report path or a JSON
// object {"queue":"id","report":"/path"}. With no "queue" the run is read-only.

var $unused : Real
var $parameter : Text
var $options : Object
var $path : Text
$parameter:=""
$unused:=Get database parameter(User param value; $parameter)
$options:=New object()
If ($parameter#"")
	If (Substring($parameter; 1; 1)="{")
		ON ERR CALL("Demo_IgnoreError"; ek local)
		$options:=JSON Parse($parameter)
		ON ERR CALL(""; ek local)
		If (Value type($options)#Is object)
			$options:=New object()
		End if 
	Else 
		$options.report:=$parameter
	End if 
End if 
$path:="/tmp/spooler-console-report.json"
If (Value type($options.report)=Is text)
	If ($options.report#"")
		$path:=$options.report
	End if 
End if 

var $console : cs.SpoolerConsole
$console:=cs.SpoolerConsole.new()

var $report : Object
$report:=$console.selfTest($options)
$report.reportPath:=$path

var $file : 4D.File
var $made : Boolean
$file:=File($path; fk posix path)
$made:=$file.parent.create()
$file.setText(JSON Stringify($report; *))

// One line per check for the shell, plus a machine-readable summary.
var $check : Object
var $line : Text
$line:=""
For each ($check; $report.checks)
	Case of 
		: ($check.status="passed")
			$line:=$line+"PASS  "+$check.name
		: ($check.status="skipped")
			$line:=$line+"SKIP  "+$check.name
		Else 
			$line:=$line+"FAIL  "+$check.name
	End case 
	$line:=$line+" — "+String($check.detail)+Char(10)
End for each 
$line:=$line+"summary passed="+String($report.summary.passed)+\
" failed="+String($report.summary.failed)+\
" skipped="+String($report.summary.skipped)+\
" · report "+$path
LOG EVENT(Into system standard outputs; $line)

QUIT 4D
