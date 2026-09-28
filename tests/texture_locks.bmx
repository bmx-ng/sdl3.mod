SuperStrict

Framework SDL3.SDL3Render
Import BRL.StandardIO
Import "test_helpers.bmx"

Local window:TSDLWindow = TSDLWindow.Create("Texture locks", 8, 8, SDL_WINDOW_HIDDEN)
Check window
Local renderer:TSDLRenderer = TSDLRenderer.Create(window, "software")
Check renderer
Local texture:TSDLTexture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_STREAMING, 2, 2)
Check texture
Local white:Byte[16]
For Local i:Int = 0 Until white.Length
	white[i] = 255
Next
Local destination:SSDLFRect = New SSDLFRect(0, 0, 2, 2)
Local retained:TSDLTextureLock
Using
	Local scope:TSDLTextureLock = texture.Lock()
Do
	Check scope, SDL_GetError()
	retained = scope
	Check scope.Width() = 2 And scope.Height() = 2 And scope.Pitch() >= 8
	Check scope.Pixels() <> Null
	Check Not texture.Lock(), "Nested lock accepted"
	Check Not scope.CopyFrom(white[..15], 8)
	Check Not scope.CopyFrom(white, 7)
	Check scope.CopyFrom(white, 8)
	Check Not texture.Update(white, 8), "Update accepted during lock"
	Check Not renderer.RenderTexture(texture, destination), "Drawing accepted during lock"
End Using
Check Not retained.IsValid() And retained.Pixels() = Null And retained.Pitch() = 0
retained.Close()
Local caught:Int
Try
	Using
		Local scope:TSDLTextureLock = texture.Lock()
	Do
		Check scope And scope.CopyFrom(white, 8)
		Throw "scope exception"
	End Using
Catch error:Object
	caught = String(error) = "scope exception"
End Try
Check caught
Local scope:TSDLTextureLock = texture.Lock()
Check scope, "Exception left texture locked"
Check scope.CopyFrom(white, 8)
texture.Unlock()
Check Not scope.IsValid()
scope.Close()
Local region:SSDLRect = New SSDLRect(1, 1, 1, 1)
scope = texture.LockRect(region)
Check scope And scope.Width() = 1 And scope.Height() = 1
Check scope.CopyFrom(white[..4], 4)
scope.Close()
region.x = 2
Check Not texture.LockRect(region), "Out-of-bounds lock accepted"
Local staticTexture:TSDLTexture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_STATIC, 2, 2)
Check staticTexture And Not staticTexture.Lock(), "Static texture lock accepted"
staticTexture.Destroy()
Check texture.SetColorMod(128, 64, 32)
Check texture.SetAlphaMod(128)
Local r:Int, g:Int, b:Int, a:Int
Check texture.GetColorMod(r, g, b) And r = 128 And g = 64 And b = 32
Check texture.GetAlphaMod(a) And a = 128
Check Not texture.SetColorMod(-1, 0, 0)
Check Not texture.SetAlphaMod(256)
Check texture.SetColorModFloat(0.5, 0.25, 0.125)
Check texture.SetAlphaModFloat(0.5)
Local rf:Float, gf:Float, bf:Float, af:Float
Check texture.GetColorModFloat(rf, gf, bf) And rf = 0.5 And gf = 0.25 And bf = 0.125
Check texture.GetAlphaModFloat(af) And af = 0.5
Check texture.SetColorMod(128, 64, 32)
Check texture.SetAlphaMod(255)
Check texture.SetBlendMode(SDL_BLENDMODE_NONE)
Check texture.SetScaleMode(SDL_SCALEMODE_NEAREST)
Check renderer.SetDrawColor(0, 0, 0)
Check renderer.Clear()
Check renderer.RenderTexture(texture, destination)
Local pixels:TSDLSurface = renderer.ReadPixels()
Check pixels And pixels.ReadPixel(0, 0, r, g, b, a)
Check Abs(r - 128) <= 1 And Abs(g - 64) <= 1 And Abs(b - 32) <= 1, "Modulated pixels incorrect"
pixels.Destroy()
scope = texture.Lock()
Check scope And scope.CopyFrom(white, 8)
texture.Destroy()
Check Not scope.IsValid() And scope.Pixels() = Null
scope.Close()
texture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_STREAMING, 2, 2)
scope = texture.Lock()
Check scope And scope.CopyFrom(white, 8)
renderer.Destroy()
Check Not scope.IsValid() And scope.Pixels() = Null
scope.Close()
texture.Destroy()
renderer = TSDLRenderer.Create(window, "software")
Check renderer
texture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_STREAMING, 2, 2)
scope = texture.Lock()
Check scope And scope.CopyFrom(white, 8)
window.Destroy()
Check Not scope.IsValid() And scope.Pixels() = Null
scope.Close()
texture.Destroy()
renderer.Destroy()
Print "SDL3 texture lock and modulation tests passed"
