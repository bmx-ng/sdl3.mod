SuperStrict

Module SDL3.SDL3Render
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3Video
Import SDL3.SDL3Surface
Import "glue.c"

Const SDL_TEXTUREACCESS_STATIC:Int = 0
Const SDL_TEXTUREACCESS_STREAMING:Int = 1
Const SDL_TEXTUREACCESS_TARGET:Int = 2
Const SDL_BLENDMODE_NONE:Int = 0
Const SDL_BLENDMODE_BLEND:Int = 1
Const SDL_BLENDMODE_ADD:Int = 2
Const SDL_BLENDMODE_MOD:Int = 4
Const SDL_BLENDMODE_MUL:Int = 8
Const SDL_SCALEMODE_NEAREST:Int = 0
Const SDL_SCALEMODE_LINEAR:Int = 1

Const SDL_LOGICAL_PRESENTATION_DISABLED:Int = 0
Const SDL_LOGICAL_PRESENTATION_STRETCH:Int = 1
Const SDL_LOGICAL_PRESENTATION_LETTERBOX:Int = 2
Const SDL_LOGICAL_PRESENTATION_OVERSCAN:Int = 3
Const SDL_LOGICAL_PRESENTATION_INTEGER_SCALE:Int = 4

Rem
bbdoc: A geometry vertex with render position, floating-point RGBA colour and normalised texture coordinates.
about: Colours normally use 0..1. The constructor defaults to opaque white. A zero-initialised vertex has zero alpha; initialise colours before drawing.
End Rem
Struct SSDLVertex
	Field x:Float
	Field y:Float
	Field r:Float
	Field g:Float
	Field b:Float
	Field a:Float
	Field u:Float
	Field v:Float

	Method New(x:Float, y:Float, r:Float = 1, g:Float = 1, b:Float = 1, a:Float = 1, u:Float = 0, v:Float = 0)
		Self.x = x
		Self.y = y
		Self.r = r
		Self.g = g
		Self.b = b
		Self.a = a
		Self.u = u
		Self.v = v
	End Method
End Struct

Rem
bbdoc: An owned renderer whose window must remain alive for drawing.
about: Call Destroy explicitly. Destroying the renderer invalidates its textures. Methods reject resources whose owning window or renderer has been destroyed through these wrappers. Native pointer fields are borrowed handles; do not destroy them separately or use them after their owner closes.
End Rem
Type TSDLRenderer
	Field rendererPtr:Byte Ptr
	Field _window:TSDLWindow
	Field _target:TSDLTexture

	Function Create:TSDLRenderer(window:TSDLWindow, driver:String = "")
		If Not window Or Not window.windowPtr Then Return Null
		Local ptr:Byte Ptr = bmx_SDL3_CreateRenderer(window.windowPtr, driver)
		If Not ptr Then Return Null
		Local renderer:TSDLRenderer = New TSDLRenderer
		renderer.rendererPtr = ptr
		renderer._window = window
		Return renderer
	End Function

	Rem
	bbdoc: Returns whether this renderer and its window are still alive.
	End Rem
	Method IsValid:Int()
		Return rendererPtr <> Null And _window <> Null And _window.windowPtr <> Null
	End Method

	Method SetDrawColor:Int(red:Int, green:Int, blue:Int, alpha:Int = 255)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetRenderDrawColor(rendererPtr, red, green, blue, alpha)
	End Method

	Method Clear:Int()
		If Not IsValid() Then Return False
		Return bmx_SDL3_RenderClear(rendererPtr)
	End Method

	Method Present:Int()
		If Not IsValid() Then Return False
		Return bmx_SDL3_RenderPresent(rendererPtr)
	End Method

	Method SetVSync:Int(interval:Int)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetRenderVSync(rendererPtr, interval)
	End Method

	Method FillRect:Int(rect:SSDLFRect Var)
		If Not IsValid() Then Return False
		Return bmx_SDL3_RenderFillRect(rendererPtr, rect)
	End Method

	Rem
	bbdoc: Creates an owned texture. Format zero selects SDL RGBA32 byte order.
	about: Access is STATIC, STREAMING or TARGET. Check for Null: formats and render-target support depend on the renderer.
	End Rem
	Method CreateTexture:TSDLTexture(format:UInt, access:Int, width:Int, height:Int)
		If Not IsValid() Then Return Null
		Return TSDLTexture._create(bmx_SDL3_CreateTexture(rendererPtr, format, access, width, height), Self)
	End Method

	Rem
	bbdoc: Selects an owned target texture, or Null for the window.
	about: The texture must belong to this renderer and have TARGET access. SDL keeps viewport, clip and scale state per target. A failed switch leaves the current target unchanged.
	End Rem
	Method SetTarget:Int(texture:TSDLTexture = Null)
		If Not IsValid() Then Return False
		Local targetPtr:Byte Ptr
		If texture Then
			If Not texture.IsValid() Or texture._renderer <> Self Then Return False
			targetPtr = texture.texturePtr
		End If
		If Not bmx_SDL3_SetRenderTarget(rendererPtr, targetPtr) Then Return False
		_target = texture
		Return True
	End Method

	Rem
	bbdoc: Returns the target selected through this wrapper, or Null for the window.
	about: Returns the same wrapper, not a second owner. Do not change targets by calling native SDL functions behind this wrapper.
	End Rem
	Method GetTarget:TSDLTexture()
		If Not IsValid() Then Return Null
		Return _target
	End Method

	Rem
	bbdoc: Sets the current target's viewport in SDL render coordinates.
	End Rem
	Method SetViewport:Int(rect:SSDLRect Var)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetRenderViewport(rendererPtr, rect)
	End Method

	Rem
	bbdoc: Gets the current target's viewport in SDL render coordinates.
	End Rem
	Method GetViewport:Int(rect:SSDLRect Var)
		rect = New SSDLRect
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetRenderViewport(rendererPtr, rect)
	End Method

	Rem
	bbdoc: Resets the current target's viewport in SDL render coordinates.
	End Rem
	Method ResetViewport:Int()
		If Not IsValid() Then Return False
		Return bmx_SDL3_ResetRenderViewport(rendererPtr)
	End Method

	Rem
	bbdoc: Sets the current target's cliprect in SDL render coordinates.
	End Rem
	Method SetClipRect:Int(rect:SSDLRect Var)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetRenderClipRect(rendererPtr, rect)
	End Method

	Rem
	bbdoc: Gets the current target's cliprect in SDL render coordinates.
	End Rem
	Method GetClipRect:Int(rect:SSDLRect Var)
		rect = New SSDLRect
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetRenderClipRect(rendererPtr, rect)
	End Method

	Rem
	bbdoc: Resets the current target's cliprect in SDL render coordinates.
	End Rem
	Method ResetClipRect:Int()
		If Not IsValid() Then Return False
		Return bmx_SDL3_ResetRenderClipRect(rendererPtr)
	End Method

	Method ViewportSet:Int()
		If Not IsValid() Then Return False
		Return bmx_SDL3_RenderViewportSet(rendererPtr)
	End Method

	Method ClipEnabled:Int()
		If Not IsValid() Then Return False
		Return bmx_SDL3_RenderClipEnabled(rendererPtr)
	End Method

	Method SetBlendMode:Int(value:Int)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetRenderDrawBlendMode(rendererPtr, value)
	End Method

	Method GetBlendMode:Int(value:Int Var)
		value = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetRenderDrawBlendMode(rendererPtr, Varptr value)
	End Method

	Method SetScale:Int(x:Float, y:Float)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetRenderScale(rendererPtr, x, y)
	End Method

	Method GetScale:Int(x:Float Var, y:Float Var)
		x = 0
		y = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetRenderScale(rendererPtr, Varptr x, Varptr y)
	End Method

	Rem
	bbdoc: Draws coloured or textured triangles with optional zero-based Int indices.
	about: Without indices (or with an empty index array) each three vertices form a triangle. Empty vertex arrays are rejected. Textures must belong to this renderer and be unlocked. Vertex colour supplies modulation; SDL ignores texture colour/alpha modulation for geometry. Arrays are borrowed for the duration of this main-thread call only.
	End Rem
	Method RenderGeometry:Int(vertices:SSDLVertex[], texture:TSDLTexture = Null, indices:Int[] = Null)
		If Not IsValid() Or Not vertices Or vertices.Length = 0 Then Return False
		Local textureHandle:Byte Ptr
		If texture Then
			If Not texture.IsValid() Or texture._lock Or texture._renderer <> Self Then Return False
			textureHandle = texture.texturePtr
		End If
		Local indexHandle:Int Ptr
		Local count:Int
		If indices Then
			count = indices.Length
			If count = 0 Or count Mod 3 Then Return False
			For Local index:Int = EachIn indices
				If index < 0 Or index >= vertices.Length Then Return False
			Next
			indexHandle = Varptr indices[0]
		Else
			If vertices.Length Mod 3 Then Return False
		End If
		Return bmx_SDL3_RenderGeometry(rendererPtr, textureHandle, Varptr vertices[0], vertices.Length, indexHandle, count)
	End Method

	Rem
	bbdoc: Sets logical size and presentation for the current render target.
	about: Modes include stretch, letterbox, overscan and integer scale. DISABLED restores native rendering. This does not transform BlitzMax events; convert input coordinates explicitly.
	End Rem
	Method SetLogicalPresentation:Int(width:Int, height:Int, mode:Int)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetRenderLogicalPresentation(rendererPtr, width, height, mode)
	End Method

	Method GetLogicalPresentation:Int(width:Int Var, height:Int Var, mode:Int Var)
		width = 0
		height = 0
		mode = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetRenderLogicalPresentation(rendererPtr, Varptr width, Varptr height, Varptr mode)
	End Method

	Rem
	bbdoc: Returns the output rectangle occupied by the logical presentation.
	End Rem
	Method GetLogicalPresentationRect:Int(rect:SSDLFRect Var)
		rect = New SSDLFRect
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetRenderLogicalPresentationRect(rendererPtr, rect)
	End Method

	Rem
	bbdoc: Converts coordinates from SDL native window space using the current target's logical presentation, viewport and scale.
	about: Coordinates in letterbox bars are not clamped to the logical content. This is not a Max2D camera conversion.
	End Rem
	Method CoordinatesFromWindow:Int(x:Float, y:Float, outX:Float Var, outY:Float Var)
		outX = 0
		outY = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_RenderCoordinatesFromWindow(rendererPtr, x, y, Varptr outX, Varptr outY)
	End Method

	Rem
	bbdoc: Converts coordinates to SDL native window space using the current target's logical presentation, viewport and scale.
	about: Coordinates in letterbox bars are not clamped to the logical content. This is not a Max2D camera conversion.
	End Rem
	Method CoordinatesToWindow:Int(x:Float, y:Float, outX:Float Var, outY:Float Var)
		outX = 0
		outY = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_RenderCoordinatesToWindow(rendererPtr, x, y, Varptr outX, Varptr outY)
	End Method

	Method CreateTextureFromSurface:TSDLTexture(surface:TSDLSurface)
		If Not IsValid() Or Not surface Or Not surface.surfacePtr Then Return Null
		Return TSDLTexture._create(SDL_CreateTextureFromSurface(rendererPtr, surface.surfacePtr), Self)
	End Method

	Method RenderTexture:Int(texture:TSDLTexture, destination:SSDLFRect Var)
		If Not IsValid() Then Return False
		If Not texture Or Not texture.IsValid() Or texture._lock Then Return False
		If texture._renderer <> Self Then Return False
		Return bmx_SDL3_RenderTexture(rendererPtr, texture.texturePtr, destination)
	End Method

	Method RenderTexturePart:Int(texture:TSDLTexture, source:SSDLFRect Var, destination:SSDLFRect Var)
		If Not IsValid() Then Return False
		If Not texture Or Not texture.IsValid() Or texture._lock Then Return False
		If texture._renderer <> Self Then Return False
		Return bmx_SDL3_RenderTexturePart(rendererPtr, texture.texturePtr, source, destination)
	End Method

	Rem
	bbdoc: Reads the current render target into a new surface owned by the caller.
	End Rem
	Method ReadPixels:TSDLSurface()
		If Not IsValid() Then Return Null
		Return TSDLSurface._create(SDL_RenderReadPixels(rendererPtr, Null))
	End Method

	Method Destroy()
		If rendererPtr Then
			SDL_DestroyRenderer(rendererPtr)
			rendererPtr = Null
			_window = Null
			_target = Null
		End If
	End Method
End Type

Rem
bbdoc: A texture owned by its renderer.
about: Call Destroy to release it early. After renderer or window destruction, IsValid returns False and texture operations fail safely. Destroy is safe to repeat. Close resources before SDL_Quit.
End Rem
Type TSDLTexture
	Field texturePtr:Byte Ptr
	Field _renderer:TSDLRenderer
	Field _lock:TSDLTextureLock

	Function _create:TSDLTexture(ptr:Byte Ptr, renderer:TSDLRenderer)
		If Not ptr Then Return Null
		Local texture:TSDLTexture = New TSDLTexture
		texture.texturePtr = ptr
		texture._renderer = renderer
		Return texture
	End Function

	Rem
	bbdoc: Returns whether the texture, its renderer and its window are still alive.
	End Rem
	Method IsValid:Int()
		If Not _renderer Or Not _renderer.IsValid() Then texturePtr = Null
		Return texturePtr <> Null
	End Method

	Method SetBlendMode:Int(value:Int)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetTextureBlendMode(texturePtr, value)
	End Method

	Method GetBlendMode:Int(value:Int Var)
		value = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetTextureBlendMode(texturePtr, Varptr value)
	End Method

	Method SetScaleMode:Int(value:Int)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetTextureScaleMode(texturePtr, value)
	End Method

	Method GetScaleMode:Int(value:Int Var)
		value = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetTextureScaleMode(texturePtr, Varptr value)
	End Method

	Rem
	bbdoc: Uploads packed pixels to the whole texture.
	about: Pitch is bytes per row. The byte array must contain every referenced row. Planar/FourCC and indexed formats are rejected. Use the texture's native format; no conversion occurs. SDL copies the bytes during the call.
	End Rem
	Method Update:Int(pixels:Byte[], pitch:Int)
		If Not IsValid() Or _lock Or Not pixels Or pixels.Length = 0 Then Return False
		Return bmx_SDL3_UpdateTexture(texturePtr, Null, Varptr pixels[0], pixels.Length, pitch)
	End Method

	Rem
	bbdoc: Uploads packed pixels to a texture subrectangle.
	about: The array begins at the subrectangle's top-left pixel, not at the full image origin. Bounds, pitch and array length are checked before SDL reads the data.
	End Rem
	Method UpdateRect:Int(rect:SSDLRect Var, pixels:Byte[], pitch:Int)
		If Not IsValid() Or _lock Or Not pixels Or pixels.Length = 0 Then Return False
		Return bmx_SDL3_UpdateTexture(texturePtr, Varptr rect, Varptr pixels[0], pixels.Length, pitch)
	End Method

	Method SetColorMod:Int(red:Int, green:Int, blue:Int)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetTextureColorMod(texturePtr, red, green, blue)
	End Method

	Method GetColorMod:Int(red:Int Var, green:Int Var, blue:Int Var)
		red = 0
		green = 0
		blue = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetTextureColorMod(texturePtr, Varptr red, Varptr green, Varptr blue)
	End Method

	Method SetColorModFloat:Int(red:Float, green:Float, blue:Float)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetTextureColorModFloat(texturePtr, red, green, blue)
	End Method

	Method GetColorModFloat:Int(red:Float Var, green:Float Var, blue:Float Var)
		red = 0
		green = 0
		blue = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetTextureColorModFloat(texturePtr, Varptr red, Varptr green, Varptr blue)
	End Method

	Method SetAlphaMod:Int(alpha:Int)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetTextureAlphaMod(texturePtr, alpha)
	End Method

	Method GetAlphaMod:Int(alpha:Int Var)
		alpha = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetTextureAlphaMod(texturePtr, Varptr alpha)
	End Method

	Method SetAlphaModFloat:Int(alpha:Float)
		If Not IsValid() Then Return False
		Return bmx_SDL3_SetTextureAlphaModFloat(texturePtr, alpha)
	End Method

	Method GetAlphaModFloat:Int(alpha:Float Var)
		alpha = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetTextureAlphaModFloat(texturePtr, Varptr alpha)
	End Method

	Rem
	bbdoc: Locks the entire streaming texture for write-only access.
	about: Returns Null if already locked, invalid or unsupported. Close the returned ICloseable scope explicitly or with Using. Initialise every pixel before closing; old pixels are not preserved.
	End Rem
	Method Lock:TSDLTextureLock()
		Return _LockRegion(Null)
	End Method

	Rem
	bbdoc: Locks a rectangle of a streaming texture for write-only access.
	End Rem
	Method LockRect:TSDLTextureLock(rect:SSDLRect Var)
		Return _LockRegion(Varptr rect)
	End Method

	Method _LockRegion:TSDLTextureLock(rect:Byte Ptr)
		If Not IsValid() Or _lock Then Return Null
		Local scope:TSDLTextureLock = New TSDLTextureLock
		If Not bmx_SDL3_LockTexture(texturePtr, rect, Varptr scope._pixels, Varptr scope._pitch, Varptr scope._width, Varptr scope._height, Varptr scope._bytes) Then Return Null
		scope._texture = Self
		_lock = scope
		Return scope
	End Method

	Rem
	bbdoc: Closes the active texture lock, if any. Safe to repeat.
	End Rem
	Method Unlock()
		If _lock Then _lock.Close()
	End Method

	Method GetSize:Int(width:Float Var, height:Float Var)
		width = 0
		height = 0
		If Not IsValid() Then Return False
		Return bmx_SDL3_GetTextureSize(texturePtr, Varptr width, Varptr height)
	End Method

	Method Destroy()
		Unlock()
		If IsValid() Then
			If _renderer._target = Self Then _renderer._target = Null
			SDL_DestroyTexture(texturePtr)
		End If
		texturePtr = Null
		_renderer = Null
	End Method
End Type

Rem
bbdoc: A deterministic write-only texture lock. Supports Using and explicit Close.
about: CopyFrom validates the source buffer and copies packed rows. Pixels is an optional borrowed pointer, valid only while this scope and all owners are alive. Never retain it across Close, Unlock or owner destruction. No GC finalizer calls SDL; close before SDL_Quit. Accessors return zero/Null once invalid.
End Rem
Type TSDLTextureLock Implements ICloseable
	Field _texture:TSDLTexture
	Field _pixels:Byte Ptr
	Field _pitch:Int
	Field _width:Int
	Field _height:Int
	Field _bytes:Int

	Method IsValid:Int()
		Return _pixels <> Null And _texture <> Null And _texture.IsValid()
	End Method

	Method Pixels:Byte Ptr()
		If IsValid() Then Return _pixels
	End Method

	Method Pitch:Int()
		If IsValid() Then Return _pitch
	End Method

	Method Width:Int()
		If IsValid() Then Return _width
	End Method

	Method Height:Int()
		If IsValid() Then Return _height
	End Method

	Method CopyFrom:Int(pixels:Byte[], pitch:Int)
		If Not IsValid() Or Not pixels Or pixels.Length = 0 Then Return False
		Local row:Long = Long(_width) * _bytes
		Local required:Long = Long(_height - 1) * pitch + row
		If pitch < row Or required > pixels.Length Then Return False
		For Local y:Int = 0 Until _height
			MemCopy _pixels + Long(y) * _pitch, Varptr pixels[0] + Long(y) * pitch, Size_T(row)
		Next
		Return True
	End Method

	Method Close()
		If _texture Then
			If IsValid() Then bmx_SDL3_UnlockTexture(_texture.texturePtr)
			_texture._lock = Null
		End If
		_texture = Null
		_pixels = Null
		_pitch = 0
		_width = 0
		_height = 0
		_bytes = 0
	End Method
End Type

Extern
	Function bmx_SDL3_RenderGeometry:Int(renderer:Byte Ptr, texture:Byte Ptr, vertices:Byte Ptr, count:Int, indices:Int Ptr, indexCount:Int)
	Function bmx_SDL3_SetRenderLogicalPresentation:Int(renderer:Byte Ptr, width:Int, height:Int, mode:Int)
	Function bmx_SDL3_GetRenderLogicalPresentation:Int(renderer:Byte Ptr, width:Int Ptr, height:Int Ptr, mode:Int Ptr)
	Function bmx_SDL3_GetRenderLogicalPresentationRect:Int(renderer:Byte Ptr, rect:SSDLFRect Var)
	Function bmx_SDL3_RenderCoordinatesFromWindow:Int(renderer:Byte Ptr, x:Float, y:Float, outX:Float Ptr, outY:Float Ptr)
	Function bmx_SDL3_RenderCoordinatesToWindow:Int(renderer:Byte Ptr, x:Float, y:Float, outX:Float Ptr, outY:Float Ptr)
	Function bmx_SDL3_LockTexture:Int(texture:Byte Ptr, rect:Byte Ptr, pixels:Byte Ptr Ptr, pitch:Int Ptr, width:Int Ptr, height:Int Ptr, bytes:Int Ptr)
	Function bmx_SDL3_UnlockTexture(texture:Byte Ptr)
	Function bmx_SDL3_SetTextureColorMod:Int(texture:Byte Ptr, red:Int, green:Int, blue:Int)
	Function bmx_SDL3_GetTextureColorMod:Int(texture:Byte Ptr, red:Int Ptr, green:Int Ptr, blue:Int Ptr)
	Function bmx_SDL3_SetTextureColorModFloat:Int(texture:Byte Ptr, red:Float, green:Float, blue:Float)
	Function bmx_SDL3_GetTextureColorModFloat:Int(texture:Byte Ptr, red:Float Ptr, green:Float Ptr, blue:Float Ptr)
	Function bmx_SDL3_SetTextureAlphaMod:Int(texture:Byte Ptr, alpha:Int)
	Function bmx_SDL3_GetTextureAlphaMod:Int(texture:Byte Ptr, alpha:Int Ptr)
	Function bmx_SDL3_SetTextureAlphaModFloat:Int(texture:Byte Ptr, alpha:Float)
	Function bmx_SDL3_GetTextureAlphaModFloat:Int(texture:Byte Ptr, alpha:Float Ptr)
	Function bmx_SDL3_CreateTexture:Byte Ptr(renderer:Byte Ptr, format:UInt, access:Int, width:Int, height:Int)
	Function bmx_SDL3_SetRenderTarget:Int(renderer:Byte Ptr, texture:Byte Ptr)
	Function bmx_SDL3_SetRenderViewport:Int(renderer:Byte Ptr, rect:SSDLRect Var)
	Function bmx_SDL3_GetRenderViewport:Int(renderer:Byte Ptr, rect:SSDLRect Var)
	Function bmx_SDL3_ResetRenderViewport:Int(renderer:Byte Ptr)
	Function bmx_SDL3_SetRenderClipRect:Int(renderer:Byte Ptr, rect:SSDLRect Var)
	Function bmx_SDL3_GetRenderClipRect:Int(renderer:Byte Ptr, rect:SSDLRect Var)
	Function bmx_SDL3_ResetRenderClipRect:Int(renderer:Byte Ptr)
	Function bmx_SDL3_RenderViewportSet:Int(renderer:Byte Ptr)
	Function bmx_SDL3_RenderClipEnabled:Int(renderer:Byte Ptr)
	Function bmx_SDL3_SetRenderDrawBlendMode:Int(renderer:Byte Ptr, value:Int)
	Function bmx_SDL3_GetRenderDrawBlendMode:Int(renderer:Byte Ptr, value:Int Ptr)
	Function bmx_SDL3_SetTextureBlendMode:Int(texture:Byte Ptr, value:Int)
	Function bmx_SDL3_GetTextureBlendMode:Int(texture:Byte Ptr, value:Int Ptr)
	Function bmx_SDL3_SetTextureScaleMode:Int(texture:Byte Ptr, value:Int)
	Function bmx_SDL3_GetTextureScaleMode:Int(texture:Byte Ptr, value:Int Ptr)
	Function bmx_SDL3_SetRenderScale:Int(renderer:Byte Ptr, x:Float, y:Float)
	Function bmx_SDL3_GetRenderScale:Int(renderer:Byte Ptr, x:Float Ptr, y:Float Ptr)
	Function bmx_SDL3_UpdateTexture:Int(texture:Byte Ptr, rect:Byte Ptr, pixels:Byte Ptr, length:Int, pitch:Int)
	Function bmx_SDL3_CreateRenderer:Byte Ptr(window:Byte Ptr, driver:String)
	Function bmx_SDL3_SetRenderDrawColor:Int(renderer:Byte Ptr, red:Int, green:Int, blue:Int, alpha:Int)
	Function bmx_SDL3_RenderClear:Int(renderer:Byte Ptr)
	Function bmx_SDL3_RenderPresent:Int(renderer:Byte Ptr)
	Function bmx_SDL3_SetRenderVSync:Int(renderer:Byte Ptr, interval:Int)
	Function bmx_SDL3_RenderFillRect:Int(renderer:Byte Ptr, rect:SSDLFRect Var)
	Function bmx_SDL3_RenderTexture:Int(renderer:Byte Ptr, texture:Byte Ptr, destination:SSDLFRect Var)
	Function bmx_SDL3_RenderTexturePart:Int(renderer:Byte Ptr, texture:Byte Ptr, source:SSDLFRect Var, destination:SSDLFRect Var)
	Function bmx_SDL3_GetTextureSize:Int(texture:Byte Ptr, width:Float Ptr, height:Float Ptr)
	Function SDL_CreateTextureFromSurface:Byte Ptr(renderer:Byte Ptr, surface:Byte Ptr)
	Function SDL_RenderReadPixels:Byte Ptr(renderer:Byte Ptr, rect:Byte Ptr)
	Function SDL_DestroyTexture(texture:Byte Ptr)
	Function SDL_DestroyRenderer(renderer:Byte Ptr)
End Extern
