SuperStrict

Module SDL3.SDL3Video
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3System
Import SDL3.SDL3Rect
Import SDL3.SDL3Surface
Import "glue.c"

Const SDL_WINDOW_HIDDEN:ULong = $8
Const SDL_WINDOW_OPENGL:ULong = $2
Const SDL_WINDOW_BORDERLESS:ULong = $10
Const SDL_WINDOW_RESIZABLE:ULong = $20
Const SDL_WINDOW_MINIMIZED:ULong = $40
Const SDL_WINDOW_MAXIMIZED:ULong = $80
Const SDL_WINDOW_MOUSE_GRABBED:ULong = $100
Const SDL_WINDOW_MOUSE_CAPTURE:ULong = $4000
Const SDL_WINDOW_HIGH_PIXEL_DENSITY:ULong = $2000
Const SDL_WINDOWPOS_CENTERED:Int = $2FFF0000

Const SDL_GL_ALPHA_SIZE:Int = 3
Const SDL_GL_DOUBLEBUFFER:Int = 5
Const SDL_GL_DEPTH_SIZE:Int = 6
Const SDL_GL_STENCIL_SIZE:Int = 7

Type TSDLWindow
	Field windowPtr:Byte Ptr
	Field _contexts:TSDLGLContext

	Function Create:TSDLWindow(title:String, width:Int, height:Int, flags:ULong = 0)
		If Not SDL_WasInit(SDL_INIT_VIDEO) And Not SDL_InitSubSystem(SDL_INIT_VIDEO) Then Return Null
		Local ptr:Byte Ptr = bmx_SDL3_CreateWindow(title, width, height, flags)
		If Not ptr Then Return Null
		Local window:TSDLWindow = New TSDLWindow
		window.windowPtr = ptr
		Return window
	End Function

	Method GetID:UInt()
		Return SDL_GetWindowID(windowPtr)
	End Method

	Method GetFlags:ULong()
		Return SDL_GetWindowFlags(windowPtr)
	End Method

	Method GetTitle:String()
		Return bmx_SDL3_GetWindowTitle(windowPtr)
	End Method

	Method SetTitle:Int(title:String)
		Return bmx_SDL3_SetWindowTitle(windowPtr, title)
	End Method

	Method GetSize:Int(width:Int Var, height:Int Var)
		Return bmx_SDL3_GetWindowSize(windowPtr, Varptr width, Varptr height)
	End Method

	Method SetSize:Int(width:Int, height:Int)
		Return bmx_SDL3_SetWindowSize(windowPtr, width, height)
	End Method

	Method GetSizeInPixels:Int(width:Int Var, height:Int Var)
		Return bmx_SDL3_GetWindowSizeInPixels(windowPtr, Varptr width, Varptr height)
	End Method

	Method GetPosition:Int(x:Int Var, y:Int Var)
		Return bmx_SDL3_GetWindowPosition(windowPtr, Varptr x, Varptr y)
	End Method

	Method SetPosition:Int(x:Int, y:Int)
		Return bmx_SDL3_SetWindowPosition(windowPtr, x, y)
	End Method

	Method Show:Int()
		Return bmx_SDL3_ShowWindow(windowPtr)
	End Method

	Method Hide:Int()
		Return bmx_SDL3_HideWindow(windowPtr)
	End Method

	Rem
	bbdoc: Starts committed-text and IME input for this window.
	about: Raw SDL windows start with text input disabled. BRL graphics windows enable it automatically.
	End Rem
	Method StartTextInput:Int()
		Return bmx_SDL3_StartTextInput(windowPtr)
	End Method

	Rem
	bbdoc: Stops text input for this window.
	End Rem
	Method StopTextInput:Int()
		Return bmx_SDL3_StopTextInput(windowPtr)
	End Method

	Rem
	bbdoc: Returns whether text input is active for this window.
	End Rem
	Method TextInputActive:Int()
		Return bmx_SDL3_TextInputActive(windowPtr)
	End Method

	Rem
	bbdoc: Sets the IME candidate area and cursor offset in SDL window coordinates.
	about: The cursor offset is relative to rect.x. These are native window coordinates, not drawable pixels or Max2D world coordinates. Call on the main thread.
	End Rem
	Method SetTextInputArea:Int(rect:SSDLRect Var, cursor:Int = 0)
		Return bmx_SDL3_SetTextInputArea(windowPtr, rect, cursor)
	End Method

	Rem
	bbdoc: Returns the previously configured input area and cursor offset.
	End Rem
	Method GetTextInputArea:Int(rect:SSDLRect Var, cursor:Int Var)
		Return bmx_SDL3_GetTextInputArea(windowPtr, rect, Varptr cursor)
	End Method

	Rem
	bbdoc: Resets the text input area to SDL's default.
	End Rem
	Method ResetTextInputArea:Int()
		Return bmx_SDL3_ResetTextInputArea(windowPtr)
	End Method

	Rem
	bbdoc: Dismisses IME composition without stopping text input.
	End Rem
	Method ClearComposition:Int()
		Return bmx_SDL3_ClearComposition(windowPtr)
	End Method

	Rem
	bbdoc: Enables continuous relative mouse movement while this window has focus.
	about: Hides the cursor and constrains it to the window. SDL flushes pending motion when changing mode. Call on the main thread and check the result.
	End Rem
	Method SetRelativeMouseMode:Int(enabled:Int)
		Return bmx_SDL3_SetWindowRelativeMouseMode(windowPtr, enabled)
	End Method

	Rem
	bbdoc: Returns whether relative mouse mode is requested for this window.
	End Rem
	Method GetRelativeMouseMode:Int()
		Return bmx_SDL3_GetWindowRelativeMouseMode(windowPtr)
	End Method

	Rem
	bbdoc: Enables or disables user resizing.
	about: Main-thread operation. Returns False on SDL failure; inspect SDL_GetError. The window manager may limit the result.
	End Rem
	Method SetResizable:Int(enabled:Int)
		Return bmx_SDL3_SetWindowResizable(windowPtr, enabled)
	End Method

	Rem
	bbdoc: Enables or disables window decorations.
	about: Main-thread operation. Returns False on SDL failure; inspect SDL_GetError. The window manager may limit the result.
	End Rem
	Method SetBordered:Int(enabled:Int)
		Return bmx_SDL3_SetWindowBordered(windowPtr, enabled)
	End Method

	Rem
	bbdoc: Requests confinement to this window while it has focus.
	about: Main-thread operation. Returns False on SDL failure; inspect SDL_GetError. The window manager may limit the result.
	End Rem
	Method SetMouseGrab:Int(enabled:Int)
		Return bmx_SDL3_SetWindowMouseGrab(windowPtr, enabled)
	End Method

	Rem
	bbdoc: Requests minimisation.
	about: Main-thread operation. Window-manager policy applies; success does not guarantee focus or placement. Sync can block, so use it after a transition rather than every frame.
	End Rem
	Method Minimize:Int()
		Return bmx_SDL3_MinimizeWindow(windowPtr)
	End Method

	Rem
	bbdoc: Requests maximisation; enable resizing first.
	about: Main-thread operation. Window-manager policy applies; success does not guarantee focus or placement. Sync can block, so use it after a transition rather than every frame.
	End Rem
	Method Maximize:Int()
		Return bmx_SDL3_MaximizeWindow(windowPtr)
	End Method

	Rem
	bbdoc: Requests restoration from minimised or maximised state.
	about: Main-thread operation. Window-manager policy applies; success does not guarantee focus or placement. Sync can block, so use it after a transition rather than every frame.
	End Rem
	Method Restore:Int()
		Return bmx_SDL3_RestoreWindow(windowPtr)
	End Method

	Rem
	bbdoc: Requests that the window be raised and focused.
	about: Main-thread operation. Window-manager policy applies; success does not guarantee focus or placement. Sync can block, so use it after a transition rather than every frame.
	End Rem
	Method Raise:Int()
		Return bmx_SDL3_RaiseWindow(windowPtr)
	End Method

	Rem
	bbdoc: Waits for pending window state changes to complete.
	about: Main-thread operation. Window-manager policy applies; success does not guarantee focus or placement. Sync can block, so use it after a transition rather than every frame.
	End Rem
	Method Sync:Int()
		Return bmx_SDL3_SyncWindow(windowPtr)
	End Method

	Rem
	bbdoc: Sets the minimum client size in native SDL window coordinates.
	about: Call on the main thread. SDL validates limits; zero removes a limit. Query outputs are initialised to zero.
	End Rem
	Method SetMinimumSize:Int(width:Int, height:Int)
		Return bmx_SDL3_SetWindowMinimumSize(windowPtr, width, height)
	End Method

	Rem
	bbdoc: Gets the minimum client size in native SDL window coordinates.
	about: Call on the main thread. SDL validates limits; zero removes a limit. Query outputs are initialised to zero.
	End Rem
	Method GetMinimumSize:Int(width:Int Var, height:Int Var)
		Return bmx_SDL3_GetWindowMinimumSize(windowPtr, Varptr width, Varptr height)
	End Method

	Rem
	bbdoc: Sets the maximum client size in native SDL window coordinates.
	about: Call on the main thread. SDL validates limits; zero removes a limit. Query outputs are initialised to zero.
	End Rem
	Method SetMaximumSize:Int(width:Int, height:Int)
		Return bmx_SDL3_SetWindowMaximumSize(windowPtr, width, height)
	End Method

	Rem
	bbdoc: Gets the maximum client size in native SDL window coordinates.
	about: Call on the main thread. SDL validates limits; zero removes a limit. Query outputs are initialised to zero.
	End Rem
	Method GetMaximumSize:Int(width:Int Var, height:Int Var)
		Return bmx_SDL3_GetWindowMaximumSize(windowPtr, Varptr width, Varptr height)
	End Method

	Rem
	bbdoc: Sets the window icon from a surface. The source may be destroyed afterwards.
	about: Main-thread operation. Platform support varies; macOS uses the application bundle icon instead of a per-window title-bar icon.
	End Rem
	Method SetIcon:Int(surface:TSDLSurface)
		If Not surface Or Not surface.surfacePtr Then Return False
		Return bmx_SDL3_SetWindowIcon(windowPtr, surface.surfacePtr)
	End Method

	Rem
	bbdoc: Returns whether mouse grab is enabled for this window.
	End Rem
	Method GetMouseGrab:Int()
		Return bmx_SDL3_GetWindowMouseGrab(windowPtr)
	End Method

	Rem
	bbdoc: Requests confinement to a rectangle in native SDL window coordinates.
	about: Platform support varies. This is independent of capture and does not itself hide the cursor. Call on the main thread.
	End Rem
	Method SetMouseRect:Int(rect:SSDLRect Var)
		Return bmx_SDL3_SetWindowMouseRect(windowPtr, rect)
	End Method

	Rem
	bbdoc: Removes the mouse confinement rectangle.
	End Rem
	Method ResetMouseRect:Int()
		Return bmx_SDL3_ResetWindowMouseRect(windowPtr)
	End Method

	Rem
	bbdoc: Copies the configured confinement rectangle.
	about: Returns False and a zero rectangle if none is configured or the window is invalid. This copies SDL's borrowed rectangle; no native pointer is retained.
	End Rem
	Method GetMouseRect:Int(rect:SSDLRect Var)
		Return bmx_SDL3_GetWindowMouseRect(windowPtr, rect)
	End Method

	Method SetFullscreen:Int(enabled:Int)
		Return bmx_SDL3_SetWindowFullscreen(windowPtr, enabled)
	End Method

	Method SetFullscreenMode:Int(width:Int, height:Int, depth:Int, hertz:Int)
		Return bmx_SDL3_SetWindowFullscreenMode(windowPtr, width, height, depth, hertz)
	End Method

	Method GLCreateContext:TSDLGLContext()
		If Not windowPtr Then Return Null
		Return TSDLGLContext._create(SDL_GL_CreateContext(windowPtr), Self)
	End Method

	Method GLMakeCurrent:Int(context:TSDLGLContext)
		If Not context Or Not context.IsValid() Or context._window <> Self Then Return 0
		Return bmx_SDL3_GLMakeCurrent(windowPtr, context.contextPtr)
	End Method

	Method GLSwap:Int()
		Return bmx_SDL3_GLSwapWindow(windowPtr)
	End Method

	Method GLGetDrawableSize:Int(width:Int Var, height:Int Var)
		Return GetSizeInPixels(width, height)
	End Method

	Method GetHandle:Byte Ptr()
		Return bmx_SDL3_GetWindowHandle(windowPtr)
	End Method

	Method GetDisplayHandle:Byte Ptr()
		Return bmx_SDL3_GetWindowDisplayHandle(windowPtr)
	End Method

	Method Destroy()
		If windowPtr Then
			While _contexts
				Local context:TSDLGLContext = _contexts
				context.Free()
				If context.contextPtr Then Return
			Wend
			SDL_DestroyWindow(windowPtr)
			windowPtr = Null
		End If
	End Method
End Type

Rem
bbdoc: An explicitly owned OpenGL context associated with its creating window.
about: Free releases it; destroying the owner window frees all its contexts first. Retaining a wrapper does not prevent explicit window destruction. Use IsValid before further operations. Native context handles are borrowed and must not be destroyed separately. Use these methods on the main thread.
End Rem
Type TSDLGLContext
	Field contextPtr:Byte Ptr
	Field _window:TSDLWindow
	Field _next:TSDLGLContext

	Function _create:TSDLGLContext(ptr:Byte Ptr, window:TSDLWindow)
		If Not ptr Then Return Null
		Local context:TSDLGLContext = New TSDLGLContext
		context.contextPtr = ptr
		context._window = window
		context._next = window._contexts
		window._contexts = context
		Return context
	End Function

	Rem
	bbdoc: Returns whether this wrapper and its owner window still have native handles.
	End Rem
	Method IsValid:Int()
		Return contextPtr And _window And _window.windowPtr
	End Method

	Function SetAttribute:Int(attribute:Int, value:Int)
		Return bmx_SDL3_GLSetAttribute(attribute, value)
	End Function

	Function GetAttribute:Int(attribute:Int, value:Int Var)
		Return bmx_SDL3_GLGetAttribute(attribute, Varptr value)
	End Function

	Function GetProcAddress:Byte Ptr(name:String)
		Return bmx_SDL3_GLGetProcAddress(name)
	End Function

	Method SetSwapInterval:Int(interval:Int)
		If Not IsValid() Or SDL_GL_GetCurrentContext() <> contextPtr Then Return 0
		Return bmx_SDL3_GLSetSwapInterval(interval)
	End Method

	Method Free()
		If contextPtr Then
			If Not bmx_SDL3_GLDestroyContext(contextPtr) Then Return
			contextPtr = Null
			If _window Then
				If _window._contexts = Self Then
					_window._contexts = _next
				Else
					Local previous:TSDLGLContext = _window._contexts
					While previous And previous._next <> Self
						previous = previous._next
					Wend
					If previous Then previous._next = _next
				End If
			End If
			_window = Null
			_next = Null
		End If
	End Method
End Type

Function _warpMouse(x:Int, y:Int)
	bmx_SDL3_WarpMouseInFocus(x, y)
End Function
_sdl_WarpMouse = _warpMouse

Extern
	Function bmx_SDL3_SetWindowResizable:Int(window:Byte Ptr, enabled:Int)
	Function bmx_SDL3_SetWindowBordered:Int(window:Byte Ptr, enabled:Int)
	Function bmx_SDL3_SetWindowMouseGrab:Int(window:Byte Ptr, enabled:Int)
	Function bmx_SDL3_MinimizeWindow:Int(window:Byte Ptr)
	Function bmx_SDL3_MaximizeWindow:Int(window:Byte Ptr)
	Function bmx_SDL3_RestoreWindow:Int(window:Byte Ptr)
	Function bmx_SDL3_RaiseWindow:Int(window:Byte Ptr)
	Function bmx_SDL3_SyncWindow:Int(window:Byte Ptr)
	Function bmx_SDL3_SetWindowMinimumSize:Int(window:Byte Ptr, width:Int, height:Int)
	Function bmx_SDL3_GetWindowMinimumSize:Int(window:Byte Ptr, width:Int Ptr, height:Int Ptr)
	Function bmx_SDL3_SetWindowMaximumSize:Int(window:Byte Ptr, width:Int, height:Int)
	Function bmx_SDL3_GetWindowMaximumSize:Int(window:Byte Ptr, width:Int Ptr, height:Int Ptr)
	Function bmx_SDL3_SetWindowIcon:Int(window:Byte Ptr, surface:Byte Ptr)
	Function bmx_SDL3_GetWindowMouseGrab:Int(window:Byte Ptr)
	Function bmx_SDL3_SetWindowMouseRect:Int(window:Byte Ptr, rect:SSDLRect Var)
	Function bmx_SDL3_ResetWindowMouseRect:Int(window:Byte Ptr)
	Function bmx_SDL3_GetWindowMouseRect:Int(window:Byte Ptr, rect:SSDLRect Var)
	Function bmx_SDL3_SetWindowRelativeMouseMode:Int(window:Byte Ptr, enabled:Int)
	Function bmx_SDL3_GetWindowRelativeMouseMode:Int(window:Byte Ptr)
	Function bmx_SDL3_SetTextInputArea:Int(window:Byte Ptr, rect:SSDLRect Var, cursor:Int)
	Function bmx_SDL3_GetTextInputArea:Int(window:Byte Ptr, rect:SSDLRect Var, cursor:Int Ptr)
	Function bmx_SDL3_ResetTextInputArea:Int(window:Byte Ptr)
	Function bmx_SDL3_ClearComposition:Int(window:Byte Ptr)
	Function bmx_SDL3_StartTextInput:Int(window:Byte Ptr)
	Function bmx_SDL3_StopTextInput:Int(window:Byte Ptr)
	Function bmx_SDL3_TextInputActive:Int(window:Byte Ptr)
	Function bmx_SDL3_CreateWindow:Byte Ptr(title:String, width:Int, height:Int, flags:ULong)
	Function bmx_SDL3_GetWindowSize:Int(window:Byte Ptr, width:Int Ptr, height:Int Ptr)
	Function bmx_SDL3_SetWindowSize:Int(window:Byte Ptr, width:Int, height:Int)
	Function bmx_SDL3_GetWindowSizeInPixels:Int(window:Byte Ptr, width:Int Ptr, height:Int Ptr)
	Function bmx_SDL3_GetWindowPosition:Int(window:Byte Ptr, x:Int Ptr, y:Int Ptr)
	Function bmx_SDL3_SetWindowPosition:Int(window:Byte Ptr, x:Int, y:Int)
	Function bmx_SDL3_GetWindowTitle:String(window:Byte Ptr)
	Function bmx_SDL3_SetWindowTitle:Int(window:Byte Ptr, title:String)
	Function bmx_SDL3_ShowWindow:Int(window:Byte Ptr)
	Function bmx_SDL3_HideWindow:Int(window:Byte Ptr)
	Function bmx_SDL3_SetWindowFullscreen:Int(window:Byte Ptr, enabled:Int)
	Function bmx_SDL3_SetWindowFullscreenMode:Int(window:Byte Ptr, width:Int, height:Int, depth:Int, hertz:Int)
	Function SDL_GL_CreateContext:Byte Ptr(window:Byte Ptr)
	Function SDL_GL_GetCurrentContext:Byte Ptr()
	Function bmx_SDL3_GLMakeCurrent:Int(window:Byte Ptr, context:Byte Ptr)
	Function bmx_SDL3_GLSwapWindow:Int(window:Byte Ptr)
	Function bmx_SDL3_GLSetAttribute:Int(attribute:Int, value:Int)
	Function bmx_SDL3_GLGetAttribute:Int(attribute:Int, value:Int Ptr)
	Function bmx_SDL3_GLGetProcAddress:Byte Ptr(name:String)
	Function bmx_SDL3_GLSetSwapInterval:Int(interval:Int)
	Function bmx_SDL3_GLDestroyContext:Int(context:Byte Ptr)
	Function bmx_SDL3_GetWindowHandle:Byte Ptr(window:Byte Ptr)
	Function bmx_SDL3_GetWindowDisplayHandle:Byte Ptr(window:Byte Ptr)
	Function bmx_SDL3_WarpMouseInFocus(x:Int, y:Int)
	Function SDL_GetWindowID:UInt(window:Byte Ptr)
	Function SDL_GetWindowFlags:ULong(window:Byte Ptr)
	Function SDL_DestroyWindow(window:Byte Ptr)
End Extern
