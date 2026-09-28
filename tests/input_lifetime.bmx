SuperStrict

Framework SDL3.SDL3Render
Import SDL3.SDL3Graphics
Import SDL3.SDL3Test
Import BRL.Hook
Import BRL.StandardIO
Import "test_helpers.bmx"

Global opened:String
Global openCount:Int
Global typed:String
Function Observe:Object(id:Int, data:Object, context:Object)
	Local event:TEvent = TEvent(data)
	If event.id = EVENT_APPOPENFILE Then
		opened = String(event.extra)
		openCount :+ 1
	Else If event.id = EVENT_KEYCHAR Then
		typed :+ Chr(event.data)
	End If
	Return data
End Function
AddHook EmitEventHook, Observe

Local window:TSDLWindow = TSDLWindow.Create("SDL3 input lifetime", 32, 32, SDL_WINDOW_HIDDEN)
Check window, SDL_GetError()
Check Not window.TextInputActive(), "Raw window unexpectedly enables text input"
Check window.StartTextInput() = 1, SDL_GetError()
Check window.TextInputActive() = 1
Check window.StartTextInput() = 1
Check probePushText()
PollSystem()
Check typed = "caf" + Chr($E9), "Committed UTF-8 text was not translated"
Check window.StopTextInput() = 1
Check Not window.TextInputActive()

Check probeQueueOpenFile()
GCCollect()
PollSystem()
Check openCount = 1 And opened = "/tmp/SDL3-caf" + Chr($E9) + ".txt", "Queued path did not survive caller cleanup"
probeRejectDrops(True)
Check Not probeQueueOpenFile(), "Rejected event reported success"
probeRejectDrops(False)
PollSystem()
Check openCount = 1, "Rejected file event was delivered"
SDL_SetEventEnabled($1000, False) ' SDL_EVENT_DROP_FILE
Check Not probeQueueOpenFile()
SDL_SetEventEnabled($1000, True)
Check probeQueueOpenFile()
PollSystem()
Check openCount = 2

Local surface:TSDLSurface = TSDLSurface.Create(2, 2)
Local renderer:TSDLRenderer = TSDLRenderer.Create(window, "software")
Check renderer, SDL_GetError()
Local texture:TSDLTexture = renderer.CreateTextureFromSurface(surface)
Check texture And texture.IsValid()
Local otherWindow:TSDLWindow = TSDLWindow.Create("Other renderer", 16, 16, SDL_WINDOW_HIDDEN)
Check otherWindow
Local otherRenderer:TSDLRenderer = TSDLRenderer.Create(otherWindow, "software")
Check otherRenderer
Local destination:SSDLFRect = New SSDLFRect(0, 0, 2, 2)
Check Not otherRenderer.RenderTexture(texture, destination), "Cross-renderer texture was accepted"
otherRenderer.Destroy()
otherWindow.Destroy()
renderer.Destroy()
Check Not texture.IsValid(), "Texture survived renderer destruction"
Local width:Float = 99, height:Float = 99
Check Not texture.GetSize(width, height)
Check width = 0 And height = 0
texture.Destroy()
texture.Destroy()
renderer.Destroy()

renderer = TSDLRenderer.Create(window, "software")
Check renderer, SDL_GetError()
texture = renderer.CreateTextureFromSurface(surface)
Check texture
window.Destroy()
Check Not renderer.IsValid() And Not texture.IsValid(), "Resources survived window destruction"
Check Not renderer.Clear()
texture.Destroy()
renderer.Destroy()
window.Destroy()
surface.Destroy()

Local graphics:TGraphics = SDLGraphics(32, 32)
Check graphics, SDL_GetError()
SetGraphics(graphics)
Check SDLGraphicsDriver().GetSDLWindow().TextInputActive(), "BRL graphics did not activate text input"
graphics.Close()
Check probeQueueOpenFile() ' Unpolled payload must be released at system shutdown.
RemoveHook EmitEventHook, Observe
Print "SDL3 input and lifetime tests passed"
