# Using SDL3's renderer directly

Import `SDL3.SDL3Render` for SDL's renderer API without Max2D. All renderer and
texture operations belong on the main thread. Check results: capabilities and
accepted pixel formats depend on the selected SDL renderer.

## Create and upload a texture

```blitzmax
Local texture:TSDLTexture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_STATIC, 2, 2)
If Not texture Then Throw SDL_GetError()
Local pixels:Byte[] = [255:Byte, 0:Byte, 0:Byte, 255:Byte, ..
	255:Byte, 0:Byte, 0:Byte, 255:Byte, ..
	255:Byte, 0:Byte, 0:Byte, 255:Byte, ..
	255:Byte, 0:Byte, 0:Byte, 255:Byte]
If Not texture.Update(pixels, 8) Then Throw SDL_GetError()
```

Format **0** selects SDL's native `RGBA32` byte ordering: red, green, blue, alpha
bytes on either endian architecture. Other format arguments are **SDL pixel-format
values**, not BRL.Pixmap/PixelFormat constants. No implicit conversion is performed.

Access is `SDL_TEXTUREACCESS_STATIC`, `SDL_TEXTUREACCESS_STREAMING` or
`SDL_TEXTUREACCESS_TARGET`. Streaming textures can be updated or locked for write-only access; see below.

`Update(bytes, pitch)` replaces all pixels; `UpdateRect(rect, bytes, pitch)` updates
a region. Pitch is bytes per row, including padding. The array starts at the first
pixel of the uploaded region, even for a subrectangle. It must contain
`(height - 1) * pitch + width * bytesPerPixel` bytes. Bounds, pitch and length are
checked before SDL receives the buffer. SDL copies the data during the call.
Planar/FourCC and indexed formats are rejected by these packed-pixel helpers.

`SetScaleMode`/`GetScaleMode` select/query nearest or linear sampling.
`SetBlendMode`/`GetBlendMode` on a texture control texture-copy blending. The same
method names on a renderer control primitive-drawing blending. SDL blend modes
are not Max2D blend constants, and SDL renderer limitations still apply.

## Render into a texture

```blitzmax
Local target:TSDLTexture = renderer.CreateTexture(0, SDL_TEXTUREACCESS_TARGET, 256, 256)
If Not target Then Throw SDL_GetError()
If Not renderer.SetTarget(target) Then Throw SDL_GetError()
renderer.SetDrawColor(0, 0, 0, 255)
renderer.Clear()
' Draw here.
If Not renderer.SetTarget() Then Throw SDL_GetError() ' Back to the window.
```

Targets must belong to the same renderer and have TARGET access. Failed switches
leave the current target unchanged. `GetTarget()` returns the existing wrapper,
not a second owner. Destroying the selected target returns rendering to the window.
Do not change targets through raw SDL calls behind the wrapper.

`ReadPixels()` returns a newly owned surface for the current target/viewport.
Destroy that surface after use. Reset the viewport first when you want a full-target
readback. Texture contents are undefined until you initialise them.

## Viewport, clip and scale

- `SetViewport(rect)`, `GetViewport(rect)`, `ResetViewport()`, `ViewportSet()`.
- `SetClipRect(rect)`, `GetClipRect(rect)`, `ResetClipRect()`, `ClipEnabled()`.
- `SetScale(x, y)` and `GetScale(x, y)`.

These use SDL render coordinates and apply to the current target. Clip coordinates
are relative to its viewport. SDL retains viewport, clip and scale independently
for each target, including the window. They do not apply Max2D virtual-resolution
or camera transformations.

`Clear()` clears the entire current target, ignoring viewport/clip. Use filled
rectangles when you need a clipped clear. `Present()` is for presenting the window;
switch back to it first.

## Ownership and errors

Textures retain their renderer wrapper; renderers retain their window wrapper.
Closing an owner invalidates operations on its children. Explicitly destroy
resources before SDL shutdown. Repeated destruction is safe; raw handle fields
are borrowed and must not be freed independently.

SDL failures return False/Null and set SDL_GetError. Wrapper-level invalid-owner,
empty-array and foreign-renderer checks can return False without setting a new SDL
error; validate resource lifetime rather than relying on a stale error string.
Getter outputs are initialised before use.

## Validation

`tests/renderer_targets.bmx` runs against SDL's software renderer. It checks actual
readback colours after padded uploads, subrectangle updates and clipped drawing;
rejects short buffers, short pitches, out-of-bounds rectangles and foreign/static
targets; checks per-target state restoration and active-target destruction.

It passes in debug and release on macOS arm64. The existing surface/texture and
input/lifetime release regressions also pass. Hardware renderer and Windows/Linux
checks remain outstanding for these newly exposed APIs.

The wider renderer property APIs are not yet covered by this public wrapper.

## Colour and alpha modulation

Textures expose `SetColorMod(red, green, blue)` and `SetAlphaMod(alpha)`, with
corresponding getters. Integer channels must be in 0..255; out-of-range values
return False. The Float variants (`SetColorModFloat`, `GetColorModFloat`,
`SetAlphaModFloat`, `GetAlphaModFloat`) preserve floating-point channel values.
A value of 1.0 is neutral; support for values outside the usual range follows SDL
and the renderer. Getters return False with zero outputs after owner destruction.

Modulation affects later texture-copy operations, not the stored source pixels.
Alpha modulation and the selected blend mode together determine compositing.

## Streaming texture locks

```blitzmax
Using
	Local scope:TSDLTextureLock = texture.Lock()
Do
	If Not scope Then Throw SDL_GetError()
	If Not scope.CopyFrom(pixels, sourcePitch) Then Throw "Invalid pixel buffer"
End Using
```

Use a texture created with `SDL_TEXTUREACCESS_STREAMING`. `LockRect(rect)` locks
a subrectangle; the scope's Width and Height describe that region. Both lock forms
currently accept packed, non-indexed formats, like the update helpers.

Locks are **write-only**. Initialise every pixel of the locked region before
closing; the old pixels are not guaranteed to be available. `CopyFrom` validates
the byte-array length and source pitch and copies each row using SDL's destination
pitch. It does not convert formats.

For manual control, call `scope.Close()` or `texture.Unlock()`. Both are safe to
repeat. `Using` calls Close on normal exit and exceptions. There is no GC finalizer
that unlocks SDL resources: deterministic main-thread release is required.

`Pixels()` and `Pitch()` allow direct access when needed. That pointer is borrowed
and is valid only until unlock or destruction of the texture, renderer or window.
Never cache it across those operations. Accessors return Null/zero after
invalidation, but an already-copied raw pointer cannot be revoked by the wrapper.

Nested locks, uploads while locked and drawing the locked texture are rejected.
Destroying the texture closes its lock; closing a scope after renderer/window
teardown does not call SDL with a stale texture handle. Close all resources before
SDL_Quit, and never destroy the native handles separately.

`tests/texture_locks.bmx` passes in debug and release with macOS software rendering.
It checks normal/exceptional Using cleanup, explicit unlock, source-buffer bounds,
subrectangles, unsupported static locks, owner destruction, modulation getters and
actual modulated pixel readback. Hardware and Windows/Linux checks remain open.

## Triangle geometry

`SSDLVertex` contains `x`, `y`, floating-point `r`, `g`, `b`, `a`, and normalised
texture coordinates `u`, `v`. Its constructor defaults to opaque white; default
zero-initialised array elements instead have zero alpha, so initialise every vertex.

```blitzmax
Local vertices:SSDLVertex[3]
vertices[0] = New SSDLVertex(10, 10, 1, 0, 0)
vertices[1] = New SSDLVertex(100, 10, 0, 1, 0)
vertices[2] = New SSDLVertex(10, 100, 0, 0, 1)
If Not renderer.RenderGeometry(vertices) Then Throw SDL_GetError()
```

Pass a texture as the second argument and optional `Int[]` indices as the third.
Indices are zero-based; the index count must be divisible by three and every index
must address an existing vertex. Without indices, the vertex count must be a
multiple of three. Empty vertex arrays are rejected.

A textured mesh must use an unlocked texture from the same renderer. Vertex
colours supply modulation; SDL ignores texture colour/alpha modulation settings
for this operation. Arrays are only borrowed during the call. Blend support and
geometry behaviour follow the selected SDL renderer.

## Logical presentation and input

```blitzmax
If Not renderer.SetLogicalPresentation(320, 180, SDL_LOGICAL_PRESENTATION_LETTERBOX) Then
	Throw SDL_GetError()
End If
```

Available modes are DISABLED, STRETCH, LETTERBOX, OVERSCAN and INTEGER_SCALE.
`GetLogicalPresentation(width, height, mode)` queries the setting;
`GetLogicalPresentationRect(rect)` returns its output rectangle. State is retained
separately for each render target, including the window.

This is SDL's own logical presentation. It does not update Max2D's virtual
resolution or transform BlitzMax mouse events automatically. Given mouse values
in **native SDL window coordinates**, call:

```blitzmax
Local renderX:Float, renderY:Float
If Not renderer.CoordinatesFromWindow(windowX, windowY, renderX, renderY) Then
	Throw SDL_GetError()
End If
```

`CoordinatesToWindow` performs the inverse. Conversion includes pixel density,
logical presentation, viewport and scale for the current target. Select the target
whose coordinate system you mean before converting. Coordinates in bars are not
clamped; test the resulting position against your content bounds if necessary.
Avoid applying these conversions a second time to coordinates already transformed
by a Max2D camera or canvas.

`tests/geometry_presentation.bmx` checks coloured and indexed textured geometry by
pixel readback, invalid indices, per-target logical state, letterbox bounds and
input conversion including viewport/scale. It passes in debug and release using
macOS software rendering. Hardware and Windows/Linux validation remains pending.
