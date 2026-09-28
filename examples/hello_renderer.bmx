SuperStrict

Framework SDL3.SDL3Render
Import BRL.EventQueue
Import BRL.KeyCodes

Local window:TSDLWindow = TSDLWindow.Create("Hello SDL3 - Escape to quit", 800, 450, ..
	SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY)
If Not window Then Throw SDL_GetError()

Local renderer:TSDLRenderer = TSDLRenderer.Create(window)
If Not renderer Then
	Local message:String = SDL_GetError()
	window.Destroy()
	Throw message
End If

' Keep drawing in an 800 x 450 canvas when the window is resized.
If Not renderer.SetLogicalPresentation(800, 450, SDL_LOGICAL_PRESENTATION_LETTERBOX) Then
	Local message:String = SDL_GetError()
	renderer.Destroy()
	window.Destroy()
	Throw message
End If
Local vsync:Int = renderer.SetVSync(1)
Local box:SSDLFRect = New SSDLFRect(40, 40, 160, 100)

Local running:Int = True
While running
	' Raw SDL windows use events directly; Graphics() normally enables polled input.
	While PollEvent()
		Select EventID()
			Case EVENT_APPTERMINATE
				running = False
			Case EVENT_WINDOWCLOSE
				If UInt(EventData()) = window.GetID() Then running = False
			Case EVENT_KEYDOWN
				If EventData() = KEY_ESCAPE Then running = False
		End Select
	Wend
	If Not running Then Exit

	renderer.SetDrawColor(24, 28, 38)
	renderer.Clear()
	renderer.SetDrawColor(55, 170, 240)
	renderer.FillRect(box)
	renderer.Present()

	If Not vsync Then Delay 1
Wend

renderer.Destroy()
window.Destroy()
