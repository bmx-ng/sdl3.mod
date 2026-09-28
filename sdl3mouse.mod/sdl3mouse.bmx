SuperStrict

Rem
bbdoc: SDL3 cursors, floating-point mouse state and mouse capture.
about: Initialise SDL video first. All operations must run on the main thread. Call PollSystem before querying cached mouse state. Positions are SDL-native window coordinates; relative deltas are accumulated since the previous relative-state query. These APIs do not apply Max2D camera or virtual-resolution transforms.
End Rem
Module SDL3.SDL3Mouse

ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3Video
Import SDL3.SDL3Surface
Import "glue.c"

Const SDL_SYSTEM_CURSOR_DEFAULT:Int = 0
Const SDL_SYSTEM_CURSOR_TEXT:Int = 1
Const SDL_SYSTEM_CURSOR_WAIT:Int = 2
Const SDL_SYSTEM_CURSOR_CROSSHAIR:Int = 3
Const SDL_SYSTEM_CURSOR_PROGRESS:Int = 4
Const SDL_SYSTEM_CURSOR_NWSE_RESIZE:Int = 5
Const SDL_SYSTEM_CURSOR_NESW_RESIZE:Int = 6
Const SDL_SYSTEM_CURSOR_EW_RESIZE:Int = 7
Const SDL_SYSTEM_CURSOR_NS_RESIZE:Int = 8
Const SDL_SYSTEM_CURSOR_MOVE:Int = 9
Const SDL_SYSTEM_CURSOR_NOT_ALLOWED:Int = 10
Const SDL_SYSTEM_CURSOR_POINTER:Int = 11
Const SDL_SYSTEM_CURSOR_NW_RESIZE:Int = 12
Const SDL_SYSTEM_CURSOR_N_RESIZE:Int = 13
Const SDL_SYSTEM_CURSOR_NE_RESIZE:Int = 14
Const SDL_SYSTEM_CURSOR_E_RESIZE:Int = 15
Const SDL_SYSTEM_CURSOR_SE_RESIZE:Int = 16
Const SDL_SYSTEM_CURSOR_S_RESIZE:Int = 17
Const SDL_SYSTEM_CURSOR_SW_RESIZE:Int = 18
Const SDL_SYSTEM_CURSOR_W_RESIZE:Int = 19

Const SDL_BUTTON_LMASK:UInt = 1
Const SDL_BUTTON_MMASK:UInt = 2
Const SDL_BUTTON_RMASK:UInt = 4
Const SDL_BUTTON_X1MASK:UInt = 8
Const SDL_BUTTON_X2MASK:UInt = 16

Rem
bbdoc: An owned system or colour cursor.
about: Call Destroy explicitly on the main thread before SDL_Quit. No GC finalizer calls SDL. Destroying the active cursor restores SDL's default. A colour cursor copies its source image; the surface can be destroyed after creation. Raw cursorPtr is borrowed and must not be freed separately.
End Rem
Type TSDLCursor
	Field cursorPtr:Byte Ptr

	Rem
	bbdoc: Creates an owned cursor using an SDL_SYSTEM_CURSOR constant, or returns Null on failure.
	End Rem
	Function CreateSystem:TSDLCursor(shape:Int = SDL_SYSTEM_CURSOR_DEFAULT)
		Return _create(bmx_SDL3_CreateSystemCursor(shape))
	End Function

	Rem
	bbdoc: Creates an owned colour cursor with a hotspot inside the surface.
	End Rem
	Function CreateColor:TSDLCursor(surface:TSDLSurface, hotX:Int, hotY:Int)
		If Not surface Or Not surface.surfacePtr Then Return Null
		Return _create(bmx_SDL3_CreateColorCursor(surface.surfacePtr, hotX, hotY))
	End Function

	Private
	Function _create:TSDLCursor(ptr:Byte Ptr)
		If Not ptr Then Return Null
		Local cursor:TSDLCursor = New TSDLCursor
		cursor.cursorPtr = ptr
		Return cursor
	End Function
	Public

	Rem
	bbdoc: Makes this cursor active. Returns False after destruction or on SDL failure.
	End Rem
	Method Set:Int()
		If Not cursorPtr Then Return False
		Return bmx_SDL3_SetCursor(cursorPtr)
	End Method

	Rem
	bbdoc: Frees the cursor. Safe to call repeatedly.
	End Rem
	Method Destroy()
		If cursorPtr Then
			bmx_SDL3_DestroyCursor(cursorPtr)
			cursorPtr = Null
		End If
	End Method
End Type

Rem
bbdoc: Selects SDL's borrowed default cursor without taking ownership of it.
End Rem
Function SDLResetCursor:Int()
	Return bmx_SDL3_ResetCursor()
End Function

Rem
bbdoc: Sets cursor visibility and reports SDL success or failure.
End Rem
Function SDLSetCursorVisible:Int(visible:Int)
	Return bmx_SDL3_CursorVisibility(visible)
End Function

Rem
bbdoc: Returns whether SDL's cursor visibility setting is enabled.
End Rem
Function SDLCursorVisible:Int()
	Return bmx_SDL3_CursorVisible()
End Function

Rem
bbdoc: Enables or releases mouse capture for the foreground window.
about: Use briefly during a drag. Capture allows coordinates outside the window without constraining or hiding the cursor. SDL releases capture on focus loss and may automatically capture while a button is held. Relative mouse mode is a separate per-window setting. Unsupported requests return False; inspect SDL_GetError.
End Rem
Function SDLCaptureMouse:Int(enabled:Int)
	Return bmx_SDL3_CaptureMouse(enabled)
End Function

Rem
bbdoc: Returns cached mouse button flags and native window coordinates.
End Rem
Function SDLGetMouseState:UInt(x:Float Var, y:Float Var)
	Return bmx_SDL3_GetMouseState(Varptr x, Varptr y)
End Function

Rem
bbdoc: Returns mouse button flags and consumes accumulated relative movement.
about: A second query without intervening movement returns zero deltas. Coordinate and delta queries do not consume BlitzMax events and are not suppressed by native event-observer capture flags.
End Rem
Function SDLGetRelativeMouseState:UInt(dx:Float Var, dy:Float Var)
	Return bmx_SDL3_GetRelativeMouseState(Varptr dx, Varptr dy)
End Function

Private
Extern
	Function bmx_SDL3_CreateSystemCursor:Byte Ptr(shape:Int)
	Function bmx_SDL3_CreateColorCursor:Byte Ptr(surface:Byte Ptr, hotX:Int, hotY:Int)
	Function bmx_SDL3_SetCursor:Int(cursor:Byte Ptr)
	Function bmx_SDL3_DestroyCursor(cursor:Byte Ptr)
	Function bmx_SDL3_ResetCursor:Int()
	Function bmx_SDL3_CursorVisibility:Int(visible:Int)
	Function bmx_SDL3_CursorVisible:Int()
	Function bmx_SDL3_CaptureMouse:Int(enabled:Int)
	Function bmx_SDL3_GetMouseState:UInt(x:Float Ptr, y:Float Ptr)
	Function bmx_SDL3_GetRelativeMouseState:UInt(x:Float Ptr, y:Float Ptr)
End Extern
