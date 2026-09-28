SuperStrict

Framework SDL3.SDL3Gamepad
Import Pub.Joystick
Import BRL.Event
Import BRL.Hook
Import BRL.StandardIO
Import "test_helpers.bmx"

Global deviceID:UInt
Global joystickAdded:Int
Global joystickRemoved:Int
Global joystickAxis:Int
Global joystickButtonDown:Int
Global joystickButtonUp:Int
Global gamepadAdded:Int
Global gamepadRemoved:Int
Global gamepadAxis:Int
Global gamepadButtonDown:Int
Global gamepadButtonUp:Int

Function eventHook:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If UInt(event.data) <> deviceID Then Return data
	Select event.id
		Case EVENT_SDL3_JOYSTICK_ADDED
			joystickAdded :+ 1
		Case EVENT_SDL3_JOYSTICK_REMOVED
			joystickRemoved :+ 1
		Case EVENT_SDL3_JOYSTICK_AXIS
			If event.mods = 0 Then joystickAxis :+ 1
		Case EVENT_SDL3_JOYSTICK_BUTTON_DOWN
			If event.mods = 0 Then joystickButtonDown :+ 1
		Case EVENT_SDL3_JOYSTICK_BUTTON_UP
			If event.mods = 0 Then joystickButtonUp :+ 1
		Case EVENT_SDL3_GAMEPAD_ADDED
			gamepadAdded :+ 1
		Case EVENT_SDL3_GAMEPAD_REMOVED
			gamepadRemoved :+ 1
		Case EVENT_SDL3_GAMEPAD_AXIS
			If event.mods = SDL_GAMEPAD_AXIS_LEFTX Then gamepadAxis :+ 1
		Case EVENT_SDL3_GAMEPAD_BUTTON_DOWN
			If event.mods = SDL_GAMEPAD_BUTTON_SOUTH Then gamepadButtonDown :+ 1
		Case EVENT_SDL3_GAMEPAD_BUTTON_UP
			If event.mods = SDL_GAMEPAD_BUTTON_SOUTH Then gamepadButtonUp :+ 1
	End Select
	Return data
End Function

Function HasID:Int(ids:UInt[], id:UInt)
	For Local value:UInt = EachIn ids
		If value = id Then Return True
	Next
	Return False
End Function

AddHook(EmitEventHook, eventHook)
Local device:TSDLVirtualJoystick = TSDLVirtualJoystick.Create("SDL3 virtual test", 6, 15, 1)
Check device, SDL_GetError()
deviceID = device.id
PollSystem()
Check HasID(SDLJoystickIDs(), deviceID), "Virtual joystick was not enumerated"
Check HasID(SDLGamepadIDs(), deviceID), "Virtual gamepad was not enumerated"
Check SDLIsGamepad(deviceID), "Virtual joystick is not a gamepad"
Check joystickAdded > 0 And gamepadAdded > 0, "Device-added events were not emitted"

Local port:Int = -1
For Local index:Int = 0 Until JoyCount()
	If SDLJoystickIDAt(index) = deviceID Then port = index
Next
Check port >= 0, "Pub.Joystick did not enumerate the virtual joystick"
Check JoyName(port) = "SDL3 virtual test", "Pub.Joystick name differs"
Check (JoyAxisCaps(port) & (1 Shl JOY_X)) <> 0, "X axis capability is missing"
Check (JoyAxisCaps(port) & (1 Shl JOY_HAT)) <> 0, "Hat capability is missing"
Check (JoyButtonCaps(port) & 1) <> 0, "Button capability is missing"

Local joystick:TSDLJoystick = TSDLJoystick.Open(deviceID)
Local gamepad:TSDLGamepad = TSDLGamepad.Open(deviceID)
Check joystick And gamepad, SDL_GetError()
Check joystick.ID() = deviceID And gamepad.ID() = deviceID, "Opened device ID differs"
Check joystick.Connected() And gamepad.Connected(), "Virtual device is disconnected"
Check gamepad.Mapping().Length > 0, "Virtual gamepad has no mapping"
Check device.SetAxis(0, 16384), SDL_GetError()
Check device.SetButton(0, True), SDL_GetError()
Check device.SetHat(0, SDL_HAT_UP | SDL_HAT_RIGHT), SDL_GetError()
PollSystem()
Check joystick.Axis(0) = 16384, "Joystick axis was not updated"
Check joystick.Button(0), "Joystick button was not updated"
Check joystick.Hat(0) = (SDL_HAT_UP | SDL_HAT_RIGHT), "Joystick hat was not updated"
Check JoyX(port) > 0.49 And JoyX(port) < 0.51, "Pub.Joystick axis differs"
Check JoyDown(0, port), "Pub.Joystick button is not down"
Check JoyHit(0, port) = 1 And JoyHit(0, port) = 0, "Pub.Joystick hit count differs"
Check JoyHat(port) = 0.125, "Pub.Joystick hat differs"
Check gamepad.Axis(SDL_GAMEPAD_AXIS_LEFTX) = 16384, "Gamepad axis was not updated"
Check gamepad.Button(SDL_GAMEPAD_BUTTON_SOUTH), "Gamepad button was not updated"
Check joystickAxis > 0 And joystickButtonDown > 0, "Joystick input events were not emitted"
Check gamepadAxis > 0 And gamepadButtonDown > 0, "Gamepad input events were not emitted"

Check device.SetButton(0, False), SDL_GetError()
PollSystem()
Check Not JoyDown(0, port) And Not gamepad.Button(SDL_GAMEPAD_BUTTON_SOUTH), "Button release was not observed"
Check joystickButtonUp > 0 And gamepadButtonUp > 0, "Button-up events were not emitted"
Check device.SetButton(0, True), SDL_GetError()
PollSystem()
FlushJoy(1 Shl port)
Check JoyHit(0, port) = 0, "FlushJoy did not clear hit counts"
joystick.Close()
gamepad.Close()
device.Detach()
PollSystem()
Check Not HasID(SDLJoystickIDs(), deviceID), "Detached joystick remains enumerated"
Check Not HasID(SDLGamepadIDs(), deviceID), "Detached gamepad remains enumerated"
Check joystickRemoved > 0 And gamepadRemoved > 0, "Device-removed events were not emitted"
Print "SDL3 joystick and gamepad test passed"
