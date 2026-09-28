SuperStrict

Framework SDL3.SDL3System
Import SDL3.SDL3Test
Import BRL.Hook
Import BRL.PolledInput
Import BRL.StandardIO
Import "test_helpers.bmx"

Global events:TEvent[128]
Global count:Int
Function hook:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	Check count < events.Length, "Event buffer overflow"
	events[count] = event
	count :+ 1
	Return data
End Function
Function reset()
	count = 0
End Function
Function push(kind:Int, windowID:UInt, amount:Float = 0)
	Check probePushInput(kind, windowID, amount), SDL_GetError()
End Function
AddHook(EmitEventHook, hook)
EnablePolledInput()
SetAutoPoll(False)

For Local i:Int = 0 Until 4
	push(1, 10, 0.25)
Next
PollSystem()
Check count = 5, "Fractional scrolling must emit four detailed events and one legacy step"
Local wheel:TSDLMouseWheelEvent = TSDLMouseWheelEvent(events[0].extra)
Check wheel And wheel.windowID = 10 And wheel.mouseID = 7
Check wheel.x = 0.5 And wheel.y = 0.25 And wheel.direction = 1
Check wheel.mouseX = 12.5 And wheel.mouseY = 34.25
Check events[4].id = EVENT_MOUSEWHEEL And events[4].data = 1
reset()
push(1, 10, -0.75)
push(1, 20, -0.5)
push(1, 10, -0.25)
PollSystem()
Check count = 4 And events[3].data = -1, "Wheel remainders crossed window boundaries"

reset()
push(2, 10)
push(2, 10, 1)
push(3, 10)
push(4, 10)
push(5, 10, 1)
PollSystem()
Check count = 5
Check events[0].data <> events[1].data, "Full-width finger IDs collided"
Check events[0].data = events[2].data And events[0].data = events[3].data
Local touch:TSDLTouchEvent = TSDLTouchEvent(events[3].extra)
Check touch.touchID = $100000001:ULong And touch.fingerID = $200000001:ULong
Check touch.canceled And touch.pressure = 0.5 And touch.dx = 0.125
Check events[3].id = EVENT_TOUCHUP And events[3].x = 2500 And events[3].y = 7500
reset()
probeCaptureAllMouse(True)
push(2, 10)
push(4, 10)
push(1, 10, 1)
PollSystem()
Check count = 0, "Captured touch cancellation or wheel reached BlitzMax"
probeCaptureAllMouse(False)

reset()
push(2, 10)
push(12, 10)
push(8, 10)
PollSystem()
reset()
probeCaptureAllMouse(True)
probeCaptureEditing(True)
push(4, 10)
push(13, 10)
push(9, 10)
PollSystem()
Check count = 3, "Capture swallowed terminal events for previously delivered input"
Check Not KeyDown(KEY_A) And Not MouseDown(1)
probeCaptureAllMouse(False)
probeCaptureEditing(False)

reset()
push(6, 10)
push(8, 10)
push(12, 10)
PollSystem()
Check KeyDown(KEY_A) And MouseDown(1)
Local key:TSDLKeyboardEvent = TSDLKeyboardEvent(events[1].extra)
Check key And key.windowID = 10 And key.keyboardID = 3 And key.scancode = 4
reset()
push(7, 10)
push(6, 20)
PollSystem()
Check Not KeyDown(KEY_A) And Not MouseDown(1), "Focus transfer left held input behind"
For Local event:TEvent = EachIn events[..count]
	Check event.id <> EVENT_APPSUSPEND And event.id <> EVENT_APPRESUME, "Internal window transfer suspended/resumed application"
Next
reset()
push(7, 20)
PollSystem()
Check count = 1 And events[0].id = EVENT_APPSUSPEND
reset()
push(6, 20)
PollSystem()
Check count = 1 And events[0].id = EVENT_APPRESUME

reset()
push(10, 20)
push(11, 20)
PollSystem()
Check count = 3
Local drop:TSDLTextDropEvent = TSDLTextDropEvent(events[0].extra)
Check events[0].id = EVENT_SDL3_TEXT_DROP And drop.windowID = 20
Check drop.text = "caf" + Chr($e9) And drop.x = 4.5 And drop.y = 8.25
Check events[1].id = EVENT_KEYCHAR And events[1].data = $d83d
Check events[2].id = EVENT_KEYCHAR And events[2].data = $de00
Local text:TSDLTextInputEvent = TSDLTextInputEvent(events[1].extra)
Check text.windowID = 20 And text.text.Length = 2 And events[1].extra = events[2].extra
GCCollect()
Check wheel.x = 0.5 And drop.text.Length = 4, "Retained event payload changed"
Print "SDL3 input fidelity test passed"
