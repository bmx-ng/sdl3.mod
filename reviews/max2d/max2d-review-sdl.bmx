SuperStrict
Framework SDL.SDLRenderMax2D
Import BRL.StandardIO
Import BRL.Retro

Extern
	Function SDL_GetTextureScaleMode:Int(texture:Byte Ptr, mode:Int Ptr)
End Extern

SetGraphicsDriver(SDLRenderMax2DDriver(), 0)
SDLSetPreferredRenderer("software")
Local g:TGraphics = Graphics(64, 64, 0, 0)
Local driver:TSDLRenderMax2DDriver = SDLRenderMax2DDriver()
Print "renderer=" + driver.ApiIdentifier()

SetClsColor(0, 0, 0, 1.0)
Print "clear alpha requested=1.0 stored byte=" + driver.clsColor.a
Cls()
SetBlend(SOLIDBLEND)
SetColor(255, 255, 255)
SetLineWidth(7)
DrawLine(5, 10, 30, 10)
Local pixels:TPixmap = GrabPixmap(0, 0, 64, 64)
Local rows:Int
For Local y:Int = 0 Until 64
	If (pixels.ReadPixel(15, y) & $ffffff) <> 0 Then rows :+ 1
Next
Print "line width requested=7 rendered rows=" + rows

Local source:TPixmap = CreatePixmap(2, 2, PF_RGBA8888)
source.ClearPixels($ffff0000)
Cls()
SetColor(0, 255, 0)
DrawPixmap(source, 5, 5)
pixels = GrabPixmap(5, 5, 1, 1)
Print "DrawPixmap red with green drawing color RGB=" + Hex(pixels.ReadPixel(0, 0) & $ffffff)

SetColor(255, 255, 255)
Local unfiltered:TImage = LoadImage(source, DYNAMICIMAGE)
Local filtered:TImage = LoadImage(source, FILTEREDIMAGE)
Local uf:TSDLRenderImageFrame = TSDLRenderImageFrame(unfiltered.Frame(0))
Local ff:TSDLRenderImageFrame = TSDLRenderImageFrame(filtered.Frame(0))
Local mode0:Int = -1, mode1:Int = -1
SDL_GetTextureScaleMode(uf.texture.texturePtr, Varptr mode0)
SDL_GetTextureScaleMode(ff.texture.texturePtr, Varptr mode1)
Print "texture scale modes unfiltered=" + mode0 + " filtered=" + mode1

source.ClearPixels($40ff0000)
Local translucent:TImage = LoadImage(source, 0)
Cls()
SetBlend(MASKBLEND)
DrawImage(translucent, 5, 5)
pixels = GrabPixmap(5, 5, 1, 1)
Print "MASKBLEND alpha64 red over black RGB=" + Hex(pixels.ReadPixel(0, 0) & $ffffff)

Local first:TImageFrame = unfiltered.Frame(0)
Local lock:TPixmap = LockImage(unfiltered, 0, True, True)
UnlockImage(unfiltered)
Local second:TImageFrame = unfiltered.Frame(0)
Print "write-lock recreates image frame=" + (first <> second)

Local target:TRenderImage = CreateRenderImage(16, 16, DYNAMICIMAGE)
SetRenderImage(target)
SetClsColor(0, 0, 0, 0.0)
Cls()
SetBlend(ALPHABLEND)
SetColor(255, 0, 0)
SetAlpha(0.5)
DrawRect(0, 0, 16, 16)
pixels = GrabPixmap(0, 0, 1, 1)
Print "half-alpha red stored in target ARGB=" + Hex(pixels.ReadPixel(0, 0))
Local targetCPU:TPixmap = LockImage(target, 0, True, False)
Print "render target read-lock ARGB=" + Hex(targetCPU.ReadPixel(0, 0))
UnlockImage(target)
SetRenderImage(Null)
SetClsColor(0, 0, 0, 1.0)
Cls()
SetColor(255, 255, 255)
SetAlpha(1)
DrawImage(target, 0, 0)
pixels = GrabPixmap(0, 0, 1, 1)
Print "target composited over black RGB=" + Hex(pixels.ReadPixel(0, 0) & $ffffff)
SetRenderImage(target)
SetClsColor(0, 0, 0, 1.0)
Cls()
pixels = GrabPixmap(0, 0, 1, 1)
Print "opaque clear on render target alpha=" + ((pixels.ReadPixel(0, 0) Shr 24) & 255)
SetRenderImage(Null)

Local oldRenderer:TSDLRenderer = driver.renderer
Try
	SetGraphics(g)
	Print "reselect same graphics succeeded"
Catch error:Object
	Print "reselect same graphics failed: " + error.ToString()
	Print "SDL error: " + SDLGetError()
End Try
driver.renderer = oldRenderer
Print "review probe complete"
