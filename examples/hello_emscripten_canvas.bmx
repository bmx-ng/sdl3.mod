SuperStrict
Framework SDL3.SDL3Render
Import BRL.StandardIO

Local window:TSDLWindow = TSDLWindow.Create("BlitzMax SDL3 WebAssembly", 640, 360)
If Not window Then Throw SDL_GetError()
Local renderer:TSDLRenderer = TSDLRenderer.Create(window)
If Not renderer Then Throw SDL_GetError()
renderer.SetDrawColor(28, 65, 119)
renderer.Clear()
renderer.Present()
Print "sdl3 canvas rendered"
