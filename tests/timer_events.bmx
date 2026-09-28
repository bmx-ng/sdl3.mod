SuperStrict

Framework SDL3.SDL3Timer
Import "test_helpers.bmx"
Import BRL.System
Import BRL.StandardIO
Import BRL.Hook

Global tickEvents:Int
Function observe:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If event.id = EVENT_TIMERTICK Then tickEvents :+ 1
	Return data
End Function

AddHook(EmitEventHook, observe)
Local timer:TTimer = CreateTimer(40)
Check timer, SDL_GetError()
Check WaitTimer(timer) > 0
Check TimerTicks(timer) > 0
Check tickEvents > 0
StopTimer(timer)
Print "SDL3 timer event test passed"
