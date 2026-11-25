//%attributes = {"invisible":true}
// Persistent worker that owns every component call for the Console form.
// One request at a time; the answer goes back through CALL FORM so the UI
// process never blocks on the external spooler-monitor process.

#DECLARE($request : Object)

var $console : cs.SpoolerConsole
var $payload : Object

// Fallback: if the call raises a 4D error, the form must not stay "busy".
$payload:=New object(\
"operation"; String($request.op); \
"id"; String($request.id); \
"seq"; $request.seq; \
"ok"; False; \
"elapsedMs"; 0; \
"launched"; False; \
"exitCode"; Null; \
"protocol"; Null; \
"raw"; ""; \
"error"; New object("code"; "demo_exception"; "message"; "the worker raised a 4D error; see /tmp/spooler-console-error.log"; "outcome"; "uncertain"))

ON ERR CALL("Demo_LogError"; ek local)

$console:=cs.SpoolerConsole.new()
If (String($request.op)="bootstrap")
	$payload:=$console.bootstrap()
Else 
	$payload:=$console.perform(String($request.op); String($request.id))
End if 
$payload.seq:=$request.seq

ON ERR CALL(""; ek local)

CALL FORM($request.window; Formula(Form.receive($1)); $payload)
