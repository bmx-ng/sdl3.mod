SuperStrict

Framework SDL3.SDL3Graphics
Import BRL.Graphics
Import BRL.StandardIO
Import "test_helpers.bmx"

Check GetGraphicsDriver() = SDLGraphicsDriver()
GraphicsModes()
Local graphics:TSDLGraphics = TSDLGraphics(Graphics(96, 64, 0, 60))
Check graphics, "Graphics() did not create SDL3 graphics"
Check GraphicsWidth() = 96 And GraphicsHeight() = 64

Local driver:TSDLGraphicsDriver = SDLGraphicsDriver()
Local window:TSDLWindow = driver.GetSDLWindow()
Local renderer:TSDLRenderer = driver.GetSDLRenderer()
Check window
Check renderer
Check (window.GetFlags() & SDL_WINDOW_HIGH_PIXEL_DENSITY) <> 0, "Graphics windows must request native pixel density"
Local pixelWidth:Int
Local pixelHeight:Int
Check window.GetSizeInPixels(pixelWidth, pixelHeight)
Check pixelWidth >= GraphicsWidth() And pixelHeight >= GraphicsHeight(), "Native drawable must retain the logical window extent"
Check driver.GetSDLGLContext() = Null
Check renderer.SetDrawColor(255, 0, 0) = 1
Check renderer.Clear() = 1
Flip(0)

Check window.SetSize(120, 72) = 1
For Local attempt:Int = 0 Until 10
	PollSystem()
Next
Check GraphicsWidth() = 120 And GraphicsHeight() = 72, "Window resize did not update graphics dimensions"

' BRL graphics flags overlap SDL3 window flag bits and must be translated.
Local other:TSDLGraphics = TSDLGraphics(CreateGraphics(80, 50, 0, 60, GRAPHICS_BORDERLESS | GRAPHICS_ACCUMBUFFER, -1, -1))
Check other
SetGraphics(other)
Local otherWindow:TSDLWindow = driver.GetSDLWindow()
Check (otherWindow.GetFlags() & SDL_WINDOW_BORDERLESS) <> 0
Check (otherWindow.GetFlags() & SDL_WINDOW_RESIZABLE) = 0
Check GraphicsWidth() = 80 And GraphicsHeight() = 50
SetGraphics(graphics)
CloseGraphics(other)

CloseGraphics(graphics)
Check driver.GetSDLWindow() = Null
Check driver.GetSDLRenderer() = Null
Print "SDL3 graphics driver test passed"
