# Controlling SDL3 windows

`TSDLWindow` exposes ordinary desktop window controls without requiring a Max2D
backend. Call these methods on the main thread. A False result means failure;
inspect `SDL_GetError()` immediately. A successful request still follows the
platform's window-manager policy.

## Decorations and resizing

```blitzmax
If Not window.SetResizable(True) Then Throw SDL_GetError()
If Not window.SetBordered(True) Then Throw SDL_GetError()
If Not window.SetMinimumSize(320, 180) Then Throw SDL_GetError()
If Not window.SetMaximumSize(1920, 1080) Then Throw SDL_GetError()
```

`GetMinimumSize(width, height)` and `GetMaximumSize(width, height)` query the
limits. Zero removes the corresponding limit. SDL rejects conflicting limits;
check each return value. Query outputs are initialised to zero before SDL is called.

These values are client sizes in **native SDL window coordinates**. They are not
physical framebuffer sizes, Max2D virtual coordinates or the logical sizes exposed
by the BRL graphics adapter. Use the appropriate conversion when working through
that adapter, especially on displays with scaling.

`GetFlags()` exposes `SDL_WINDOW_RESIZABLE`, `SDL_WINDOW_BORDERLESS`,
`SDL_WINDOW_MINIMIZED` and `SDL_WINDOW_MAXIMIZED`. A headless driver may accept a
request without updating decorations or flags; it has no real window manager.

## Desktop transitions

- `Minimize()` requests minimisation.
- `Maximize()` requests maximisation; the window must be resizable.
- `Restore()` requests restoration from minimised/maximised state.
- `Raise()` requests raising and focus. Platforms may refuse to steal focus.
- `Sync()` waits for pending window transitions where supported.

Requests can complete asynchronously. `Sync()` can block; use it when a transition
must be settled before querying state, not every frame. Success does not guarantee
that a compositor will honour focus, placement or size requests. Maximisation is
separate from exclusive or borderless fullscreen.

## Window icons

`SetIcon(surface)` copies the icon from a `TSDLSurface`. You can destroy the source
surface after the call succeeds. Passing a missing/destroyed surface returns False.
Per-window icons are platform-dependent; macOS uses the application bundle icon
rather than a title-bar icon. This function does not rewrite the bundle icon.

## Mouse confinement

`SetMouseGrab(True)` requests confinement to the window while it has focus;
`SetMouseGrab(False)` releases it. `GetMouseGrab()` queries SDL's current state.
The `SDL_WINDOW_MOUSE_GRABBED` and `SDL_WINDOW_MOUSE_CAPTURE` flags are also exposed.

For a smaller region, use `SetMouseRect(rect)`. The rectangle uses native window
coordinates and is copied by SDL. `GetMouseRect(rect)` copies it back; False with a
zero rectangle means no region or an invalid window. No borrowed native rectangle
pointer escapes to BlitzMax. `ResetMouseRect()` removes the region.

Region confinement is platform-dependent. Check the setter result, and always
provide a way to release confinement. These settings differ from:

- **Capture:** receiving movement outside the window during a drag.
- **Relative mode:** hidden-pointer continuous movement, typically for a camera.

See [mouse and cursor controls](mouse.md) for those APIs.

## Test coverage

`tests/window_controls.bmx` runs with `SDL_VIDEODRIVER=dummy`. It checks boolean
normalisation, size-limit roundtrips and conflicting limits, invalid handles,
missing/destroyed icon surfaces, and unsupported operations. It explicitly expects
the dummy driver to reject maximise/minimise/restore and rectangle confinement;
it does not treat these failures as a visual desktop test.

`tests/window_controls_manual.bmx` checks real decoration/resizable flag changes
and size-limit roundtrips at launch. Then use:

- **1 / 2 / 3:** maximise, restore, minimise (restore a minimised window from the OS).
- **B:** toggle borders.
- **G:** toggle whole-window mouse grab.
- **C:** toggle a smaller confinement rectangle, if supported.
- **Escape:** release confinement and close.

The initial native checks pass on macOS arm64. Dummy-driver tests pass in both
debug and release. Visual transitions, confinement behaviour and Windows/Linux
window-manager policies still need interactive validation. Icon display was not
verified on a platform with per-window icons.
