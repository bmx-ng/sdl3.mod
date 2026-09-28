# Mouse input and cursors

Import `SDL3.SDL3Mouse` for owned cursors, floating-point mouse queries and capture.
Create an SDL window first and call these APIs on the main thread.

## Cursors

```blitzmax
Local cursor:TSDLCursor = TSDLCursor.CreateSystem(SDL_SYSTEM_CURSOR_POINTER)
If Not cursor Then Throw SDL_GetError()
If Not cursor.Set() Then Throw SDL_GetError()

' When no longer needed, on the main thread:
cursor.Destroy()
```

System shapes include arrow/default, text, wait, crosshair, pointer and resize
cursors. `CreateColor(surface, hotX, hotY)` copies an SDL surface into a colour
cursor. Its hotspot must lie inside the image; the source surface may be destroyed
once creation succeeds.

The wrapper owns only cursors it creates. `SDLResetCursor()` selects SDL's default
without handing ownership of that default to the caller. Destroying an active
owned cursor also restores the default. `Destroy()` is idempotent, and `Set()`
returns False after destruction.

Explicitly destroy cursors before SDL shutdown. There is no GC finalizer: SDL
cursor destruction belongs on the main thread. Treat `cursorPtr` as a borrowed
native handle and do not free it separately.

`SDLSetCursorVisible(enabled)` reports success; `SDLCursorVisible()` queries the
visibility setting. Relative mode may hide the actual cursor even when this
setting is enabled. Cursor shape/visibility state is shared across SDL windows.

## Relative mode

```blitzmax
If Not window.SetRelativeMouseMode(True) Then Throw SDL_GetError()

' Once per frame, after PollSystem:
Local dx:Float, dy:Float
Local buttons:UInt = SDLGetRelativeMouseState(dx, dy)

' Release when leaving the mode:
window.SetRelativeMouseMode(False)
```

Relative mode is requested per window and takes effect while that window has
focus. SDL hides and constrains the pointer and supplies continuous relative
movement. `GetRelativeMouseMode()` reports the requested setting, not proof that
an unfocused window is currently controlling the pointer. Changing mode flushes
pending motion for the window.

The relative-state query consumes accumulated deltas; coordinate queries use
SDL's cached state from the last event pump. Query once and share the result if
several parts of your game need the same movement. Button flags use
`SDL_BUTTON_LMASK`, `SDL_BUTTON_RMASK`, and the other SDL masks, not BlitzMax
button numbering.

`SDLGetMouseState(x, y)` supplies floating-point native window coordinates. Neither
query applies virtual resolution or camera transformations. Native observer input
capture suppresses translated BlitzMax events, but does not suppress these direct
state queries; a UI integration must decide when the game should ignore them.

## Capture during dragging

`SDLCaptureMouse(True)` requests capture for the foreground window. It allows
movement outside that window without hiding or constraining the pointer. Release
with `SDLCaptureMouse(False)` when the operation ends. SDL also releases capture
on focus loss, and normally performs automatic capture while a mouse button is
held, so an ordinary drag may need no explicit capture at all.

Capture is different from relative mode. Check its result: some platforms do not
support it. Coordinates outside the window may be negative. Avoid holding capture
for the entire application session.

## Try it

Build `tests/mouse_manual.bmx` as a GUI app. At launch it checks system and colour
cursor creation, destroying a source surface, destroying an active cursor and
repeated destruction. The title reports when those checks pass.

- Press **R** to toggle relative mode; the title reports accumulated motion.
- Hold **Space** to request capture and release it to end capture.
- Press **Escape** or close the window to release the modes and destroy the cursor.

`tests/mouse_controls.bmx` is an automated dummy-driver test. It verifies failure
handling, visibility, boolean conversion, relative-state consumption and closed
windows. It deliberately does not claim native cursor or physical mouse coverage.
