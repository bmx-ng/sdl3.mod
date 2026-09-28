SuperStrict

Framework SDL3.SDL3Render
Import BRL.StandardIO
Import "test_helpers.bmx"

Local window:TSDLWindow = TSDLWindow.Create("Geometry", 64, 32, SDL_WINDOW_HIDDEN)
Check window, "Failed: window"
Local renderer:TSDLRenderer = TSDLRenderer.Create(window, "software")
Check renderer, "Failed: renderer"
Local target:TSDLTexture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_TARGET, 8, 8)
Check target And renderer.SetTarget(target), "Failed: target And renderer.SetTarget(target)"
Check renderer.SetDrawColor(0, 0, 0) And renderer.Clear(), "Failed: renderer.SetDrawColor(0, 0, 0) And renderer.Clear()"
Local triangle:SSDLVertex[3]
triangle[0] = New SSDLVertex(0, 0, 1, 0, 0)
triangle[1] = New SSDLVertex(8, 0, 1, 0, 0)
triangle[2] = New SSDLVertex(0, 8, 1, 0, 0)
Check renderer.RenderGeometry(triangle), SDL_GetError()
Local pixels:TSDLSurface = renderer.ReadPixels()
Local r:Int, g:Int, b:Int, a:Int
Check pixels And pixels.ReadPixel(1, 1, r, g, b, a), "Failed: pixels And pixels.ReadPixel(1, 1, r, g, b, a)"
Check r = 255 And g = 0 And b = 0, "Vertex position/colour layout incorrect"
pixels.Destroy()
Check Not renderer.RenderGeometry(triangle[..2]), "Failed: Not renderer.RenderGeometry(triangle[..2])"
Local invalid:Int[] = [0, 1, 3]
Check Not renderer.RenderGeometry(triangle, Null, invalid), "Failed: Not renderer.RenderGeometry(triangle, Null, invalid)"
invalid = [0, -1, 2]
Check Not renderer.RenderGeometry(triangle, Null, invalid), "Failed: Not renderer.RenderGeometry(triangle, Null, invalid)"
invalid = [0, 1]
Check Not renderer.RenderGeometry(triangle, Null, invalid), "Failed: Not renderer.RenderGeometry(triangle, Null, invalid)"
Local texture:TSDLTexture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_STATIC, 1, 1)
Local white:Byte[] = [255:Byte, 255:Byte, 255:Byte, 255:Byte]
Check texture And texture.Update(white, 4), "Failed: texture And texture.Update(white, 4)"
Check texture.SetBlendMode(SDL_BLENDMODE_NONE), "Failed: texture.SetBlendMode(SDL_BLENDMODE_NONE)"
Check texture.SetColorMod(0, 0, 0) And texture.SetAlphaMod(0), "Failed: texture.SetColorMod(0, 0, 0) And texture.SetAlphaMod(0)"
Local quad:SSDLVertex[4]
quad[0] = New SSDLVertex(0, 0, 0, 1, 0, 1, 0, 0)
quad[1] = New SSDLVertex(8, 0, 0, 1, 0, 1, 1, 0)
quad[2] = New SSDLVertex(8, 8, 0, 1, 0, 1, 1, 1)
quad[3] = New SSDLVertex(0, 8, 0, 1, 0, 1, 0, 1)
Local indices:Int[] = [0, 1, 2, 0, 2, 3]
Check renderer.RenderGeometry(quad, texture, indices), "Failed: renderer.RenderGeometry(quad, texture, indices)"
pixels = renderer.ReadPixels()
Check pixels And pixels.ReadPixel(6, 6, r, g, b, a), "Failed: pixels And pixels.ReadPixel(6, 6, r, g, b, a)"
Check r = 0 And g = 255 And b = 0, "Textured geometry did not use vertex modulation"
pixels.Destroy()
Check renderer.SetLogicalPresentation(4, 4, SDL_LOGICAL_PRESENTATION_STRETCH), "Failed: renderer.SetLogicalPresentation(4, 4, SDL_LOGICAL_PRESENTATION_STRETCH)"
Check renderer.SetTarget(), "Failed: renderer.SetTarget()"
Check renderer.SetLogicalPresentation(16, 16, SDL_LOGICAL_PRESENTATION_LETTERBOX), "Failed: renderer.SetLogicalPresentation(16, 16, SDL_LOGICAL_PRESENTATION_LETTERBOX)"
Local width:Int, height:Int, mode:Int
Check renderer.GetLogicalPresentation(width, height, mode), "Failed: renderer.GetLogicalPresentation(width, height, mode)"
Check width = 16 And height = 16 And mode = SDL_LOGICAL_PRESENTATION_LETTERBOX, "Failed: width = 16 And height = 16 And mode = SDL_LOGICAL_PRESENTATION_LETTERBOX"
Local rect:SSDLFRect
Check renderer.GetLogicalPresentationRect(rect), "Failed: renderer.GetLogicalPresentationRect(rect)"
Check rect.x = 16 And rect.y = 0 And rect.w = 32 And rect.h = 32, "Failed: rect.x = 16 And rect.y = 0 And rect.w = 32 And rect.h = 32"
Local x:Float, y:Float
Check renderer.CoordinatesFromWindow(16, 0, x, y), "Failed: renderer.CoordinatesFromWindow(16, 0, x, y)"
Check Abs(x) < 0.001 And Abs(y) < 0.001, "Expected zero coordinates, got " + x + ", " + y
Check renderer.CoordinatesToWindow(16, 16, x, y), "Failed: renderer.CoordinatesToWindow(16, 16, x, y)"
Check Abs(x - 48) < 0.001 And Abs(y - 32) < 0.001, "Failed: x = 48 And y = 32"
Check renderer.CoordinatesFromWindow(0, 0, x, y), "Failed: renderer.CoordinatesFromWindow(0, 0, x, y)"
Check Abs(x + 8) < 0.001 And Abs(y) < 0.001, "Letterbox coordinates were unexpectedly clamped"
Local viewport:SSDLRect = New SSDLRect(2, 3, 8, 8)
Check renderer.SetViewport(viewport) And renderer.SetScale(2, 2), "Failed: renderer.SetViewport(viewport) And renderer.SetScale(2, 2)"
Check renderer.CoordinatesToWindow(1, 2, x, y), "Failed: renderer.CoordinatesToWindow(1, 2, x, y)"
Local localX:Float, localY:Float
Check renderer.CoordinatesFromWindow(x, y, localX, localY), "Failed: renderer.CoordinatesFromWindow(x, y, localX, localY)"
Check Abs(localX - 1) < 0.001 And Abs(localY - 2) < 0.001, "Failed: Abs(localX - 1) < 0.001 And Abs(localY - 2) < 0.001"
Check renderer.SetTarget(target), "Failed: renderer.SetTarget(target)"
Check renderer.GetLogicalPresentation(width, height, mode), "Failed: renderer.GetLogicalPresentation(width, height, mode)"
Check width = 4 And height = 4 And mode = SDL_LOGICAL_PRESENTATION_STRETCH, "Failed: width = 4 And height = 4 And mode = SDL_LOGICAL_PRESENTATION_STRETCH"
Check renderer.SetTarget(), "Failed: renderer.SetTarget()"
Check renderer.GetLogicalPresentation(width, height, mode), "Failed: renderer.GetLogicalPresentation(width, height, mode)"
Check width = 16 And height = 16 And mode = SDL_LOGICAL_PRESENTATION_LETTERBOX, "Failed: width = 16 And height = 16 And mode = SDL_LOGICAL_PRESENTATION_LETTERBOX"
Check renderer.SetLogicalPresentation(0, 0, SDL_LOGICAL_PRESENTATION_DISABLED), "Failed: renderer.SetLogicalPresentation(0, 0, SDL_LOGICAL_PRESENTATION_DISABLED)"
texture.Destroy()
target.Destroy()
renderer.Destroy()
Check Not renderer.RenderGeometry(triangle), "Failed: Not renderer.RenderGeometry(triangle)"
Check Not renderer.CoordinatesFromWindow(1, 1, x, y), "Failed: Not renderer.CoordinatesFromWindow(1, 1, x, y)"
Check Abs(x) < 0.001 And Abs(y) < 0.001, "Expected zero coordinates, got " + x + ", " + y
window.Destroy()
Print "SDL3 geometry and logical presentation tests passed"
