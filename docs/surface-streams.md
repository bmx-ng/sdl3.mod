# BMP surfaces from files and streams

SDL itself supplies the BMP decoder/encoder. This support does not use SDL_image
or replace BlitzMax's existing image loaders.

`TSDLSurface.LoadBMP(source)` and `surface.SaveBMP(destination)` accept:

- A filesystem filename.
- A registered BlitzMax stream URL.
- An existing `TStream`.

They open through `ReadStream`/`WriteStream`, so BRL.IO mounts are honoured when
MaxIO is initialised. Import and configure any additional stream provider your
application needs. No temporary file or full-file memory copy is introduced.

## Memory example

```blitzmax
Import SDL3.SDL3Surface
Import BRL.BankStream

Local stream:TBankStream = CreateBankStream(Null)
Local surface:TSDLSurface = TSDLSurface.Create(32, 32)
surface.Fill(20, 100, 200)
If Not surface.SaveBMP(stream) Then Throw SDL_GetError()

stream.Seek(0)
Local loaded:TSDLSurface = TSDLSurface.LoadBMP(stream)
If Not loaded Then Throw SDL_GetError()

loaded.Destroy()
surface.Destroy()
stream.Close()
```

## Position and ownership

Operations begin at the stream's current position. SDL's BMP implementation needs
seeking (including writing header offsets after encoding), so forward-only streams
are rejected. Wrap or stage those in a seekable stream yourself if needed.

Caller streams remain open. A successful save flushes the stream. Streams opened
internally from a filename/URL are closed on success and failure. Existing caller
streams are not truncated, and writes before the initial position are preserved.
Saving to an existing stream can leave trailing data after the BMP.

Paths use the normal WriteStream overwrite behaviour. A failed operation can leave
partial output or move the stream position; it does not provide transactions or
position rollback.

## Errors and callback safety

Open/decode/encode failures return Null/False; inspect `SDL_GetError`. Exceptions
raised by a stream's read/write/seek callbacks are caught before returning through
SDL's C stack, then rethrown after the native adapter and owned resources are
cleaned up. Flush/close exceptions also propagate after cleanup. If both a callback
and close fail, the callback exception is preserved.

Callbacks run synchronously on the calling BlitzMax thread. The adapter retains
its managed context for the native call, including when a stream triggers GC. This
is a BMP bridge, not a general SDL_IOStream object that can escape to another
thread or remain alive after the call.

## Regression coverage

`tests/bmp_streams.bmx` checks a BMP after a prefix, three-byte partial transfers,
Unicode-independent pixel roundtrip, caller ownership, registered URL factories,
GC during a read, read/write/seek/flush exceptions, owned-stream cleanup on failure,
zero-progress writes, non-seekable streams and truncated input.

`tests/surface_texture.bmx` retains its file-based BMP roundtrip. Both tests pass in
debug and release on macOS arm64. Cross-platform and actual archive-mount checks
remain part of the wider release validation.
