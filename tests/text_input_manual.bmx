SuperStrict

' Run with a real desktop video driver. Type into the window; committed text
' appears in its title. Try accents/IME, changing focus, and Escape to close.
Framework SDL3.SDL3Graphics
Import BRL.PolledInput
Import BRL.Hook

Local graphics:TGraphics = SDLGraphics(640, 160)
If Not graphics Then Throw SDL_GetError()
SetGraphics(graphics)
Local window:TSDLWindow = SDLGraphicsDriver().GetSDLWindow()
Local renderer:TSDLRenderer = SDLGraphicsDriver().GetSDLRenderer()
Global text:String
Global composition:String
Global inputWindow:TSDLWindow
Function ObserveEditing:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If event.id = EVENT_SDL3_TEXT_EDITING Then
		Local editing:TSDLTextEditingEvent = TSDLTextEditingEvent(event.extra)
		If editing.windowID = inputWindow.GetID() Then
			composition = editing.text
			inputWindow.SetTitle("Received: " + text + " | Composing: " + composition)
		End If
	End If
	Return data
End Function
inputWindow = window
Local area:SSDLRect = New SSDLRect(16, 32, 600, 32)
If Not window.SetTextInputArea(area, 0) Then Throw SDL_GetError()
AddHook EmitEventHook, ObserveEditing
window.SetTitle("Type text here - Escape closes")
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local character:Int = GetChar()
	While character
		If character = 8 Then
			If text.Length Then text = text[..text.Length - 1]
		Else If character >= 32 Then
			text :+ Chr(character)
		End If
		window.SetTitle("Received: " + text + " | Composing: " + composition)
		character = GetChar()
	Wend
	renderer.SetDrawColor(24, 32, 48)
	renderer.Clear()
	Flip(1)
Wend
RemoveHook EmitEventHook, ObserveEditing
CloseGraphics(graphics)
