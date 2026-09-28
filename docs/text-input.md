# Text input and the clipboard

## Committed text

`SDL3.SDL3Graphics` starts text input when it creates a graphics window. Ordinary
BlitzMax `GetChar()` and `EVENT_KEYCHAR` handling therefore work without an extra
SDL-specific call. A raw `TSDLWindow.Create` leaves input disabled; call
`window.StartTextInput()` explicitly. Stop it with `window.StopTextInput()` and
query it with `window.TextInputActive()`.

These window functions must be called on the main thread. Check their Int boolean
result and use `SDL_GetError()` after failure.

## IME composition

An input method may offer provisional text before committing it. Subscribe to
`EVENT_SDL3_TEXT_EDITING` through the normal BlitzMax event/hook APIs and cast
`event.extra` to `TSDLTextEditingEvent`:

```blitzmax
If event.id = EVENT_SDL3_TEXT_EDITING Then
	Local editing:TSDLTextEditingEvent = TSDLTextEditingEvent(event.extra)
	If editing.windowID = window.GetID() Then
		composition = editing.text
	End If
End If
```

Display this separately from your committed text. Empty composition text clears
that display. Committed characters continue through `EVENT_KEYCHAR`/`GetChar`;
composition updates never insert characters into that stream. Native observers
that capture keyboard input also suppress composition delivery to BlitzMax.

The payload owns its String and may be retained after dispatch. `start` and
`length` preserve SDL's selection offsets, including -1 when unspecified. They
are not converted into BlitzMax UTF-16 indices; do not directly slice a BlitzMax
String using them without accounting for the input method's offsets.

Use `window.ClearComposition()` to dismiss native composition without stopping
text input. Clear your own displayed composition when changing text fields or
stopping input; do not depend on every platform emitting an empty update then.
Candidate-list events and custom candidate rendering are not yet wrapped; SDL
continues to manage the platform's native candidate UI.

## Position the candidate UI

```blitzmax
Local area:SSDLRect = New SSDLRect(20, 40, 300, 24)
If Not window.SetTextInputArea(area, 80) Then Throw SDL_GetError()
```

The rectangle uses **SDL window coordinates**. The cursor offset (80 above) is
relative to the rectangle's left edge. These are not drawable pixels, virtual
resolution coordinates or camera/world coordinates. Convert your text field's
position to native window coordinates first.

`GetTextInputArea(rect, cursor)` returns the configured values;
`ResetTextInputArea()` restores SDL's default. On a failed query, the wrapper
initialises the outputs to zero. Candidate placement is ultimately controlled by
the platform/input method.

Run `tests/text_input_manual.bmx` with a real video driver to try typing and
composition. Its title shows committed and provisional text separately. Escape
closes it. Automated tests cannot validate the placement of a real IME popup.

## Clipboard text

Import `SDL3.SDL3Clipboard` to add text clipboard access:

```blitzmax
Import SDL3.SDL3Clipboard

' After SDL video initialisation, on the main thread:
If Not SDLSetClipboardText("Hello") Then Throw SDL_GetError()
Local text:String = SDLGetClipboardText()
```

`SDLHasClipboardText()` reports nonempty text. Setting an empty string clears the
text clipboard. Retrieved text is copied into a BlitzMax String and the native
allocation is released; callers do not free it.

An empty result can mean empty contents or failure. If that distinction matters,
call `SDL_ClearError()` before reading and inspect `SDL_GetError()` afterwards.
Only text is supported here: arbitrary MIME data and the X11 primary selection
are separate, future APIs.

`tests/clipboard_composition.bmx` checks Unicode (including a surrogate pair),
multiline/empty clipboard text, input-area roundtrips, composition capture and
retained payloads. It refuses to run unless the SDL dummy video driver is active,
so running this regression cannot overwrite your desktop clipboard.
