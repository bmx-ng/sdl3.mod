# Drawing into a MaxGUI canvas

On macOS, import `SDL3.SDL3MaxGUI` alongside `Max2D.SDL3RenderMax2D` to draw with SDL3 inside a native MaxGUI canvas:

```blitzmax
SuperStrict

Framework MaxGUI.Drivers
Import SDL3.SDL3MaxGUI
Import Max2D.SDL3RenderMax2D
Import BRL.TimerDefault
Import BRL.EventQueue
```

This requires BRL.System 1.31 and the corresponding SDL3 and Max2D attachment updates. Windows, Linux and the native SDL GPU Max2D backend are not supported by this bridge yet.

Build and run [the canvas example](../sdl3maxgui.mod/examples/canvas.bmx). It combines an editable native text field, a button, a timer and a resizable drawing surface. Click the canvas to check its mouse-event counter, type into the field, and resize the window to try the integration.

## Drawing and resizing

Create a canvas with `CreateCanvas()`, then obtain its graphics using `CanvasGraphics(canvas)`. MaxGUI calls the current graphics driver's `AttachGraphics()` for you. Select those graphics before drawing:

```blitzmax
SetGraphics(CanvasGraphics(canvas))
Cls
DrawText "Hello from an attached canvas", 20, 20
Flip(0)
```

Use `RedrawGadget(canvas)` to request painting, and draw when you receive `EVENT_GADGETPAINT` for that canvas. A native timer can request regular redraws. Use the normal MaxGUI `WaitEvent()` loop; no extra `PollSystem()` is necessary.

`GraphicsWidth()` and `GraphicsHeight()` describe the canvas's client area in logical units, excluding its border. The backend uses the corresponding Retina pixel dimensions for rendering. Resize and position the **gadget**, not its graphics. Attached graphics do not support Max2D fullscreen operations: the containing window belongs to MaxGUI.

Multiple canvases may use separate renderers. This initial macOS implementation selects SDL's Metal renderer for attached canvases.

## Input and timers

MaxGUI remains responsible for keyboard, mouse, focus and gadget events. Use `EventSource()`, `EventX()` and `EventY()` as in an ordinary MaxGUI application. SDL's duplicate translations of those native events are suppressed.

Native timers continue to work. If you explicitly use `TSDLTimer.Create()` from `SDL3.SDL3Timer`, its queued timer events also wake a sleeping MaxGUI event loop. SDL lifecycle notifications queued by the binding use the same wakeup mechanism. Native producers integrating with this bridge can call `bmx_SDL3_NotifyEventQueued()` after successfully pushing an SDL event; an SDL event watch alone is too early to guarantee a wakeup after queuing.

The bridge drains SDL's queue after host polling without running a second native event pump. It does not yet provide general SDL controller polling, standalone SDL windows alongside the GUI, or ImGui input handling inside attached canvases. Those need additional routing; importing the ImGui SDL platform backend is not sufficient to enable them.

## Ownership and cleanup

The host gadget must outlive its attached graphics. MaxGUI closes the graphics it created when the gadget is freed. If you manually attach or reattach graphics, close those graphics yourself before freeing the gadget.

Closing attached graphics releases the renderer and its drawing subview; it does not destroy the MaxGUI window or other controls. Release images/resources tied to a renderer before closing it, as you would with standalone graphics.

## Existing applications

The bridge is opt-in. Standalone SDL3 applications use the SDL system driver when no explicit host system driver exists. Ordinary MaxGUI applications continue using their native driver. Import order does not choose which system driver wins: an explicit native driver takes precedence over the SDL fallback.

The macOS checks cover canvas resize and drawable dimensions, pixel readback, multiple canvases, repeated attachment, SDL timer wakeups and both import orders. Existing native MaxGUI/BRL.GLMax2D and standalone SDL3/ImGui tests are also exercised.
