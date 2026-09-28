SuperStrict

Framework SDL3.SDL3System
Import SDL3.SDL3Test
Import "test_helpers.bmx"
Import BRL.Event
Import BRL.Hook
Import BRL.StandardIO

Global received:Int[8]
Global receivedCount:Int
Global lifecycleCount:Int
Global lifecycleType:Int

Function lifecycle(data:Object, event:Int)
	lifecycleCount :+ 1
	lifecycleType = event
End Function

Function eventHook:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If receivedCount < received.Length Then
		received[receivedCount] = event.id
		receivedCount :+ 1
	End If
	Return data
End Function

AddHook(EmitEventHook, eventHook)
SetLifecycleCallback(lifecycle)
probeInstall()
Check probePushKey() And probePushMouse() And probePushQuit(), SDL_GetError()
PollSystem()
Check probeCallCount(0) = 3 And probeCallCount(1) = 3, "Native observers missed an event"
Check receivedCount = 2, "Unexpected BlitzMax event count: " + receivedCount
Check received[0] = EVENT_MOUSEMOVE, "Mouse event was not mapped"
Check received[1] = EVENT_APPTERMINATE, "Quit event was not mapped"
probeSetMouseCapture(True)
Check probePushMouse()
PollSystem()
Check receivedCount = 2, "Captured mouse event reached BlitzMax"
probeSetMouseCapture(False)
Check probePushLifecycle(), SDL_GetError()
Check lifecycleCount = 1 And lifecycleType = SDL_EVENT_WILL_ENTER_BACKGROUND, "Lifecycle watch failed"
Check probePushLifecycleFromThread(), SDL_GetError()
Check lifecycleCount = 1, "Lifecycle callback ran on an SDL thread"
PollSystem()
Check lifecycleCount = 2 And lifecycleType = SDL_EVENT_DID_ENTER_FOREGROUND, "Deferred lifecycle delivery failed"
probeInstallSelfRemoving()
Check probePushQuit() And probePushQuit()
PollSystem()
Check probeSelfCallCount() = 1, "Callback removal during dispatch failed"
probeRemove()
Check probePushKey()
PollSystem()
Check received[receivedCount - 1] = EVENT_KEYDOWN, "Uncaptured keyboard event was not mapped"
Print "SDL3 system event test passed"
