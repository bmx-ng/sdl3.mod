SuperStrict

Module SDL3.SDL3Joystick
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3System
Import Pub.Joystick
Import Collections.IntMap
Import BRL.Event
Import "glue.c"

Const SDL_JOYSTICK_TYPE_UNKNOWN:Int = 0
Const SDL_JOYSTICK_TYPE_GAMEPAD:Int = 1
Const SDL_HAT_CENTERED:Int = 0
Const SDL_HAT_UP:Int = 1
Const SDL_HAT_RIGHT:Int = 2
Const SDL_HAT_DOWN:Int = 4
Const SDL_HAT_LEFT:Int = 8

Const SDL_EVENT_JOYSTICK_AXIS_MOTION:Int = $600
Const SDL_EVENT_JOYSTICK_HAT_MOTION:Int = $602
Const SDL_EVENT_JOYSTICK_BUTTON_DOWN:Int = $603
Const SDL_EVENT_JOYSTICK_BUTTON_UP:Int = $604
Const SDL_EVENT_JOYSTICK_ADDED:Int = $605
Const SDL_EVENT_JOYSTICK_REMOVED:Int = $606

' Event data is the instance ID, mods is the axis/button/hat index, x is its value.
Global EVENT_SDL3_JOYSTICK_ADDED:Int = AllocUserEventId("SDL3 joystick added")
Global EVENT_SDL3_JOYSTICK_REMOVED:Int = AllocUserEventId("SDL3 joystick removed")
Global EVENT_SDL3_JOYSTICK_AXIS:Int = AllocUserEventId("SDL3 joystick axis")
Global EVENT_SDL3_JOYSTICK_HAT:Int = AllocUserEventId("SDL3 joystick hat")
Global EVENT_SDL3_JOYSTICK_BUTTON_DOWN:Int = AllocUserEventId("SDL3 joystick button down")
Global EVENT_SDL3_JOYSTICK_BUTTON_UP:Int = AllocUserEventId("SDL3 joystick button up")

Function SDLJoystickIDs:UInt[]()
	Local count:Int = bmx_SDL3_CopyJoystickIDs(Null, 0)
	Local ids:UInt[count]
	If count Then
		Local copied:Int = bmx_SDL3_CopyJoystickIDs(ids, count)
		If copied < count Then Return ids[..copied]
	End If
	Return ids
End Function

Function SDLJoystickIDAt:UInt(port:Int)
	Local ids:UInt[] = SDLJoystickIDs()
	If port < 0 Or port >= ids.Length Then Return 0
	Return ids[port]
End Function

Type TSDLJoystick
	Field joystickPtr:Byte Ptr

	Function Open:TSDLJoystick(id:UInt)
		If Not id Then Return Null
		Local ptr:Byte Ptr = SDL_OpenJoystick(id)
		If Not ptr Then Return Null
		Local joystick:TSDLJoystick = New TSDLJoystick
		joystick.joystickPtr = ptr
		Return joystick
	End Function

	Method ID:UInt()
		If joystickPtr Then Return SDL_GetJoystickID(joystickPtr)
	End Method

	Method Name:String()
		If joystickPtr Then Return bmx_SDL3_JoystickName(joystickPtr)
		Return ""
	End Method

	Method Connected:Int()
		If joystickPtr Then Return bmx_SDL3_JoystickConnected(joystickPtr)
	End Method

	Method AxisCount:Int()
		If joystickPtr Then Return SDL_GetNumJoystickAxes(joystickPtr)
	End Method

	Method ButtonCount:Int()
		If joystickPtr Then Return SDL_GetNumJoystickButtons(joystickPtr)
	End Method

	Method HatCount:Int()
		If joystickPtr Then Return SDL_GetNumJoystickHats(joystickPtr)
	End Method

	Method Axis:Int(axis:Int)
		If joystickPtr Then Return bmx_SDL3_GetJoystickAxis(joystickPtr, axis)
	End Method

	Method Button:Int(button:Int)
		If joystickPtr Then Return bmx_SDL3_GetJoystickButton(joystickPtr, button)
	End Method

	Method Hat:Int(hat:Int = 0)
		If joystickPtr Then Return bmx_SDL3_GetJoystickHat(joystickPtr, hat)
	End Method

	Method Close()
		If joystickPtr Then
			SDL_CloseJoystick(joystickPtr)
			joystickPtr = Null
		End If
	End Method

	Method Delete()
		Close()
	End Method
End Type

Type TSDLVirtualJoystick
	Field id:UInt
	Field joystick:TSDLJoystick

	Function Create:TSDLVirtualJoystick(name:String, axes:Int, buttons:Int, hats:Int = 0, joystickType:Int = SDL_JOYSTICK_TYPE_GAMEPAD)
		If axes < 0 Or axes > 65535 Or buttons < 0 Or buttons > 65535 Or hats < 0 Or hats > 65535 Then Return Null
		Local id:UInt = bmx_SDL3_AttachVirtualJoystick(name, joystickType, axes, buttons, hats)
		If Not id Then Return Null
		Local device:TSDLVirtualJoystick = New TSDLVirtualJoystick
		device.id = id
		device.joystick = TSDLJoystick.Open(id)
		If Not device.joystick Then
			bmx_SDL3_DetachVirtualJoystick(id)
			Return Null
		End If
		Return device
	End Function

	Method SetAxis:Int(axis:Int, value:Int)
		If Not joystick Or Not joystick.joystickPtr Then Return 0
		If value < -32768 Then value = -32768
		If value > 32767 Then value = 32767
		Return bmx_SDL3_SetVirtualAxis(joystick.joystickPtr, axis, value)
	End Method

	Method SetButton:Int(button:Int, down:Int)
		If Not joystick Or Not joystick.joystickPtr Then Return 0
		Return bmx_SDL3_SetVirtualButton(joystick.joystickPtr, button, down)
	End Method

	Method SetHat:Int(hat:Int, value:Int)
		If Not joystick Or Not joystick.joystickPtr Then Return 0
		Return bmx_SDL3_SetVirtualHat(joystick.joystickPtr, hat, value)
	End Method

	Method Detach()
		If Not id Then Return
		If joystick Then joystick.Close()
		bmx_SDL3_DetachVirtualJoystick(id)
		id = 0
	End Method

	Method Delete()
		Detach()
	End Method
End Type

Public
Type TSDLJoystickState
	Field joystick:TSDLJoystick
	Field hits:Int[32]
End Type

Private
Global _driver:TSDLJoystickDriver

Function _JoystickEvent(kind:Int, id:UInt, control:Int, value:Int)
	Try
		Local eventID:Int
		Select kind
			Case SDL_EVENT_JOYSTICK_ADDED
				eventID = EVENT_SDL3_JOYSTICK_ADDED
			Case SDL_EVENT_JOYSTICK_REMOVED
				eventID = EVENT_SDL3_JOYSTICK_REMOVED
				_driver.Forget(id)
			Case SDL_EVENT_JOYSTICK_AXIS_MOTION
				eventID = EVENT_SDL3_JOYSTICK_AXIS
			Case SDL_EVENT_JOYSTICK_HAT_MOTION
				eventID = EVENT_SDL3_JOYSTICK_HAT
			Case SDL_EVENT_JOYSTICK_BUTTON_DOWN
				eventID = EVENT_SDL3_JOYSTICK_BUTTON_DOWN
				If control >= 0 And control < 32 Then
					Local state:TSDLJoystickState = _driver.StateForID(id)
					If state Then state.hits[control] :+ 1
				End If
			Case SDL_EVENT_JOYSTICK_BUTTON_UP
				eventID = EVENT_SDL3_JOYSTICK_BUTTON_UP
		End Select
		If eventID Then EmitEvent(CreateEvent(eventID, Null, Int(id), control, value))
	Catch error:Object
		SDLSystemDriver()._DeferCallbackError(error)
	End Try
End Function
Public

Type TSDLJoystickDriver Extends TJoystickDriver
	Field states:TIntMap = New TIntMap

	Method GetName:String() Override
		Return "SDL3 Joystick"
	End Method

	Method StateForID:TSDLJoystickState(id:UInt)
		If Not id Then Return Null
		Local state:TSDLJoystickState = TSDLJoystickState(states.ValueForKey(Int(id)))
		If state And state.joystick.Connected() Then Return state
		If state Then Forget(id)
		Local joystick:TSDLJoystick = TSDLJoystick.Open(id)
		If Not joystick Then Return Null
		state = New TSDLJoystickState
		state.joystick = joystick
		states.Insert(Int(id), state)
		Return state
	End Method

	Method Forget(id:UInt)
		Local state:TSDLJoystickState = TSDLJoystickState(states.ValueForKey(Int(id)))
		If state Then state.joystick.Close()
		states.Remove(Int(id))
	End Method

	Method StateForPort:TSDLJoystickState(port:Int)
		Return StateForID(SDLJoystickIDAt(port))
	End Method

	Method JoyCount:Int() Override
		Return bmx_SDL3_CopyJoystickIDs(Null, 0)
	End Method

	Method JoyName:String(port:Int) Override
		Local id:UInt = SDLJoystickIDAt(port)
		If id Then Return bmx_SDL3_JoystickNameForID(id)
		Return ""
	End Method

	Method JoyButtonCaps:Int(port:Int) Override
		Local state:TSDLJoystickState = StateForPort(port)
		If Not state Then Return 0
		Local result:Int
		For Local button:Int = 0 Until Min(state.joystick.ButtonCount(), 32)
			result :| (1 Shl button)
		Next
		Return result
	End Method

	Method JoyAxisCaps:Int(port:Int) Override
		Local state:TSDLJoystickState = StateForPort(port)
		If Not state Then Return 0
		Local result:Int
		For Local axis:Int = 0 Until Min(state.joystick.AxisCount(), 9)
			result :| (1 Shl axis)
		Next
		If state.joystick.HatCount() > 0 Then result :| (1 Shl JOY_HAT)
		If state.joystick.AxisCount() > 10 Then result :| (1 Shl JOY_WHEEL)
		Return result
	End Method

	Method JoyDown:Int(button:Int, port:Int = 0) Override
		Local state:TSDLJoystickState = StateForPort(port)
		If state Then Return state.joystick.Button(button)
	End Method

	Method JoyHit:Int(button:Int, port:Int = 0) Override
		If button < 0 Or button >= 32 Then Return 0
		Local state:TSDLJoystickState = StateForPort(port)
		If Not state Then Return 0
		Local count:Int = state.hits[button]
		state.hits[button] = 0
		Return count
	End Method

	Method AxisValue:Float(axis:Int, port:Int)
		Local state:TSDLJoystickState = StateForPort(port)
		If Not state Or axis >= state.joystick.AxisCount() Then Return 0.0
		Local value:Int = state.joystick.Axis(axis)
		If value < 0 Then Return Float(value) / 32768.0
		Return Float(value) / 32767.0
	End Method

	Method JoyX:Float(port:Int = 0) Override
		Return AxisValue(JOY_X, port)
	End Method
	Method JoyY:Float(port:Int = 0) Override
		Return AxisValue(JOY_Y, port)
	End Method
	Method JoyZ:Float(port:Int = 0) Override
		Return AxisValue(JOY_Z, port)
	End Method
	Method JoyR:Float(port:Int = 0) Override
		Return AxisValue(JOY_R, port)
	End Method
	Method JoyU:Float(port:Int = 0) Override
		Return AxisValue(JOY_U, port)
	End Method
	Method JoyV:Float(port:Int = 0) Override
		Return AxisValue(JOY_V, port)
	End Method
	Method JoyYaw:Float(port:Int = 0) Override
		Return AxisValue(JOY_YAW, port)
	End Method
	Method JoyPitch:Float(port:Int = 0) Override
		Return AxisValue(JOY_PITCH, port)
	End Method
	Method JoyRoll:Float(port:Int = 0) Override
		Return AxisValue(JOY_ROLL, port)
	End Method
	Method JoyWheel:Float(port:Int = 0) Override
		Return AxisValue(JOY_WHEEL, port)
	End Method

	Method JoyHat:Float(port:Int = 0) Override
		Local state:TSDLJoystickState = StateForPort(port)
		If Not state Or state.joystick.HatCount() < 1 Then Return -1.0
		Select state.joystick.Hat()
			Case SDL_HAT_UP Return 0.0
			Case SDL_HAT_UP | SDL_HAT_RIGHT Return 0.125
			Case SDL_HAT_RIGHT Return 0.25
			Case SDL_HAT_RIGHT | SDL_HAT_DOWN Return 0.375
			Case SDL_HAT_DOWN Return 0.5
			Case SDL_HAT_DOWN | SDL_HAT_LEFT Return 0.625
			Case SDL_HAT_LEFT Return 0.75
			Case SDL_HAT_LEFT | SDL_HAT_UP Return 0.875
		End Select
		Return -1.0
	End Method

	Method JoyType:Int(port:Int = 0) Override
		Return SDLJoystickIDAt(port) <> 0
	End Method

	Method Direction:Int(axis:Int, port:Int)
		Local value:Float = AxisValue(axis, port)
		If value < -0.333333 Then Return -1
		If value > 0.333333 Then Return 1
		Return 0
	End Method
	Method JoyXDir:Int(port:Int = 0) Override
		Return Direction(JOY_X, port)
	End Method
	Method JoyYDir:Int(port:Int = 0) Override
		Return Direction(JOY_Y, port)
	End Method
	Method JoyZDir:Int(port:Int = 0) Override
		Return Direction(JOY_Z, port)
	End Method
	Method JoyUDir:Int(port:Int = 0) Override
		Return Direction(JOY_U, port)
	End Method
	Method JoyVDir:Int(port:Int = 0) Override
		Return Direction(JOY_V, port)
	End Method

	Method FlushJoy(port_mask:Int = ~0) Override
		For Local port:Int = 0 Until Min(JoyCount(), 32)
			If port_mask & (1 Shl port) Then
				Local state:TSDLJoystickState = StateForPort(port)
				If state Then
					For Local button:Int = 0 Until 32
						state.hits[button] = 0
					Next
				End If
			End If
		Next
	End Method
End Type

Extern
	Function bmx_SDL3_CopyJoystickIDs:Int(output:UInt Ptr, capacity:Int)
	Function bmx_SDL3_JoystickNameForID:String(id:UInt)
	Function bmx_SDL3_JoystickName:String(joystick:Byte Ptr)
	Function bmx_SDL3_JoystickConnected:Int(joystick:Byte Ptr)
	Function bmx_SDL3_GetJoystickAxis:Int(joystick:Byte Ptr, axis:Int)
	Function bmx_SDL3_GetJoystickButton:Int(joystick:Byte Ptr, button:Int)
	Function bmx_SDL3_GetJoystickHat:Int(joystick:Byte Ptr, hat:Int)
	Function bmx_SDL3_AttachVirtualJoystick:UInt(name:String, joystickType:Int, axes:Int, buttons:Int, hats:Int)
	Function bmx_SDL3_DetachVirtualJoystick:Int(id:UInt)
	Function bmx_SDL3_SetVirtualAxis:Int(joystick:Byte Ptr, axis:Int, value:Int)
	Function bmx_SDL3_SetVirtualButton:Int(joystick:Byte Ptr, button:Int, down:Int)
	Function bmx_SDL3_SetVirtualHat:Int(joystick:Byte Ptr, hat:Int, value:Int)
	Function bmx_SDL3_RegisterJoystickObserver()
	Function SDL_OpenJoystick:Byte Ptr(id:UInt)
	Function SDL_CloseJoystick(joystick:Byte Ptr)
	Function SDL_GetJoystickID:UInt(joystick:Byte Ptr)
	Function SDL_GetNumJoystickAxes:Int(joystick:Byte Ptr)
	Function SDL_GetNumJoystickButtons:Int(joystick:Byte Ptr)
	Function SDL_GetNumJoystickHats:Int(joystick:Byte Ptr)
End Extern

If Not SDL_WasInit(SDL_INIT_JOYSTICK) And Not SDL_InitSubSystem(SDL_INIT_JOYSTICK) Then Throw "SDL3 joystick init failed: " + SDL_GetError()
_driver = New TSDLJoystickDriver
GetJoystickDriver(_driver.GetName())
bmx_SDL3_RegisterJoystickObserver()
