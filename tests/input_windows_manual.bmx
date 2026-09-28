SuperStrict

' Click between both windows, hold keys/buttons while changing focus, scroll,
' and drag selected text from another application. Details appear in titles.
' Closing either window or pressing Escape exits. Suspend/resume is printed.
Framework SDL3.SDL3Render
Import BRL.Hook
Import BRL.KeyCodes
Import BRL.StandardIO

Global windows:TSDLWindow[2]
Global finished:Int
Global previousCommit:Object

Function InputHook:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If event.id = EVENT_WINDOWCLOSE Or event.id = EVENT_APPTERMINATE Then finished = True
	If event.id = EVENT_KEYDOWN And event.data = KEY_ESCAPE Then finished = True
	If event.id = EVENT_APPSUSPEND Then Print "Application suspended"
	If event.id = EVENT_APPRESUME Then Print "Application resumed"
	Local input:TSDLInputEvent = TSDLInputEvent(event.extra)
	If Not input Then Return data
	Local detail:String
	Select event.id
		Case EVENT_SDL3_MOUSE_WHEEL
			Local wheel:TSDLMouseWheelEvent = TSDLMouseWheelEvent(input)
			detail = "Wheel " + wheel.x + ", " + wheel.y
		Case EVENT_KEYDOWN, EVENT_KEYUP
			detail = "Key " + event.data + " | down: " + (event.id = EVENT_KEYDOWN)
		Case EVENT_MOUSEDOWN, EVENT_MOUSEUP
			detail = "Button " + event.data + " | down: " + (event.id = EVENT_MOUSEDOWN)
		Case EVENT_KEYCHAR
			Local commit:TSDLTextInputEvent = TSDLTextInputEvent(input)
			If commit And commit <> previousCommit Then
				detail = "Text: " + commit.text
				previousCommit = commit
			End If
		Case EVENT_SDL3_TEXT_DROP
			Local drop:TSDLTextDropEvent = TSDLTextDropEvent(input)
			detail = "Dropped: " + drop.text
	End Select
	If detail Then
		For Local window:TSDLWindow = EachIn windows
			If window And window.GetID() = input.windowID Then window.SetTitle("Window " + input.windowID + " | " + detail)
		Next
	End If
	Return data
End Function

Local renderers:TSDLRenderer[2]
For Local i:Int = 0 Until windows.Length
	windows[i] = TSDLWindow.Create("SDL3 input - click, type, scroll or drop text", 520, 240, SDL_WINDOW_RESIZABLE)
	If Not windows[i] Then Throw SDL_GetError()
	windows[i].SetPosition(80 + i * 550, 160)
	If Not windows[i].StartTextInput() Then Throw SDL_GetError()
	renderers[i] = TSDLRenderer.Create(windows[i])
	If Not renderers[i] Then Throw SDL_GetError()
Next
AddHook(EmitEventHook, InputHook)
While Not finished
	PollSystem()
	For Local i:Int = 0 Until renderers.Length
		renderers[i].SetDrawColor(24 + i * 20, 40, 64 + i * 32)
		renderers[i].Clear()
		renderers[i].Present()
	Next
	Delay(10)
Wend
RemoveHook(EmitEventHook, InputHook)
For Local i:Int = 0 Until windows.Length
	renderers[i].Destroy()
	windows[i].Destroy()
Next
