SuperStrict

Framework SDL3.SDL3Render
Import "test_helpers.bmx"
Import BRL.StandardIO
Import BRL.FileSystem

Local surface:TSDLSurface = TSDLSurface.Create(4, 4)
Check surface, SDL_GetError()
Check surface.Width() = 4 And surface.Height() = 4
Check surface.Format() <> 0
Check surface.Fill(255, 0, 0) = 1
Local patch:SSDLRect = New SSDLRect(1, 1, 2, 2)
Check surface.FillRect(patch, 0, 255, 0) = 1

Local red:Int, green:Int, blue:Int, alpha:Int
Check surface.ReadPixel(0, 0, red, green, blue, alpha) = 1
Check red = 255 And green = 0 And blue = 0 And alpha = 255
Check surface.ReadPixel(1, 1, red, green, blue, alpha) = 1
Check red = 0 And green = 255 And blue = 0 And alpha = 255

Local bmpPath:String = AppDir + "/sdl3-surface-texture.bmp"
Check surface.SaveBMP(bmpPath) = 1, SDL_GetError()
Local loaded:TSDLSurface = TSDLSurface.LoadBMP(bmpPath)
Check loaded, SDL_GetError()
Check loaded.Width() = 4 And loaded.Height() = 4
Check loaded.ReadPixel(1, 1, red, green, blue, alpha) = 1
Check red = 0 And green = 255 And blue = 0
loaded.Destroy()
DeleteFile(bmpPath)

Local window:TSDLWindow = TSDLWindow.Create("SDL3 texture test", 32, 32, SDL_WINDOW_HIDDEN)
Check window, SDL_GetError()
Local renderer:TSDLRenderer = TSDLRenderer.Create(window, "software")
Check renderer, SDL_GetError()
Local texture:TSDLTexture = renderer.CreateTextureFromSurface(surface)
Check texture, SDL_GetError()
Local width:Float, height:Float
Check texture.GetSize(width, height) = 1
Check width = 4 And height = 4
Check renderer.SetDrawColor(0, 0, 0) = 1
Check renderer.Clear() = 1
Local destination:SSDLFRect = New SSDLFRect(0, 0, 4, 4)
Check renderer.RenderTexture(texture, destination) = 1
Local source:SSDLFRect = New SSDLFRect(1, 1, 2, 2)
destination = New SSDLFRect(8, 8, 8, 8)
Check renderer.RenderTexturePart(texture, source, destination) = 1
Check renderer.SetDrawColor(0, 0, 255) = 1
Local fill:SSDLFRect = New SSDLFRect(16, 16, 4, 4)
Check renderer.FillRect(fill) = 1

Local pixels:TSDLSurface = renderer.ReadPixels()
Check pixels, SDL_GetError()
Check pixels.ReadPixel(0, 0, red, green, blue, alpha) = 1
Check red = 255 And green = 0 And blue = 0
Check pixels.ReadPixel(1, 1, red, green, blue, alpha) = 1
Check red = 0 And green = 255 And blue = 0
Check pixels.ReadPixel(9, 9, red, green, blue, alpha) = 1
Check red = 0 And green = 255 And blue = 0
Check pixels.ReadPixel(17, 17, red, green, blue, alpha) = 1
Check red = 0 And green = 0 And blue = 255
pixels.Destroy()
Check renderer.Present() = 1
texture.Destroy()
surface.Destroy()
renderer.Destroy()
window.Destroy()
Print "SDL3 surface and texture test passed"
