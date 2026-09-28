SuperStrict

' Native cursor creation is checked at launch. R toggles relative mode.
' Space holds mouse capture. Escape or closing the window releases everything.
Framework SDL3.SDL3Graphics
Import SDL3.SDL3Mouse
Import BRL.PolledInput
Import "test_helpers.bmx"

Local graphics:TGraphics = SDLGraphics(640, 200)
Check graphics, SDL_GetError()
SetGraphics(graphics)
Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
Local renderer:TSDLRenderer = SDLGraphicsDriver().GetSDLRenderer()
Local cursor:TSDLCursor = TSDLCursor.CreateSystem(SDL_SYSTEM_CURSOR_CROSSHAIR)
Check cursor, SDL_GetError()
Check cursor.Set(), SDL_GetError()
Local surface:TSDLSurface = TSDLSurface.Create(16, 16)
Check surface
Check surface.Fill(255, 160, 0, 255)
Local colour:TSDLCursor = TSDLCursor.CreateColor(surface, 8, 8)
Check colour, SDL_GetError()
surface.Destroy()
Check colour.Set(), SDL_GetError()
colour.Destroy() ' Destroy the active cursor, after its source surface is gone.
colour.Destroy()
Check Not colour.Set()
Check cursor.Set()
window.SetTitle("Cursor checks passed | R: relative | Hold Space: capture | Escape: exit")
Local capture:Int
Local changed:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	changed = False
	If KeyHit(KEY_R) Then
		If Not window.SetRelativeMouseMode(Not window.GetRelativeMouseMode()) Then
			window.SetTitle(SDL_GetError())
		Else
			changed = True
		End If
	End If
	If KeyDown(KEY_SPACE) <> capture Then
		capture = KeyDown(KEY_SPACE)
		If Not SDLCaptureMouse(capture) Then
			window.SetTitle(SDL_GetError())
		Else
			changed = True
		End If
	End If
	Local dx:Float, dy:Float
	SDLGetRelativeMouseState(dx, dy)
	If changed Or (window.GetRelativeMouseMode() And (dx <> 0 Or dy <> 0)) Then
		window.SetTitle("Relative=" + window.GetRelativeMouseMode() + " delta=" + dx + "," + dy + " | Capture requested=" + capture + " | Escape exits")
	End If
	renderer.SetDrawColor(24, 32, 48)
	renderer.Clear()
	Flip(1)
Wend
SDLCaptureMouse(False)
window.SetRelativeMouseMode(False)
cursor.Destroy()
CloseGraphics(graphics)
