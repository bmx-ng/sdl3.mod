SuperStrict

Framework SDL3.SDL3Render
Import BRL.StandardIO
Import "test_helpers.bmx"

Local window:TSDLWindow = TSDLWindow.Create("Renderer API", 16, 16, SDL_WINDOW_HIDDEN)
Check window
Local renderer:TSDLRenderer = TSDLRenderer.Create(window, "software")
Check renderer, SDL_GetError()
Local texture:TSDLTexture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_STATIC, 2, 2)
Local target:TSDLTexture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_TARGET, 8, 8)
Check texture And target, SDL_GetError()
Local bytes:Byte[24] ' Two RGBA rows, pitch 16; final row needs only 8 bytes.
For Local row:Int = 0 Until 2
	For Local x:Int = 0 Until 2
		bytes[row * 16 + x * 4] = 255
		bytes[row * 16 + x * 4 + 3] = 255
	Next
Next
Check texture.Update(bytes, 16)
Check Not texture.Update(bytes[..23], 16), "Short upload accepted"
Check Not texture.Update(bytes, 7), "Short pitch accepted"
Local outside:SSDLRect = New SSDLRect(2, 0, 1, 1)
Check Not texture.UpdateRect(outside, bytes, 4), "Out-of-bounds upload accepted"
Local patch:SSDLRect = New SSDLRect(0, 0, 1, 1)
Local green:Byte[] = [0:Byte, 255:Byte, 0:Byte, 255:Byte]
Check texture.UpdateRect(patch, green, 4)
Check texture.SetScaleMode(SDL_SCALEMODE_NEAREST)
Check texture.SetBlendMode(SDL_BLENDMODE_NONE)
Local value:Int
Check texture.GetScaleMode(value) And value = SDL_SCALEMODE_NEAREST
Check texture.GetBlendMode(value) And value = SDL_BLENDMODE_NONE
Check renderer.SetBlendMode(SDL_BLENDMODE_NONE)
Check renderer.GetBlendMode(value) And value = SDL_BLENDMODE_NONE
Check renderer.SetTarget(target)
Check renderer.GetTarget() = target
Check Not renderer.SetTarget(texture), "Static texture accepted as render target"
Check renderer.GetTarget() = target, "Failed switch changed target"
Check renderer.SetDrawColor(0, 0, 0)
Check renderer.Clear()
Local destination:SSDLFRect = New SSDLFRect(0, 0, 8, 8)
Check renderer.RenderTexture(texture, destination)
Local pixels:TSDLSurface = renderer.ReadPixels()
Local r:Int, g:Int, b:Int, a:Int
Check pixels.ReadPixel(1, 1, r, g, b, a)
Check r = 0 And g = 255 And b = 0
Check pixels.ReadPixel(6, 6, r, g, b, a)
Check r = 255 And g = 0 And b = 0
pixels.Destroy()
Local viewport:SSDLRect = New SSDLRect(1, 1, 6, 6)
Local clip:SSDLRect = New SSDLRect(1, 1, 2, 2)
Check renderer.SetViewport(viewport)
Check renderer.ViewportSet()
Check renderer.SetClipRect(clip)
Check renderer.ClipEnabled()
Check renderer.SetScale(2, 2)
Local sx:Float, sy:Float
Check renderer.GetScale(sx, sy) And sx = 2 And sy = 2
Check renderer.SetScale(1, 1)
Check renderer.SetDrawColor(0, 0, 255)
Check renderer.FillRect(destination)
Check renderer.SetTarget()
Check renderer.GetTarget() = Null
Check Not renderer.ClipEnabled(), "Target clip leaked into window state"
Check renderer.SetTarget(target)
Local copy:SSDLRect
Check renderer.GetViewport(copy) And copy.Equals(viewport)
Check renderer.GetClipRect(copy) And copy.Equals(clip)
Check renderer.ResetViewport()
Check renderer.ResetClipRect()
Check Not renderer.ViewportSet() And Not renderer.ClipEnabled()
pixels = renderer.ReadPixels()
Check pixels.ReadPixel(2, 2, r, g, b, a)
Check r = 0 And g = 0 And b = 255, "Viewport/clip origin was wrong"
Check pixels.ReadPixel(5, 5, r, g, b, a)
Check r = 255 And g = 0 And b = 0, "Clipping did not protect outside pixels"
pixels.Destroy()
Local otherWindow:TSDLWindow = TSDLWindow.Create("Other", 8, 8, SDL_WINDOW_HIDDEN)
Local other:TSDLRenderer = TSDLRenderer.Create(otherWindow, "software")
Check other
Check Not other.SetTarget(target), "Foreign target accepted"
other.Destroy()
otherWindow.Destroy()
target.Destroy() ' SDL resets to the window when the active target is destroyed.
Check renderer.GetTarget() = Null
Check renderer.SetDrawColor(0, 0, 0) And renderer.Clear()
texture.Destroy()
Check Not texture.Update(bytes, 16)
renderer.Destroy()
Check Not renderer.SetTarget()
window.Destroy()
Print "SDL3 renderer target and upload tests passed"
