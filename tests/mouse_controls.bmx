SuperStrict

Framework SDL3.SDL3Mouse
Import SDL3.SDL3Test
Import BRL.StandardIO
Import "test_helpers.bmx"

Local window:TSDLWindow = TSDLWindow.Create("SDL3 mouse tests", 64, 64, SDL_WINDOW_HIDDEN)
Check window, SDL_GetError()
Check probeIsDummyVideo(), "Run this test with SDL_VIDEODRIVER=dummy"
Check Not TSDLCursor.CreateSystem(-1), "Invalid system cursor accepted"
Check Not TSDLCursor.CreateColor(Null, 0, 0)
Local empty:TSDLCursor = New TSDLCursor
Check Not empty.Set()
empty.Destroy()
empty.Destroy()
SDL_ClearError()
Local cursor:TSDLCursor = TSDLCursor.CreateSystem(SDL_SYSTEM_CURSOR_DEFAULT)
Check Not cursor, "Dummy driver unexpectedly supports native cursors; update the test"
Check SDL_GetError() <> "", "Unsupported cursor had no error"
Check SDLSetCursorVisible(False) = 1
Check Not SDLCursorVisible()
Check SDLSetCursorVisible(7) = 1
Check SDLCursorVisible() = 1
' An unfocused window stores the request; no hardware-relative-mode claim here.
Check window.SetRelativeMouseMode(7) = 1, SDL_GetError()
Check window.GetRelativeMouseMode() = 1
Check window.SetRelativeMouseMode(False) = 1
Check Not window.GetRelativeMouseMode()
Local x:Float = 999, y:Float = 999
SDLGetRelativeMouseState(x, y)
x = 999
y = 999
SDLGetRelativeMouseState(x, y)
Check x = 0 And y = 0, "Relative state did not consume accumulated deltas"
SDL_ClearError()
Check Not SDLCaptureMouse(True), "Dummy driver unexpectedly supports capture; update the test"
Check SDL_GetError() <> ""
window.Destroy()
Check Not window.SetRelativeMouseMode(True)
Check Not window.GetRelativeMouseMode()
Print "SDL3 mouse tests passed (dummy driver; native cursor creation not exercised)"
