SuperStrict

Module SDL3.SDL3Gamepad
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3Joystick
Import BRL.Event
Import "glue.c"

Const SDL_GAMEPAD_AXIS_LEFTX:Int = 0
Const SDL_GAMEPAD_AXIS_LEFTY:Int = 1
Const SDL_GAMEPAD_AXIS_RIGHTX:Int = 2
Const SDL_GAMEPAD_AXIS_RIGHTY:Int = 3
Const SDL_GAMEPAD_AXIS_LEFT_TRIGGER:Int = 4
Const SDL_GAMEPAD_AXIS_RIGHT_TRIGGER:Int = 5

Const SDL_GAMEPAD_BUTTON_SOUTH:Int = 0
Const SDL_GAMEPAD_BUTTON_EAST:Int = 1
Const SDL_GAMEPAD_BUTTON_WEST:Int = 2
Const SDL_GAMEPAD_BUTTON_NORTH:Int = 3
Const SDL_GAMEPAD_BUTTON_BACK:Int = 4
Const SDL_GAMEPAD_BUTTON_GUIDE:Int = 5
Const SDL_GAMEPAD_BUTTON_START:Int = 6
Const SDL_GAMEPAD_BUTTON_LEFT_STICK:Int = 7
Const SDL_GAMEPAD_BUTTON_RIGHT_STICK:Int = 8
Const SDL_GAMEPAD_BUTTON_LEFT_SHOULDER:Int = 9
Const SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER:Int = 10
Const SDL_GAMEPAD_BUTTON_DPAD_UP:Int = 11
Const SDL_GAMEPAD_BUTTON_DPAD_DOWN:Int = 12
Const SDL_GAMEPAD_BUTTON_DPAD_LEFT:Int = 13
Const SDL_GAMEPAD_BUTTON_DPAD_RIGHT:Int = 14

Const SDL_EVENT_GAMEPAD_AXIS_MOTION:Int = $650
Const SDL_EVENT_GAMEPAD_BUTTON_DOWN:Int = $651
Const SDL_EVENT_GAMEPAD_BUTTON_UP:Int = $652
Const SDL_EVENT_GAMEPAD_ADDED:Int = $653
Const SDL_EVENT_GAMEPAD_REMOVED:Int = $654
Const SDL_EVENT_GAMEPAD_REMAPPED:Int = $655

' Event data is the instance ID, mods is the axis/button index, x is its value.
Global EVENT_SDL3_GAMEPAD_ADDED:Int = AllocUserEventId("SDL3 gamepad added")
Global EVENT_SDL3_GAMEPAD_REMOVED:Int = AllocUserEventId("SDL3 gamepad removed")
Global EVENT_SDL3_GAMEPAD_REMAPPED:Int = AllocUserEventId("SDL3 gamepad remapped")
Global EVENT_SDL3_GAMEPAD_AXIS:Int = AllocUserEventId("SDL3 gamepad axis")
Global EVENT_SDL3_GAMEPAD_BUTTON_DOWN:Int = AllocUserEventId("SDL3 gamepad button down")
Global EVENT_SDL3_GAMEPAD_BUTTON_UP:Int = AllocUserEventId("SDL3 gamepad button up")

Function SDLGamepadIDs:UInt[]()
	Local count:Int = bmx_SDL3_CopyGamepadIDs(Null, 0)
	Local ids:UInt[count]
	If count Then
		Local copied:Int = bmx_SDL3_CopyGamepadIDs(ids, count)
		If copied < count Then Return ids[..copied]
	End If
	Return ids
End Function

Function SDLIsGamepad:Int(id:UInt)
	Return bmx_SDL3_IsGamepad(id)
End Function

Function SDLAddGamepadMapping:Int(mapping:String)
	Return bmx_SDL3_AddGamepadMapping(mapping)
End Function

Type TSDLGamepad
	Field gamepadPtr:Byte Ptr

	Function Open:TSDLGamepad(id:UInt)
		If Not id Then Return Null
		Local ptr:Byte Ptr = SDL_OpenGamepad(id)
		If Not ptr Then Return Null
		Local gamepad:TSDLGamepad = New TSDLGamepad
		gamepad.gamepadPtr = ptr
		Return gamepad
	End Function

	Method ID:UInt()
		If gamepadPtr Then Return SDL_GetGamepadID(gamepadPtr)
	End Method

	Method Name:String()
		If gamepadPtr Then Return bmx_SDL3_GamepadName(gamepadPtr)
		Return ""
	End Method

	Method Mapping:String()
		If gamepadPtr Then Return bmx_SDL3_GetGamepadMapping(gamepadPtr)
		Return ""
	End Method

	Method Connected:Int()
		If gamepadPtr Then Return bmx_SDL3_GamepadConnected(gamepadPtr)
	End Method

	Method Axis:Int(axis:Int)
		If gamepadPtr Then Return bmx_SDL3_GetGamepadAxis(gamepadPtr, axis)
	End Method

	Method Button:Int(button:Int)
		If gamepadPtr Then Return bmx_SDL3_GetGamepadButton(gamepadPtr, button)
	End Method

	Method Rumble:Int(low:Int, high:Int, durationMs:UInt)
		If Not gamepadPtr Then Return 0
		low = Max(0, Min(low, 65535))
		high = Max(0, Min(high, 65535))
		Return bmx_SDL3_RumbleGamepad(gamepadPtr, low, high, durationMs)
	End Method

	Method Close()
		If gamepadPtr Then
			SDL_CloseGamepad(gamepadPtr)
			gamepadPtr = Null
		End If
	End Method

	Method Delete()
		Close()
	End Method
End Type

Private
Function _GamepadEvent(kind:Int, id:UInt, control:Int, value:Int)
	Try
		Local eventID:Int
		Select kind
			Case SDL_EVENT_GAMEPAD_ADDED
				eventID = EVENT_SDL3_GAMEPAD_ADDED
			Case SDL_EVENT_GAMEPAD_REMOVED
				eventID = EVENT_SDL3_GAMEPAD_REMOVED
			Case SDL_EVENT_GAMEPAD_REMAPPED
				eventID = EVENT_SDL3_GAMEPAD_REMAPPED
			Case SDL_EVENT_GAMEPAD_AXIS_MOTION
				eventID = EVENT_SDL3_GAMEPAD_AXIS
			Case SDL_EVENT_GAMEPAD_BUTTON_DOWN
				eventID = EVENT_SDL3_GAMEPAD_BUTTON_DOWN
			Case SDL_EVENT_GAMEPAD_BUTTON_UP
				eventID = EVENT_SDL3_GAMEPAD_BUTTON_UP
		End Select
		If eventID Then EmitEvent(CreateEvent(eventID, Null, Int(id), control, value))
	Catch error:Object
		SDLSystemDriver()._DeferCallbackError(error)
	End Try
End Function
Public

Extern
	Function bmx_SDL3_CopyGamepadIDs:Int(output:UInt Ptr, capacity:Int)
	Function bmx_SDL3_IsGamepad:Int(id:UInt)
	Function bmx_SDL3_GamepadConnected:Int(gamepad:Byte Ptr)
	Function bmx_SDL3_GamepadName:String(gamepad:Byte Ptr)
	Function bmx_SDL3_GetGamepadAxis:Int(gamepad:Byte Ptr, axis:Int)
	Function bmx_SDL3_GetGamepadButton:Int(gamepad:Byte Ptr, button:Int)
	Function bmx_SDL3_RumbleGamepad:Int(gamepad:Byte Ptr, low:Int, high:Int, durationMs:UInt)
	Function bmx_SDL3_GetGamepadMapping:String(gamepad:Byte Ptr)
	Function bmx_SDL3_AddGamepadMapping:Int(mapping:String)
	Function bmx_SDL3_RegisterGamepadObserver()
	Function SDL_OpenGamepad:Byte Ptr(id:UInt)
	Function SDL_CloseGamepad(gamepad:Byte Ptr)
	Function SDL_GetGamepadID:UInt(gamepad:Byte Ptr)
End Extern

If Not SDL_WasInit(SDL_INIT_GAMEPAD) And Not SDL_InitSubSystem(SDL_INIT_GAMEPAD) Then Throw "SDL3 gamepad init failed: " + SDL_GetError()
bmx_SDL3_RegisterGamepadObserver()
