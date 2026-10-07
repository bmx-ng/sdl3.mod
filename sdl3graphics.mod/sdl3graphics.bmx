SuperStrict

Module SDL3.SDL3Graphics
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3Render
Import BRL.Graphics
Import "glue.c"

Private
Global _currentContext:TSDLGraphicsContext
Public

Rem
bbdoc: Native attachment provider installed by an optional GUI integration module.
End Rem
Global SDLAttachWindow:Byte Ptr(widget:Byte Ptr)

Rem
bbdoc: Creates the renderer for a GUI-owned drawing surface.
End Rem
Global SDLAttachRenderer:TSDLRenderer(window:TSDLWindow)

Rem
bbdoc: Claims an attached native canvas for an SDL GPU device.
param: Borrowed SDL_GPUDevice pointer.
param: Borrowed SDL_Window wrapper pointer.
returns: Nonzero on success; zero with SDL_GetError set on failure.
about: Installed by the optional GUI bridge. Called on the main thread before GPU drawing.
End Rem
Global SDLAttachGPUClaim:Int(device:Byte Ptr,window:Byte Ptr)

Rem
bbdoc: Optional conversion from framework drawing coordinates to SDL window coordinates.
about: Rendering frameworks whose presentation transform is not represented by SDL's renderer can install this hook.
End Rem
Global SDLTransformTextInputPoint:Int(window:TSDLWindow,x:Float,y:Float,windowX:Float Var,windowY:Float Var)

Rem
bbdoc: Reports an attached canvas size in logical coordinates or pixels.
End Rem
Global SDLAttachedSize(window:Byte Ptr, width:Int Var, height:Int Var, pixels:Int)

Type TSDLGraphicsContext
	Rem
	bbdoc: True when a native GUI owns the drawing surface and its window.
	End Rem
	Field attached:Int
	Field window:TSDLWindow
	Field renderer:TSDLRenderer
	Field glContext:TSDLGLContext
	Field width:Int, height:Int, depth:Int, hertz:Int
	Field flags:Long
	Field x:Int, y:Int
	Field sync:Int = -2
	Method WindowScale:Float()
		If attached Then Return 1.0
		Local d:Int,hz:Int
		If bmx_SDL3_GraphicsWindowMode(window.windowPtr,d,hz)=1 Then Return 1.0
		Return bmx_SDL3_GraphicsWindowScale(window.windowPtr)
	End Method
	Method RefreshSize()
		If attached Then
			SDLAttachedSize(window.windowPtr,width,height,False)
			Return
		End If
?android Or ios
		' Mobile platforms own the full-screen surface; retain the requested logical size.
		Return
?Not android And Not ios
		window.GetSize(width,height)
		Local scale:Float=WindowScale()
		width=Int(width/scale+0.5);height=Int(height/scale+0.5)
?
	End Method
End Type

Type TSDLGraphics Extends TGraphics
	Field _context:TSDLGraphicsContext

	Method Driver:TSDLGraphicsDriver() Override
		Return SDLGraphicsDriver()
	End Method

	Method GetSettings(width:Int Var, height:Int Var, depth:Int Var, hertz:Int Var, flags:Long Var, x:Int Var, y:Int Var) Override
		If Not _context Then Return
		RefreshWindowSettings()
		width = _context.width
		height = _context.height
		depth = _context.depth
		hertz = _context.hertz
		flags = _context.flags
		x = _context.x
		y = _context.y
	End Method

	Method RefreshWindowSettings()
		If Not _context Then Return
		_context.RefreshSize()
?android Or ios
		_context.x=0;_context.y=0
		_context.depth=0;_context.hertz=0
?Not android And Not ios
		_context.window.GetPosition(_context.x,_context.y)
		bmx_SDL3_GraphicsWindowMode(_context.window.windowPtr,_context.depth,_context.hertz)
?
	End Method

	Method WindowMode:Int()
		If Not _context Or _context.attached Then Return 0
?android Or ios
		Return 0
?Not android And Not ios
		Return bmx_SDL3_GraphicsWindowMode(_context.window.windowPtr,_context.depth,_context.hertz)
?
	End Method

	Method SetFullscreen(enabled:Int,width:Int=0,height:Int=0,hertz:Int=0)
		RefreshWindowSettings()
		If width=0 Then width=_context.width
		If height=0 Then height=_context.height
		ChangeWindowMode(Int(enabled<>0),width,height,hertz)
	End Method

	Method SetBorderlessFullscreen(enabled:Int)
		If Not enabled And WindowMode()<>2 Then Return
		ChangeWindowMode(2*Int(enabled<>0),0,0,0)
	End Method

	Method ChangeWindowMode(mode:Int,width:Int,height:Int,hertz:Int)
		If _context.attached Then Throw "SDL3 Graphics: the GUI owns this canvas window"
		Local ok:Int=bmx_SDL3_GraphicsSetWindowMode(_context.window.windowPtr,mode,width,height,hertz)
		Local message:String
		If Not ok Then message=SDL_GetError()
		RefreshWindowSettings()
		If Not ok Then Throw "SDL3 Graphics: "+message
	End Method

	Method Close() Override
		If Not _context Then Return
		RemoveHook EmitEventHook, TSDLGraphicsDriver.GraphicsHook, _context
		If _currentContext = _context Then _currentContext = Null
		If _context.renderer Then _context.renderer.Destroy()
		If _context.glContext Then _context.glContext.Free()
		If _context.window Then _context.window.Destroy()
		_context = Null
	End Method

	Method Resize(width:Int, height:Int) Override
		If _context And _context.attached Then Throw "SDL3 Graphics: resize the host gadget instead"
		If Not _context Then Return
		_context.RefreshSize()
		If width=_context.width And height=_context.height Then Return
		If WindowMode()<>0 Then Throw "SDL3 Graphics: leave fullscreen before resizing the window"
		Local ok:Int=bmx_SDL3_GraphicsSetLogicalSize(_context.window.windowPtr,width,height)
		Local message:String
		If Not ok Then message=SDL_GetError()
		RefreshWindowSettings()
		If Not ok Then Throw "SDL3 Graphics: "+message
	End Method

	Method Position(x:Int, y:Int) Override
		If _context And _context.attached Then Throw "SDL3 Graphics: position the host gadget instead"
		If Not _context Then Return
		_context.x = x
		_context.y = y
	End Method
End Type

Type TSDLGraphicsMode Extends TGraphicsMode
End Type

Type TSDLGraphicsDriver Extends TGraphicsDriver
	Const MODE_SIZE:Int = 5

	Method GraphicsModes:TGraphicsMode[]() Override
		If Not SDL_WasInit(SDL_INIT_VIDEO) And Not SDL_InitSubSystem(SDL_INIT_VIDEO) Then Return New TGraphicsMode[0]
		Local buffer:Int[1024 * MODE_SIZE]
		Local count:Int = bmx_SDL3_GraphicsModes(buffer, 1024)
		Local modes:TGraphicsMode[count]
		Local entry:Int Ptr = buffer
		For Local i:Int = 0 Until count
			Local mode:TSDLGraphicsMode = New TSDLGraphicsMode
			mode.width = entry[0]
			mode.height = entry[1]
			mode.depth = entry[2]
			mode.hertz = entry[3]
			mode.display = entry[4]
			modes[i] = mode
			entry :+ MODE_SIZE
		Next
		Return modes
	End Method

	Method AttachGraphics:TSDLGraphics(widget:Byte Ptr, flags:Long) Override
		If Not SDLAttachWindow Then Return Null
		If flags & SDL_GRAPHICS_GL Then Throw "SDL3 Graphics: OpenGL attachment is not supported by this provider"
		If (flags & SDL_GRAPHICS_GPU) And Not SDLAttachGPUClaim Then Return Null
		Local ptr:Byte Ptr=SDLAttachWindow(widget)
		If Not ptr Then Return Null
		Local context:TSDLGraphicsContext=New TSDLGraphicsContext
		context.attached=True
		context.window=New TSDLWindow
		context.window.windowPtr=ptr
		If Not (flags & SDL_GRAPHICS_GPU) Then
			context.renderer=SDLAttachRenderer(context.window)
			If Not context.renderer Then
				context.window.Destroy()
				Return Null
			End If
		End If
		context.flags=flags
		context.RefreshSize()
		Local graphics:TSDLGraphics=New TSDLGraphics
		graphics._context=context
		Return graphics
	End Method

	Method CreateGraphics:TSDLGraphics(width:Int, height:Int, depth:Int, hertz:Int, flags:Long, x:Int, y:Int) Override
		If width <= 0 Or height <= 0 Then Return Null
		Local useGL:Int = (flags & SDL_GRAPHICS_GL) <> 0
		If useGL And (flags & SDL_GRAPHICS_GPU) Then Throw "SDL3 Graphics: OpenGL and GPU window flags are mutually exclusive"
		If useGL Then
			If flags & GRAPHICS_BACKBUFFER Then TSDLGLContext.SetAttribute(SDL_GL_DOUBLEBUFFER, 1)
			If flags & GRAPHICS_ALPHABUFFER Then TSDLGLContext.SetAttribute(SDL_GL_ALPHA_SIZE, 1)
			If flags & GRAPHICS_DEPTHBUFFER Then TSDLGLContext.SetAttribute(SDL_GL_DEPTH_SIZE, 24)
			If flags & GRAPHICS_STENCILBUFFER Then TSDLGLContext.SetAttribute(SDL_GL_STENCIL_SIZE, 1)
		End If

		' Keep the requested logical size while exposing the display's native pixels.
		Local windowFlags:ULong=SDL_WINDOW_HIDDEN | SDL_WINDOW_HIGH_PIXEL_DENSITY
		If flags & GRAPHICS_BORDERLESS Then windowFlags :| SDL_WINDOW_BORDERLESS
		If useGL Then windowFlags :| SDL_WINDOW_OPENGL
		Local window:TSDLWindow = TSDLWindow.Create(AppTitle, width, height, windowFlags)
		If Not window Then Return Null

		' Position first so the requested logical size uses the destination display scale.
		Local windowX:Int=x,windowY:Int=y
		If windowX<0 Then windowX=SDL_WINDOWPOS_CENTERED
		If windowY<0 Then windowY=SDL_WINDOWPOS_CENTERED
		If Not bmx_SDL3_GraphicsInitialPosition(window.windowPtr,windowX,windowY) Or Not bmx_SDL3_GraphicsSetLogicalSize(window.windowPtr,width,height) Then
			window.Destroy()
			Return Null
		End If
		' Recenter after applying the logical size; explicit desktop positions stay native.
		If Not bmx_SDL3_GraphicsInitialPosition(window.windowPtr,windowX,windowY) Or Not window.Show() Then
			window.Destroy()
			Return Null
		End If
		If depth > 0 Then
			If Not (flags & GRAPHICS_FULLSCREEN_DESKTOP) Then
				If Not window.SetFullscreenMode(width, height, depth, hertz) Then
					window.Destroy()
					Return Null
				End If
			End If
			If Not window.SetFullscreen(True) Then
				window.Destroy()
				Return Null
			End If
		End If

?Not android And Not ios
		If Not window.StartTextInput() Then
			window.Destroy()
			Return Null
		End If
?

		Local renderer:TSDLRenderer
		Local glContext:TSDLGLContext
		If useGL Then
			glContext = window.GLCreateContext()
			If Not glContext Then
				window.Destroy()
				Return Null
			End If
		Else If Not (flags & SDL_GRAPHICS_GPU) Then
			renderer = TSDLRenderer.Create(window)
			If Not renderer Then
				window.Destroy()
				Return Null
			End If
		End If
?android Or ios
		x=0;y=0
?Not android And Not ios
		window.GetSize(width, height)
		window.GetPosition(x, y)
?

		Local context:TSDLGraphicsContext = New TSDLGraphicsContext
		context.window = window
		context.renderer = renderer
		context.glContext = glContext
		context.width = width
		context.height = height
		context.depth = depth
		context.hertz = hertz
		context.flags = flags
		context.x = x
		context.y = y
		AddHook EmitEventHook, GraphicsHook, context, 0

		Local graphics:TSDLGraphics = New TSDLGraphics
		graphics._context = context
		graphics.RefreshWindowSettings()
		Return graphics
	End Method

	Method SetGraphics(graphics:TGraphics) Override
		Local selected:TSDLGraphics = TSDLGraphics(graphics)
		_currentContext = Null
		If selected Then
			_currentContext = selected._context
			If _currentContext And _currentContext.glContext Then
				_currentContext.window.GLMakeCurrent(_currentContext.glContext)
			End If
		End If
	End Method

	Method Flip:Int(sync:Int) Override
		If Not _currentContext Then Return 0
		If Not _currentContext.glContext And Not _currentContext.renderer Then Return 0
		If sync <> _currentContext.sync Then
			' BRL's -1 means use the display refresh rate. SDL's -1 means adaptive sync.
			Local interval:Int = sync
			If interval < 0 Then interval = 1
			If _currentContext.glContext Then
				_currentContext.glContext.SetSwapInterval(interval)
			Else
				_currentContext.renderer.SetVSync(interval)
			End If
			_currentContext.sync = sync
		End If
		If _currentContext.glContext Then Return _currentContext.window.GLSwap()
		Return _currentContext.renderer.Present()
	End Method

	Function GraphicsHook:Object(id:Int, data:Object, context:Object)
		Local event:TEvent = TEvent(data)
		Local selected:TSDLGraphicsContext = TSDLGraphicsContext(context)
		If Not event Or Not selected Or Not selected.window Then Return data
		If selected.window.GetID() <> event.data Then Return data
		Select event.id
			Case EVENT_WINDOWSIZE
				selected.RefreshSize()
				If _currentContext = selected Then GraphicsResize(selected.width, selected.height)
			Case EVENT_WINDOWMOVE
				selected.window.GetPosition(selected.x,selected.y)
				If _currentContext = selected Then GraphicsPosition(selected.x, selected.y)
		End Select
		Return data
	End Function

	Method CanResize:Int() Override
		Return True
	End Method

	Method ToString:String() Override
		Return "TSDLGraphicsDriver"
	End Method

	Method GetHandle:Byte Ptr(handleType:EGraphicsHandleType = EGraphicsHandleType.Window) Override
		If Not _currentContext Then Return Null
		If handleType = EGraphicsHandleType.Display Then Return _currentContext.window.GetDisplayHandle()
		Return _currentContext.window.GetHandle()
	End Method

	Method GetSDLWindow:TSDLWindow()
		If _currentContext Then Return _currentContext.window
	End Method

	Method GetSDLRenderer:TSDLRenderer()
		If _currentContext Then Return _currentContext.renderer
	End Method

	Method GetSDLGLContext:TSDLGLContext()
		If _currentContext Then Return _currentContext.glContext
	End Method
End Type

Const SDL_GRAPHICS_GL:Long = $20000000
Rem
bbdoc: Creates a window without an SDL renderer or OpenGL context, for an externally managed SDL GPU device.
End Rem
Const SDL_GRAPHICS_GPU:Long = $40000000

Function SDLGraphicsDriver:TSDLGraphicsDriver()
	Global driver:TSDLGraphicsDriver = New TSDLGraphicsDriver
	Return driver
End Function

Function SDLGraphics:TGraphics(width:Int, height:Int, depth:Int = 0, hertz:Int = 60, flags:Long = GRAPHICS_BACKBUFFER)
	SetGraphicsDriver SDLGraphicsDriver()
	Return Graphics(width, height, depth, hertz, flags)
End Function

Rem
bbdoc: Shows the software keyboard, when available, and starts receiving text input for the current SDL graphics window.
about: Input type and capitalization constants are provided by SDL3.SDL3Video. A value of -1 for capitalization, autocorrect or multiline preserves the platform default.
End Rem
Function SDLStartTextInput:Int(inputType:Int = SDL_TEXTINPUT_TYPE_TEXT, capitalization:Int = SDL_CAPITALIZE_DEFAULT, autocorrect:Int = -1, multiline:Int = -1)
	Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
	If Not window Then Return False
	Return window.StartTextInputWithProperties(inputType, capitalization, autocorrect, multiline)
End Function

Rem
bbdoc: Hides the software keyboard, when shown, and stops text input for the current SDL graphics window.
End Rem
Function SDLStopTextInput:Int()
	Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
	If Not window Then Return False
	Return window.StopTextInput()
End Function

Rem
bbdoc: Returns whether text input is active for the current SDL graphics window.
End Rem
Function SDLTextInputActive:Int()
	Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
	If Not window Then Return False
	Return window.TextInputActive()
End Function

Rem
bbdoc: Returns whether the current platform provides an on-screen keyboard.
End Rem
Function SDLHasScreenKeyboardSupport:Int()
	Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
	If Not window Then Return False
	Return window.HasScreenKeyboardSupport()
End Function

Rem
bbdoc: Returns whether the on-screen keyboard is shown for the current SDL graphics window.
End Rem
Function SDLScreenKeyboardShown:Int()
	Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
	If Not window Then Return False
	Return window.ScreenKeyboardShown()
End Function

Rem
bbdoc: Positions the IME candidate area for the current SDL graphics window.
about: The rectangle uses the active framework's drawing coordinates when it supplies a conversion, otherwise SDL renderer coordinates or native window coordinates. Mobile platforms also use it to keep the edited area visible above the software keyboard. The cursor offset is relative to x.
End Rem
Function SDLSetTextInputArea:Int(x:Int, y:Int, width:Int, height:Int, cursor:Int = 0)
	Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
	If Not window Then Return False
	Local area:SSDLRect
	Local x1:Float, y1:Float, x2:Float, y2:Float, cursorX:Float, cursorY:Float
	Local converted:Int
	If SDLTransformTextInputPoint Then
		converted = SDLTransformTextInputPoint(window, x, y, x1, y1) And ..
			SDLTransformTextInputPoint(window, x + width, y + height, x2, y2) And ..
			SDLTransformTextInputPoint(window, x + cursor, y, cursorX, cursorY)
	End If
	If Not converted Then
		Local renderer:TSDLRenderer = SDLGraphicsDriver().GetSDLRenderer()
		If renderer Then
			If Not renderer.CoordinatesToWindow(x, y, x1, y1) Then Return False
			If Not renderer.CoordinatesToWindow(x + width, y + height, x2, y2) Then Return False
			If Not renderer.CoordinatesToWindow(x + cursor, y, cursorX, cursorY) Then Return False
			converted = True
		End If
	End If
	If converted Then
		area = New SSDLRect(Int(x1), Int(y1), Int(x2 - x1), Int(y2 - y1))
		cursor = Int(cursorX - x1)
	Else
		area = New SSDLRect(x, y, width, height)
	End If
	Return window.SetTextInputArea(area, cursor)
End Function

Extern
	Function bmx_SDL3_GraphicsInitialPosition:Int(window:Byte Ptr,x:Int,y:Int)
	Function bmx_SDL3_GraphicsWindowScale:Float(window:Byte Ptr)
	Function bmx_SDL3_GraphicsSetLogicalSize:Int(window:Byte Ptr,width:Int,height:Int)
	Function bmx_SDL3_GraphicsWindowMode:Int(window:Byte Ptr,depth:Int Var,hertz:Int Var)
	Function bmx_SDL3_GraphicsSetWindowMode:Int(window:Byte Ptr,mode:Int,width:Int,height:Int,hertz:Int)
	Function bmx_SDL3_GraphicsModes:Int(output:Int Ptr, capacity:Int)
End Extern

SetGraphicsDriver SDLGraphicsDriver()
