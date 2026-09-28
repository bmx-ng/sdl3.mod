SuperStrict

Framework SDL3.SDL3Graphics
Import BRL.PolledInput
Import "test_helpers.bmx"

Local graphics:TGraphics = SDLGraphics(640, 320)
Check graphics, SDL_GetError()
SetGraphics(graphics)
Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
Local renderer:TSDLRenderer = SDLGraphicsDriver().GetSDLRenderer()
Check window.SetResizable(7)
Check (window.GetFlags() & SDL_WINDOW_RESIZABLE) <> 0
Check window.SetResizable(False)
Check (window.GetFlags() & SDL_WINDOW_RESIZABLE) = 0
Check window.SetResizable(True)
Check window.SetBordered(False)
Check (window.GetFlags() & SDL_WINDOW_BORDERLESS) <> 0
Check window.SetBordered(7)
Check (window.GetFlags() & SDL_WINDOW_BORDERLESS) = 0
Check window.SetMinimumSize(320, 160)
Check window.SetMaximumSize(1000, 700)
Local width:Int, height:Int
Check window.GetMinimumSize(width, height) And width = 320 And height = 160
Check window.GetMaximumSize(width, height) And width = 1000 And height = 700
Local icon:TSDLSurface = TSDLSurface.Create(32, 32)
Check icon
icon.Fill(20, 180, 230)
Local iconSet:Int = window.SetIcon(icon)
icon.Destroy()
window.SetTitle("Window checks passed | 1 maximize, 2 restore, 3 minimize, B border, G grab, C confine, Esc exit")
Local confined:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local changed:Int
	Local result:Int = True
	If KeyHit(KEY_1) Then
		result = window.Maximize()
		changed = True
	Else If KeyHit(KEY_2) Then
		result = window.Restore()
		changed = True
	Else If KeyHit(KEY_3) Then
		result = window.Minimize()
		changed = True
	Else If KeyHit(KEY_B) Then
		result = window.SetBordered((window.GetFlags() & SDL_WINDOW_BORDERLESS) <> 0)
		changed = True
	Else If KeyHit(KEY_G) Then
		result = window.SetMouseGrab(Not window.GetMouseGrab())
		changed = True
	Else If KeyHit(KEY_C) Then
		If confined Then
			result = window.ResetMouseRect()
		Else
			Local rect:SSDLRect = New SSDLRect(20, 20, 240, 100)
			result = window.SetMouseRect(rect)
			If result Then
				Local copy:SSDLRect
				Check window.GetMouseRect(copy) And copy.Equals(rect)
			End If
		End If
		If result Then confined = Not confined
		changed = True
	End If
	If changed Then
		If result Then
			window.Sync()
			window.SetTitle("Flags=" + window.GetFlags() + " | Grab=" + window.GetMouseGrab() + " Rect=" + confined + " | 1/2/3 B/G/C Esc")
		Else
			window.SetTitle(SDL_GetError())
		End If
	End If
	renderer.SetDrawColor(24, 32, 48)
	renderer.Clear()
	Flip(1)
Wend
window.ResetMouseRect()
window.SetMouseGrab(False)
CloseGraphics(graphics)
