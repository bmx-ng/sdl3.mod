SuperStrict

' Requires SDL_VIDEODRIVER=dummy: never changes the desktop clipboard.
Framework SDL3.SDL3Video
Import SDL3.SDL3Clipboard
Import SDL3.SDL3Test
Import BRL.Hook
Import BRL.StandardIO
Import "test_helpers.bmx"

Global edits:Int
Global characters:Int
Global lastEdit:TSDLTextEditingEvent
Function Observe:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If event.id = EVENT_SDL3_TEXT_EDITING Then
		lastEdit = TSDLTextEditingEvent(event.extra)
		edits :+ 1
	Else If event.id = EVENT_KEYCHAR Then
		characters :+ 1
	End If
	Return data
End Function

Local window:TSDLWindow = TSDLWindow.Create("SDL3 composition", 80, 60, SDL_WINDOW_HIDDEN)
Check window, SDL_GetError()
Check probeIsDummyVideo(), "Use SDL_VIDEODRIVER=dummy to protect the desktop clipboard"
Local text:String = "caf" + Chr($E9) + " " + Chr($D83D) + Chr($DE00) + "~nsecond line"
Check SDLSetClipboardText(text) = 1, SDL_GetError()
Check SDLHasClipboardText() = 1
Check SDLGetClipboardText() = text, "Unicode clipboard roundtrip failed"
Check SDLSetClipboardText("") = 1
Check SDLGetClipboardText() = ""
Check Not SDLHasClipboardText()

Check window.StartTextInput()
Local area:SSDLRect = New SSDLRect(3, 5, 40, 18)
Check window.SetTextInputArea(area, 12), SDL_GetError()
Local actual:SSDLRect
Local cursor:Int
Check window.GetTextInputArea(actual, cursor)
Check actual.Equals(area) And cursor = 12, "IME area roundtrip failed"
Check window.ClearComposition()
Check window.TextInputActive(), "ClearComposition stopped text input"
Check window.ResetTextInputArea()
AddHook EmitEventHook, Observe
Check probePushEditing(window.GetID(), False)
PollSystem()
Check edits = 1 And characters = 0, "Preedit text leaked into committed input"
Check lastEdit.windowID = window.GetID()
Check lastEdit.text = "caf" + Chr($E9) And lastEdit.start = 1 And lastEdit.length = 2
Local saved:TSDLTextEditingEvent = lastEdit
probeCaptureEditing(True)
Check probePushEditing(window.GetID(), False)
PollSystem()
Check edits = 1, "Captured composition was delivered"
probeCaptureEditing(False)
Check probePushEditing(window.GetID(), True)
PollSystem()
Check edits = 2 And lastEdit.text = "" And lastEdit.start = -1 And lastEdit.length = -1
GCCollect()
Check saved.text = "caf" + Chr($E9), "Retained composition payload changed"
RemoveHook EmitEventHook, Observe
window.Destroy()
Check Not window.GetTextInputArea(actual, cursor)
Check actual.x = 0 And actual.y = 0 And actual.w = 0 And actual.h = 0 And cursor = 0
Print "SDL3 clipboard and composition tests passed"
