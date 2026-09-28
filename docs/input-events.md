# Input events and multiple windows

Import `SDL3.SDL3System` directly or through the SDL3 graphics driver. Standard BRL
keyboard, mouse and touch events keep their usual IDs and integer fields. Their
`source` stays Null; use `event.extra` for copied SDL-specific data:

| Event | Payload in extra |
| --- | --- |
| KEYDOWN / KEYUP / KEYREPEAT | TSDLKeyboardEvent |
| KEYCHAR from a control key | TSDLKeyboardEvent |
| KEYCHAR from committed text | TSDLTextInputEvent |
| MOUSEMOVE / MOUSEDOWN / MOUSEUP | TSDLMouseEvent |
| MOUSEWHEEL and SDL3_MOUSE_WHEEL | TSDLMouseWheelEvent |
| TOUCHDOWN / TOUCHMOVE / TOUCHUP | TSDLTouchEvent |

All these types inherit `TSDLInputEvent`, with `windowID` and the native
nanosecond `timestamp`. Payloads contain values rather than native event pointers,
so you may retain them after polling. A window ID does not keep a window alive.
Synthetic releases during focus loss have timestamp zero and zero-valued native
key/button/position details; the BRL event still identifies the released key or
button. This metadata adds a managed allocation per translated native input event.

## Find the originating window

```blitzmax
Local input:TSDLInputEvent = TSDLInputEvent(event.extra)
If input And input.windowID = window.GetID() Then
	' Handle input for this window.
End If
```

Mouse coordinates are SDL window coordinates. They are not framebuffer pixels or
Max2D virtual/world coordinates; use the relevant graphics/camera conversion for
those spaces. Mouse payloads preserve fractional position, relative movement,
button clicks and device identity. Payload button numbering is SDL's; BRL event
`data` retains BlitzMax numbering. The BRL path exposes five mouse buttons to match
BRL.PolledInput's storage; native observers can inspect other buttons.

## Smooth wheel scrolling

For trackpads or horizontal scrolling, handle `EVENT_SDL3_MOUSE_WHEEL`:

```blitzmax
If event.id = EVENT_SDL3_MOUSE_WHEEL Then
	Local wheel:TSDLMouseWheelEvent = TSDLMouseWheelEvent(event.extra)
	scrollX :+ wheel.x
	scrollY :+ wheel.y
End If
```

`x` and `y` retain SDL's raw values. `direction` is 0 for normal and 1 for flipped;
the binding does not reverse the values. `mouseX`/`mouseY` locate the pointer.

For existing applications, `EVENT_MOUSEWHEEL` accumulates vertical fractions until
a whole step is available, separately for each window and mouse. A movement of
2.5 produces two steps and retains 0.5. Negative movement works the same way.
Focus loss discards the window's remainder. Horizontal-only movement emits only
the detailed event. Choose one wheel interface to avoid counting movement twice.

## Touch contacts

`TSDLTouchEvent` preserves unsigned 64-bit `touchID` and `fingerID`, normalized
position/deltas, pressure and `canceled`. BRL's integer `data` is a positive slot
allocated to the active device/finger pair. It remains stable during the contact
and may be reused after it ends; do not use it as a persistent device identifier.
Legacy x/y still scale normalized coordinates by 10000.

SDL cancellation emits `EVENT_TOUCHUP` with `canceled = True`. Losing window
focus also cancels outstanding delivered contacts; these synthetic cancellations
have zero position/pressure. Unmatched native release/cancel events are ignored.

## Focus and capture

Moving focus between SDL windows in the same polling batch does not produce an
application suspend/resume pair. The binding also checks SDL's current keyboard
focus before suspending. Leaving the application's windows produces
`EVENT_APPSUSPEND`; returning produces `EVENT_APPRESUME`. `WaitSystem` drains
pending events after waking so it can resolve an in-queue focus transfer too.

Held keys/buttons delivered for a window are released when that window loses
focus or is destroyed. BRL.PolledInput therefore does not retain stale pressed
states during an internal focus transfer. SDL continues to manage native capture
and relative-mode behaviour; the binding does not disable another window's mode.

Native observers still see every event. Capture suppresses translation, including
detailed wheel and touch cancellation events, **except releases needed to finish
input already delivered to BRL**. Starting capture midway through a held key,
button or touch must not leave that input stuck. A fully captured gesture creates
no BRL contact and delivers no terminal event.

## Text and drops

Committed text retains the existing UTF-16 `EVENT_KEYCHAR` contract: a non-BMP
character produces two code-unit events. Both share a `TSDLTextInputEvent`
containing the complete committed string and window identity. Applications needing
a complete commit can process each distinct payload once. Composition remains
separate; see [text input](text-input.md).

`EVENT_SDL3_TEXT_DROP` carries `TSDLTextDropEvent` in `extra`, with a copied `text`,
window identity, timestamp and floating-point x/y. Its legacy event `data` is the
window ID and x/y are integer drop coordinates. Existing file drops keep
`EVENT_APPOPENFILE` with the path string in `extra` and window ID in `data`.

## Validation

`tests/input_fidelity.bmx` checks fractional/per-window wheel accumulation,
full-width touch ID collisions, cancellation/capture, held input across focus
transfers, text drops, retained payloads and non-BMP code-unit delivery. These are
synthetic events. Real trackpads, touchscreens, OS drops, IME and window-manager
focus transitions still need desktop/device checks.

Build `tests/input_windows_manual.bmx` as a console application to inspect two
real windows. Click between them, hold keys/buttons while switching focus, scroll
and drop selected text from another application. Window titles show the received
data; the console reports application suspend/resume. Switching only between
these two windows should not suspend the application. Close either window or
press Escape to exit.
