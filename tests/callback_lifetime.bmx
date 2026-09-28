SuperStrict

Framework SDL3.SDL3Timer
Import SDL3.SDL3Test
Import SDL3.SDL3Gamepad
Import BRL.Hook
Import BRL.StandardIO
Import "test_helpers.bmx"

Global throwController:Int
Global ticks:Int
Global stopOnTick:TTimer
Global throwOnTick:Int
Function observe:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If throwController Then Throw "controller callback failure"
	If event.id = EVENT_TIMERTICK Then
		ticks :+ 1
		If stopOnTick Then StopTimer(stopOnTick)
		If throwOnTick Then Throw "timer callback failure"
	End If
	Return data
End Function
Function lifecycle(data:Object, event:Int)
	Throw "lifecycle callback failure"
End Function
Function expectLifecycleError()
	Local caught:Int
	Try
		PollSystem()
	Catch error:Object
		caught = String(error) = "lifecycle callback failure"
	End Try
	Check caught, "Lifecycle exception was not safely rethrown"
End Function

SetLifecycleCallback(lifecycle)
Check probePushLifecycle(), "Native push must return despite callback exception"
expectLifecycleError()
PollSystem()
Check probePushLifecycleFromThread()
expectLifecycleError()
SetLifecycleCallback(Null)
Check probePushLifecycle(), "Watch did not survive callback exception"
PollSystem()

AddHook(EmitEventHook, observe)
Check Not CreateTimer(0), "Zero frequency accepted"
Check Not CreateTimer(-1), "Negative frequency accepted"
Check Not CreateTimer(1.0e-20), "Out-of-range timer interval accepted"
Local timer:TTimer = CreateTimer(1000)
Check timer
Delay(30)
StopTimer(timer)
PollSystem()
Check ticks = 0 And TimerTicks(timer) = 0, "Stopped timer delivered queued ticks"
StopTimer(timer)
Check WaitTimer(timer) = 0

stopOnTick = CreateTimer(1000)
Check stopOnTick
Delay(30)
PollSystem()
Check ticks = 1, "Stopping in callback did not suppress pending ticks"
stopOnTick = Null

throwOnTick = True
timer = CreateTimer(100)
Check timer
Local caught:Int
Try
	WaitTimer(timer)
Catch error:Object
	caught = String(error) = "timer callback failure"
End Try
StopTimer(timer)
Check caught, "Timer exception was not rethrown after dispatch"
throwOnTick = False
Local before:Int = ticks
timer = CreateTimer(100)
Check WaitTimer(timer) > 0
Check ticks > before, "Native observer dispatcher did not recover"
StopTimer(timer)
For Local gamepad:Int = 0 To 1
	PollSystem()
	throwController = True
	Check probePushController(gamepad)
	caught = False
	Try
		PollSystem()
	Catch error:Object
		caught = String(error) = "controller callback failure"
	End Try
	throwController = False
	Check caught, "Controller callback error did not return safely"
	PollSystem()
Next
RemoveHook(EmitEventHook, observe)
Print "SDL3 callback lifetime test passed"
