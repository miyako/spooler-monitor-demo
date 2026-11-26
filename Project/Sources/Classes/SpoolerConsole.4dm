// View model behind the "Console" form.
//
// The component wrapper (cs.SpoolerMonitor.Queue) is synchronous and runs an
// external process with a 30-second timeout. This class never calls it from the
// form's own process: every call is posted to a persistent worker
// ("spooler-monitor ops") and the worker answers with an evidence envelope
// through CALL FORM. The same `perform`/`apply` pair drives the headless
// self-test, so the form and Demo_SelfTest exercise one code path.

property target : Text
// Deliberately Variant: a literal cs.SpoolerMonitor.Queue reference cannot be
// resolved by tool4d's compiler when the component lives in Components/ (the
// analyzer reports "The class cs.SpoolerMonitor is unknown"). The bracket form
// below resolves at runtime and keeps the project compile-clean; see README
// "Chokepoints" for the evidence.
property tool : Variant
property ready : Boolean

property componentLine : Text
property capabilityLine : Text
property envText : Text
property rulesText : Text

property queues : Collection
property selectedQueue : Object
property selectedPos : Integer
property detailText : Text

property idText : Text
property busy : Boolean
property inflight : Text
property busyText : Text
property requestCount : Integer
property countText : Text

property statusText : Text
property statusBadge : Text
property statusDetail : Text
property decodedText : Text
property mutationText : Text
property factText : Text
property raw : Text
property protocolText : Text
property exitText : Text
property elapsedText : Text

property seq : Integer
property __page : Integer
property __screenshotPath : Text

Class constructor()

	This.target:=""
	If (Is Windows)
		This.target:="Windows-x64"
	Else 
		This.target:="macOS-universal"
	End if 

	This.tool:=Null
	This.ready:=False

	This.componentLine:="spooler-monitor · "+This.target
	This.capabilityLine:="capabilities not read yet"

	This.rulesText:="list()/get() are snapshots — observedAt says when, it is not a live stream."+Char(13)+\
	"acceptingJobs is Boolean or Null. Null means unknown; never show it as false."+Char(13)+\
	"displayName is a label; pause()/resume() take the exact id."+Char(13)+\
	"pause() stops processing, not admission: the queue keeps accepting jobs."+Char(13)+\
	"accepted is not printed: a mutation reports submission plus one follow-up observation."+Char(13)+\
	"Each call is one external process, 30 s timeout, run in a worker — never the UI process."

	This.queues:=New collection()
	This.selectedQueue:=Null
	This.selectedPos:=0
	This.detailText:="Select a queue row, or call get() on an id you type below."
	This.idText:=""
	This.busy:=False
	This.inflight:=""
	This.busyText:="idle"
	This.requestCount:=0
	This.countText:="requests: 0"
	This.statusText:="Not started."
	This.statusBadge:="IDLE"
	This.statusDetail:="One call at a time; the worker reports back through CALL FORM."
	This.decodedText:=""
	This.mutationText:=""
	This.factText:=""
	This.raw:=""
	This.protocolText:="—"
	This.exitText:="—"
	This.elapsedText:="—"
	This.seq:=0
	This.__page:=1
	This.__screenshotPath:=""

	// Last: connect() reports a missing component through statusBadge/statusText,
	// which the defaults above would otherwise overwrite.
	This.connect()
	This.refreshEnv()

// --- wiring -------------------------------------------------------------

Function connect()->$ok : Boolean

	// A missing component must not kill the form: report it instead.
	var $queue : Variant
	$ok:=False
	ON ERR CALL("Demo_IgnoreError"; ek local)
	$queue:=cs["SpoolerMonitor"]["Queue"].new(This.target)
	ON ERR CALL(""; ek local)
	If (Value type($queue)=Is object)
		This.tool:=$queue
		This.ready:=True
		$ok:=True
	Else 
		This.statusBadge:="ERROR"
		This.statusText:="Component unavailable — cs.SpoolerMonitor.Queue is undefined."
		This.statusDetail:="Stage spooler-monitor.4dbase in Components/ (scripts/fetch_dependency.py)."
	End if 
	return $ok

Function refreshEnv()

	var $signature : Text
	$signature:=Choose(Is compiled mode; "compiled"; "interpreted")
	This.envText:="4D "+Application version+" · "+$signature+" · "+Choose(This.ready; "component loaded"; "component missing")

// --- calls --------------------------------------------------------------

// Runs one CLI call synchronously. Callers are the worker (interactive frame)
// and selfTest (headless frame); the form itself never calls this directly.
Function perform($operation : Text; $queueID : Text)->$payload : Object

	var $start : Integer
	var $elapsed : Integer
	var $result : Object
	$start:=Milliseconds

	If (This.tool=Null)
		$result:=New object("ok"; False; "error"; New object("code"; "component_unavailable"; "message"; "cs.SpoolerMonitor.Queue is not loaded"; "outcome"; "not_submitted"))
	Else 
		Case of 
			: ($operation="version")
				$result:=This.tool.version()
			: ($operation="capabilities")
				$result:=This.tool.capabilities()
			: ($operation="list")
				$result:=This.tool.list()
			: ($operation="get")
				$result:=This.tool.get($queueID)
			: ($operation="pause")
				$result:=This.tool.pause($queueID)
			: ($operation="resume")
				$result:=This.tool.resume($queueID)
			Else 
				$result:=New object("ok"; False; "error"; New object("code"; "invalid_argument"; "message"; "unsupported demo operation: "+$operation; "outcome"; "not_submitted"))
		End case 
	End if 

	$elapsed:=Milliseconds-$start
	$payload:=This.envelope($operation; $queueID; $result; $elapsed)
	return $payload

Function envelope($operation : Text; $queueID : Text; $result : Object; $elapsed : Integer)->$payload : Object

	var $error : Object
	$payload:=New object()
	$payload.operation:=$operation
	$payload.id:=$queueID
	$payload.elapsedMs:=$elapsed
	$payload.ok:=($result.ok=True)
	$payload.exitCode:=Null
	$payload.protocol:=Null
	$payload.stdout:=""
	$payload.stderr:=""
	$payload.raw:=""
	$payload.queues:=Null
	$payload.queue:=Null
	$payload.mutation:=Null
	$payload.value:=Null
	$payload.error:=Null
	$payload.launched:=False

	// The component surfaces exitCode as a Real here (JSON-derived numbers are
	// not guaranteed to arrive as Longint), so accept every numeric shape.
	If (This.isNumber($result.exitCode))
		$payload.exitCode:=$result.exitCode
		$payload.launched:=True
	End if 
	If (Value type($result.stdout)=Is text)
		$payload.stdout:=$result.stdout
	End if 
	If (Value type($result.stderr)=Is text)
		$payload.stderr:=$result.stderr
	End if 
	If (Value type($result.value)=Is object)
		$payload.value:=$result.value
		If (This.isNumber($result.value.protocol))
			$payload.protocol:=$result.value.protocol
		End if 
	End if 
	If (Value type($result.queues)=Is collection)
		$payload.queues:=$result.queues
	End if 
	If (Value type($result.queue)=Is object)
		$payload.queue:=$result.queue
	End if 
	If (Value type($result.mutation)=Is object)
		$payload.mutation:=$result.mutation
	End if 

	If (Value type($result.error)=Is object)
		$error:=$result.error
		$payload.error:=New object()
		$payload.error.code:=This.asText($error.code)
		$payload.error.message:=This.asText($error.message)
		$payload.error.backend:=This.asText($error.backend)
		$payload.error.nativeCode:=This.asText($error.nativeCode)
		$payload.error.outcome:=This.asText($error.outcome)
		$payload.error.details:=This.asText($error.details)
	End if 

	If ($payload.ok)
		$payload.raw:=$payload.stdout
	Else 
		If ($payload.stderr#"")
			$payload.raw:=$payload.stderr
		Else 
			$payload.raw:=$payload.stdout
		End if 
	End if 
	return $payload

// Form entry point (On Load). Nothing here calls the component directly: the
// window is already on screen before the first external process starts.
Function start()

	// Already filled (the screenshot endpoint applies a bootstrap before the
	// form opens): do not blank the values again.
	If ((This.busy) | (This.requestCount>0))
		return 
	End if 
	This.statusBadge:="WAIT"
	This.statusText:="Reading version, capabilities and the queue list…"
	This.statusDetail:="One worker call: three CLI processes, ~100 ms"
	This.request("bootstrap"; "")

// Posts one call to the worker. Used by the form only.
Function request($operation : Text; $queueID : Text)

	If (This.busy)
		This.busyText:="ignored "+$operation+" — "+This.inflight+" is still in flight"
		return 
	End if 
	This.seq:=This.seq+1
	This.busy:=True
	This.inflight:=$operation
	This.busyText:="in flight: "+$operation+" · sequence "+String(This.seq)+" · one process, 30 s cap"
	This.statusBadge:="WAIT"
	var $request : Object
	$request:=New object("seq"; This.seq; "op"; $operation; "id"; $queueID; "window"; Current form window)
	CALL WORKER("spooler-monitor ops"; "QueueWorker"; $request)

// Worker callback (via CALL FORM). Applies the envelope and re-enables the UI.
Function receive($payload : Object)

	// Numbers that travel inside an object arrive as Real, not Longint.
	If (This.isNumber($payload.seq))
		If ($payload.seq<This.seq)
			return 
		End if 
	End if 
	This.apply($payload)
	This.busy:=False
	This.inflight:=""
	This.busyText:="idle"

// --- applying envelopes -------------------------------------------------

Function apply($payload : Object)

	This.requestCount:=This.requestCount+1
	This.countText:="requests: "+String(This.requestCount)
	This.raw:=This.asText($payload.raw)
	This.protocolText:=This.protocolLabel($payload)
	This.exitText:=This.exitLabel($payload)
	This.elapsedText:=String($payload.elapsedMs)+" ms"
	This.factText:="measured "+This.elapsedText+" · exit "+This.exitText+" · protocol "+This.protocolText
	This.decodedText:=This.describe($payload)
	This.mutationText:=This.describeMutation($payload)
	This.statusDetail:=This.factText

	If ($payload.operation="bootstrap")
		This.applyBootstrap($payload)
		return 
	End if 
	If (Not($payload.ok))
		This.applyFailure($payload)
		return 
	End if 
	Case of 
		: ($payload.operation="list")
			This.applyList($payload)
		: ($payload.operation="get")
			This.applyQueue($payload; "get")
		: (($payload.operation="pause") | ($payload.operation="resume"))
			This.applyQueue($payload; $payload.operation)
		: ($payload.operation="version")
			This.statusBadge:="OK"
			This.statusText:="version → "+This.asText($payload.value.version)
		: ($payload.operation="capabilities")
			This.applyCapabilities($payload)
	End case 

// One worker call that reads all three read-only surfaces. Keeps the first
// paint honest: the window opens before any process is launched.
Function bootstrap()->$payload : Object

	var $version; $capabilities; $list : Object
	var $start : Integer
	var $elapsed : Integer
	$start:=Milliseconds
	$version:=This.perform("version"; "")
	$capabilities:=This.perform("capabilities"; "")
	$list:=This.perform("list"; "")
	$elapsed:=Milliseconds-$start
	$payload:=New object()
	$payload.operation:="bootstrap"
	$payload.ok:=$list.ok
	$payload.elapsedMs:=$elapsed
	$payload.version:=$version
	$payload.capabilities:=$capabilities
	$payload.list:=$list
	return $payload

Function applyBootstrap($payload : Object)

	var $version; $capabilities; $list : Object
	$version:=$payload.version
	$capabilities:=$payload.capabilities
	$list:=$payload.list
	// The envelope panel speaks for the list call: it is the one whose payload
	// the form shows. The total wall time covers all three processes.
	This.raw:=This.asText($list.raw)
	This.exitText:=This.exitLabel($list)
	This.protocolText:=This.protocolLabel($list)
	This.factText:="3 calls measured "+String($payload.elapsedMs)+" ms · last exit "+This.exitText+" · protocol "+This.protocolText
	This.decodedText:="decoded: version + capabilities + list"
	If ($version.ok)
		This.componentLine:="spooler-monitor "+This.asText($version.value.version)+" · "+This.target+" · protocol "+This.asText($version.value.protocol)
	End if 
	If ($capabilities.ok)
		This.applyCapabilities($capabilities)
	End if 
	If ($list.ok)
		This.applyList($list)
	Else 
		This.applyFailure($list)
	End if 

Function applyCapabilities($payload : Object)

	var $operations : Text
	$operations:=""
	If (Value type($payload.value.operations)=Is collection)
		$operations:=$payload.value.operations.join(", ")
	End if 
	This.capabilityLine:="backend "+This.asText($payload.value.backend)+" · "+$operations+" · mutationPolicy "+This.asText($payload.value.mutationPolicy)
	This.statusBadge:="OK"
	This.statusText:="capabilities → "+This.asText($payload.value.backend)+" · "+$operations
	This.statusDetail:="mutationPolicy "+This.asText($payload.value.mutationPolicy)+" · "+This.factText

Function applyList($payload : Object)

	This.queues:=New collection()
	If (Value type($payload.queues)=Is collection)
		var $queue : Object
		For each ($queue; $payload.queues)
			This.queues.push(This.rowFor($queue))
		End for each 
	End if 
	If (This.queues.length>0)
		If ((This.selectedPos<1) | (This.selectedPos>This.queues.length))
			This.selectRow(1; False)
		Else 
			This.selectRow(This.selectedPos; False)
		End if 
	End if 
	If (This.queues.length=0)
		This.selectedQueue:=Null
		This.selectedPos:=0
		This.detailText:="No queues are configured on this machine — list() returned an empty collection, which is a successful answer."+Char(13)+Char(13)+"Type any id below and press get to see the error protocol, or stage a scratch queue with scripts/demo_queue.py. Select a row here when real printers exist."
	End if 
	This.statusBadge:="OK"
	This.statusText:="list → "+String(This.queues.length)+" queue(s)"
	This.statusDetail:="snapshot taken now · "+This.factText

Function applyQueue($payload : Object; $operation : Text)

	If (Value type($payload.queue)#Is object)
		This.applyFailure($payload)
		return 
	End if 
	var $row : Object
	$row:=This.rowFor($payload.queue)
	var $i : Integer
	$i:=This.indexOfQueue($row.id)
	If ($i>0)
		This.queues[$i-1]:=$row
		This.selectedPos:=$i
	Else 
		This.queues.push($row)
		This.selectedPos:=This.queues.length
	End if 
	This.selectedQueue:=This.queues[This.selectedPos-1]
	This.detailText:=This.describeQueue($payload.queue)
	This.idText:=This.asText($payload.queue.id)
	This.statusBadge:="OK"
	If ($operation="get")
		This.statusText:="get → "+This.asText($payload.queue.id)+" · "+This.asText($payload.queue.state)
	Else 
		This.statusText:=$operation+" → "+This.mutationOutcome($payload)
	End if 
	This.statusDetail:="observed "+This.asText($payload.queue.observedAt)+" · "+This.factText

Function applyFailure($payload : Object)

	This.statusBadge:="ERROR"
	If (Value type($payload.error)=Is object)
		This.statusText:=$payload.error.code+" — "+$payload.error.message
		This.statusDetail:=This.factText+" · outcome "+$payload.error.outcome
	Else 
		This.statusText:="failed without a decoded error"
		This.statusDetail:=This.factText
	End if 

// --- formatting ---------------------------------------------------------

Function describe($payload : Object)->$text : Text

	If (Not($payload.ok))
		If (Value type($payload.error)=Is object)
			$text:="decoded: "+$payload.error.code+" · outcome "+$payload.error.outcome+" · backend "+Choose($payload.error.backend=""; "—"; $payload.error.backend)
		Else 
			$text:="decoded: no structured error"
		End if 
		return $text
	End if 
	Case of 
		: ($payload.operation="list")
			$text:="decoded: ok · queues["+String($payload.queues.length)+"]"
		: ($payload.operation="get")
			$text:="decoded: ok · "+This.asText($payload.queue.id)+" · "+This.asText($payload.queue.state)
		: ($payload.operation="pause") | ($payload.operation="resume")
			$text:="decoded: mutation accepted="+This.booleanLabel($payload.mutation.accepted)+" · observation "+This.asText($payload.mutation.observation)+" · state "+This.asText($payload.queue.state)
		: ($payload.operation="version")
			$text:="decoded: ok · version "+This.asText($payload.value.version)
		: ($payload.operation="capabilities")
			$text:="decoded: ok · backend "+This.asText($payload.value.backend)
		Else 
			$text:="decoded: ok"
	End case 
	return $text

Function describeMutation($payload : Object)->$text : Text

	If (Value type($payload.mutation)#Is object)
		return ""
	End if 
	var $line : Text
	$line:="accepted="+This.booleanLabel($payload.mutation.accepted)+\
	" · outcome="+This.asText($payload.mutation.outcome)+\
	" · observation="+This.asText($payload.mutation.observation)+\
	" · error="+Choose(Value type($payload.mutation.error)=Is object; This.asText($payload.mutation.error.code); "null")
	return $line

Function mutationOutcome($payload : Object)->$text : Text

	If (Value type($payload.mutation)=Is object)
		If ($payload.mutation.accepted=True)
			return "accepted · observed "+This.asText($payload.queue.state)
		End if 
		return This.asText($payload.mutation.outcome)
	End if 
	return This.asText($payload.queue.state)

Function rowFor($queue : Object)->$row : Object

	$row:=OB Copy($queue)
	$row.stateLabel:=This.asText($queue.state)
	$row.jobsLabel:=This.nullLabel($queue.jobCount)
	$row.acceptingLabel:=This.nullLabel($queue.acceptingJobs)
	$row.reasonsLabel:=This.reasonsLabel($queue.reasons)
	$row.shortTime:=This.asText($queue.observedAt)
	return $row

Function describeQueue($queue : Object)->$text : Text

	var $lines : Collection
	$lines:=New collection()
	$lines.push(This.padPair("id"; This.asText($queue.id)))
	$lines.push(This.padPair("displayName"; This.asText($queue.displayName)))
	$lines.push(This.padPair("backend"; This.asText($queue.backend)))
	$lines.push(This.padPair("state"; This.asText($queue.state)))
	$lines.push(This.padPair("acceptingJobs"; This.nullLabel($queue.acceptingJobs)))
	$lines.push(This.padPair("jobCount"; This.nullLabel($queue.jobCount)))
	$lines.push(This.padPair("reasons"; This.reasonsLabel($queue.reasons)))
	$lines.push(This.padPair("message"; Choose(This.asText($queue.message)=""; "— (empty)"; This.asText($queue.message))))
	$lines.push(This.padPair("observedAt"; This.asText($queue.observedAt)))
	$lines.push("")
	If (Value type($queue.raw)=Is object)
		$lines.push(This.padPair("raw.state"; This.asText($queue.raw["printer-state"])))
		$lines.push(This.padPair("raw.reasons"; This.reasonsLabel($queue.raw["printer-state-reasons"])))
	End if 
	return $lines.join(Char(13))

Function padPair($name : Text; $value : Text)->$line : Text

	var $keys : Text
	$keys:=$name
	While (Length($keys)<16)
		$keys:=$keys+" "
	End while 
	$line:=$keys+$value

Function nullLabel($value : Variant)->$text : Text

	Case of 
		: (Value type($value)=Is null)
			return "null → unknown"
		: (Value type($value)=Is boolean)
			return Choose($value; "yes"; "no")
		: ((Value type($value)=Is real) | (Value type($value)=Is longint))
			return String($value)
		Else 
			$text:=This.asText($value)
			If ($text="")
				$text:="— (empty)"
			End if 
	End case 
	return $text

Function reasonsLabel($reasons : Variant)->$text : Text

	If (Value type($reasons)=Is collection)
		If ($reasons.length=0)
			return "[]"
		End if 
		return $reasons.join(", ")
	End if 
	If (Value type($reasons)=Is null)
		return "null → unknown"
	End if 
	return This.asText($reasons)

Function booleanLabel($value : Variant)->$text : Text

	Case of 
		: (Value type($value)=Is boolean)
			return Choose($value; "true"; "false")
		: (Value type($value)=Is null)
			return "null"
		Else 
			return "—"
	End case 

Function isNumber($value : Variant)->$is : Boolean

	$is:=(Value type($value)=Is real) | (Value type($value)=Is longint) | (Value type($value)=Is integer)

Function exitLabel($payload : Object)->$text : Text

	// "no process" only when nothing was launched; a launched process has a
	// real exit code, zero included.
	If (($payload.launched=True) & (This.isNumber($payload.exitCode)))
		$text:=String($payload.exitCode)
	Else 
		$text:="no process"
	End if 

Function protocolLabel($payload : Object)->$text : Text

	If (This.isNumber($payload.protocol))
		$text:=String($payload.protocol)
	Else 
		$text:="—"
	End if 

Function asText($value : Variant)->$text : Text

	Case of 
		: (Value type($value)=Is text)
			return $value
		: (Value type($value)=Is null)
			return ""
		: (Value type($value)=Is collection) | (Value type($value)=Is object)
			return JSON Stringify($value; *)
		Else 
			return String($value)
	End case 
	return ""

// --- selection and actions ---------------------------------------------

Function selectRow($position : Integer; $issueGet : Boolean)

	If (($position<1) | ($position>This.queues.length))
		return 
	End if 
	This.selectedPos:=$position
	This.selectedQueue:=This.queues[$position-1]
	This.detailText:=This.describeQueue(This.selectedQueue)
	This.idText:=This.asText(This.selectedQueue.id)
	If ($issueGet)
		This.request("get"; This.idText)
	End if 

Function selectCurrent()

	If (This.selectedPos<1)
		This.statusBadge:="IDLE"
		This.statusText:="No row selected — click a queue first."
		return 
	End if 
	This.selectRow(This.selectedPos; True)

Function inspectTyped()

	If (This.busy)
		This.busyText:="ignored get — "+This.inflight+" is still in flight"
		return 
	End if 
	If (This.idText="")
		This.statusBadge:="IDLE"
		This.statusText:="Type a queue id or select a row first."
		return 
	End if 
	This.request("get"; This.idText)

// Explicit-only: never called from On Load, On Timer or a list event, and the
// caller asks the human for confirmation before it reaches this method.
Function confirmMutation($operation : Text)

	If (This.busy)
		This.statusBadge:="WAIT"
		This.statusText:="One call at a time — "+This.inflight+" is still in flight."
		This.statusDetail:="Click again when the worker is idle."
		return 
	End if 
	If (This.idText="")
		This.statusBadge:="IDLE"
		This.statusText:="Choose a queue id first (select a row or type one)."
		return 
	End if 
	var $verb : Text
	$verb:=Choose($operation="pause"; "Pause processing for"; "Resume processing for")
	// CONFIRM is a procedure, not a function: it reports the choice in OK, and its
	// optional parameters are the OK then the Cancel button titles.
	CONFIRM($verb+" “"+This.idText+"”?"+Char(13)+Char(13)+\
	"This sends an explicit mutation for that exact id and changes the real print queue on this machine."+Char(13)+\
	"Nothing is sent unless you confirm."; Choose($operation="pause"; "Pause"; "Resume"); "Cancel")
	If (OK#1)
		This.statusBadge:="IDLE"
		This.statusText:="Cancelled — no "+$operation+" was sent."
		This.statusDetail:="outcome not_submitted · nothing left this process"
		return 
	End if 
	This.request($operation; This.idText)

// Deliberately wrong inputs. Both are decided by the component *before* any
// process is launched, which is why they carry no exitCode.
Function tryInvalid()

	This.request("get"; "bad"+Char(9)+"id")

Function tryUnknown()

	This.request("get"; "spooler-monitor-demo-no-such-queue")

Function copyRaw()

	If (This.raw="")
		This.statusBadge:="IDLE"
		This.statusText:="Nothing to copy yet — make a call first."
		return 
	End if 
	SET TEXT TO PASTEBOARD(This.raw)
	This.statusBadge:="OK"
	This.statusText:="Copied "+String(Length(This.raw))+" characters from the last raw envelope."

// --- headless -----------------------------------------------------------

// Read-only by default. A mutation runs only when the caller names a queue
// explicitly, so this method can never pause a real printer by surprise.
Function selfTest($options : Object)->$report : Object

	var $checks : Collection
	var $target; $mutate : Text
	$checks:=New collection()
	// The report describes the component it actually talked to, not the form.
	$mutate:=""
	If (Value type($options.queue)=Is text)
		$mutate:=$options.queue
	End if 

	var $version : Object
	$version:=This.perform("version"; "")
	var $versionOK : Boolean
	$versionOK:=False
	If ($version.ok)
		$versionOK:=(This.asText($version.value.version)="0.1.1") & (This.asText($version.value.protocol)="1")
	End if 
	$checks.push(This.check("version reads 0.1.1 with protocol 1"; $version; $versionOK))

	var $capabilities : Object
	$capabilities:=This.perform("capabilities"; "")
	var $operations : Text
	var $capabilitiesOK : Boolean
	$operations:=""
	$capabilitiesOK:=False
	If ($capabilities.ok)
		$operations:=$capabilities.value.operations.join(",")
		$capabilitiesOK:=((This.asText($capabilities.value.backend)="cups") | (This.asText($capabilities.value.backend)="winspool")) & \
		($operations="list,get,pause,resume") & (This.asText($capabilities.value.mutationPolicy)="explicit-only")
	End if 
	$checks.push(This.check("capabilities name backend, operations, explicit-only policy"; $capabilities; $capabilitiesOK))
	If ($version.ok)
		This.componentLine:="spooler-monitor "+This.asText($version.value.version)+\
		" · "+This.target+" · protocol "+This.asText($version.value.protocol)
	End if 
	If ($capabilitiesOK)
		This.applyCapabilities($capabilities)
	End if 

	var $list : Object
	$list:=This.perform("list"; "")
	var $listOK; $hasQueues : Boolean
	var $first : Text
	$first:=""
	$listOK:=($list.ok) & (Value type($list.queues)=Is collection)
	$hasQueues:=False
	If ($list.ok)
		If (Value type($list.queues)=Is collection)
			If ($list.queues.length>0)
				$hasQueues:=True
				$first:=This.asText($list.queues[0].id)
			End if 
		End if 
	End if 
	$checks.push(This.check("list returns a queue collection"; $list; $listOK))

	var $unknown : Object
	$unknown:=This.perform("get"; "spooler-monitor-demo-no-such-queue")
	var $unknownOK : Boolean
	$unknownOK:=(Not($unknown.ok)) & (This.errorCode($unknown)="unknown_queue") & \
	(This.asText($unknown.exitCode)="3") & (This.errorOutcome($unknown)="not_submitted")
	$checks.push(This.check("unknown queue is unknown_queue, exit 3, not_submitted"; $unknown; $unknownOK))

	var $invalid : Object
	$invalid:=This.perform("get"; "bad"+Char(9)+"id")
	var $invalidOK : Boolean
	$invalidOK:=(Not($invalid.ok)) & (This.errorCode($invalid)="invalid_argument") & (Not($invalid.launched))
	$checks.push(This.check("invalid id is rejected locally, before any process"; $invalid; $invalidOK))

	var $wrong : Object
	$wrong:=This.wrongTargetCall()
	var $wrongOK : Boolean
	$wrongOK:=(Not($wrong.ok)) & (This.errorCode($wrong)="unsupported_architecture") & (Not($wrong.launched))
	$checks.push(This.check("a foreign target is refused before launch"; $wrong; $wrongOK))

	If ($hasQueues)
		var $get : Object
		$get:=This.perform("get"; $first)
		var $getOK : Boolean
		$getOK:=False
		If ($get.ok)
			$getOK:=(This.asText($get.queue.id)=$first) & (This.asText($get.queue.observedAt)#"")
		End if 
		$checks.push(This.check("get returns the same id with an observation time"; $get; $getOK))
	Else 
		$checks.push(New object("name"; "get returns the same id with an observation time"; "status"; "skipped"; "detail"; "no queue exists to read"))
	End if 

	If ($mutate#"")
		var $pause; $resume : Object
		var $pauseOK; $resumeOK : Boolean
		$pause:=This.perform("pause"; $mutate)
		$pauseOK:=False
		If ($pause.ok)
			$pauseOK:=($pause.mutation.accepted=True) & (This.asText($pause.mutation.observation)="succeeded") & (This.asText($pause.queue.state)="stopped")
		End if 
		$checks.push(This.check("pause is accepted and observed as stopped"; $pause; $pauseOK))
		$resume:=This.perform("resume"; $mutate)
		$resumeOK:=False
		If ($resume.ok)
			$resumeOK:=($resume.mutation.accepted=True) & (This.asText($resume.queue.state)="idle")
		End if 
		$checks.push(This.check("resume is accepted and observed as idle"; $resume; $resumeOK))
	Else 
		$checks.push(New object("name"; "pause/resume are explicit-only"; "status"; "skipped"; "detail"; "no queue named; the demo never mutates a queue on its own"))
	End if 

	var $passed; $failed; $skipped : Integer
	$passed:=0
	$failed:=0
	$skipped:=0
	var $check : Object
	For each ($check; $checks)
		Case of 
			: ($check.status="passed")
				$passed:=$passed+1
			: ($check.status="failed")
				$failed:=$failed+1
			: ($check.status="skipped")
				$skipped:=$skipped+1
		End case 
	End for each 

	$report:=New object()
	$report.component:="spooler-monitor"
	$report.demo:="spooler-monitor-demo"
	$report.target:=This.target
	$report.componentLine:=This.componentLine
	$report.capabilityLine:=This.capabilityLine
	$report.envText:=This.envText
	$report.queueCount:=0
	If ($list.ok) & (Value type($list.queues)=Is collection)
		$report.queueCount:=$list.queues.length
	End if 
	$report.queueIDs:=New collection()
	If ($list.ok) & (Value type($list.queues)=Is collection)
		$report.queueIDs:=$list.queues.extract("id")
	End if 
	$report.checks:=$checks
	$report.summary:=New object("passed"; $passed; "failed"; $failed; "skipped"; $skipped)
	$report.finished:=True
	return $report

Function wrongTargetCall()->$payload : Object

	var $foreign : Text
	$foreign:=Choose(Is Windows; "macOS-universal"; "Windows-x64")
	var $start : Integer
	var $elapsed : Integer
	var $tool; $result : Variant
	$start:=Milliseconds
	ON ERR CALL("Demo_IgnoreError"; ek local)
	$tool:=cs["SpoolerMonitor"]["Queue"].new($foreign)
	$result:=$tool.list()
	ON ERR CALL(""; ek local)
	$elapsed:=Milliseconds-$start
	If (Value type($result)#Is object)
		$result:=New object("ok"; False; "error"; New object("code"; "component_unavailable"; "message"; "the component class is not loaded"; "outcome"; "not_submitted"))
	End if 
	$payload:=This.envelope("list"; ""; $result; $elapsed)
	return $payload

Function check($name : Text; $payload : Object; $passed : Boolean)->$check : Object

	$check:=New object()
	$check.name:=$name
	$check.status:=Choose($passed; "passed"; "failed")
	$check.operation:=$payload.operation
	$check.ok:=$payload.ok
	$check.exitCode:=$payload.exitCode
	$check.launched:=$payload.launched
	$check.elapsedMs:=$payload.elapsedMs
	If (Value type($payload.error)=Is object)
		$check.errorCode:=$payload.error.code
		$check.errorOutcome:=$payload.error.outcome
	End if 
	$check.detail:=This.describe($payload)
	return $check

Function errorCode($payload : Object)->$code : Text

	If (Value type($payload.error)=Is object)
		return $payload.error.code
	End if 
	return ""

Function errorOutcome($payload : Object)->$outcome : Text

	If (Value type($payload.error)=Is object)
		return $payload.error.outcome
	End if 
	return ""

Function indexOfQueue($queueID : Text)->$position : Integer

	var $i : Integer
	$position:=0
	For ($i; 1; This.queues.length)
		If (This.asText(This.queues[$i-1].id)=$queueID)
			$position:=$i
			return $position
		End if 
	End for 
	return $position
