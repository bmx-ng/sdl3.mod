# Resource ownership and callbacks

## Windows and OpenGL contexts

A window created with `TSDLWindow.Create` is explicitly owned. Call `Destroy`
when finished; retaining its BlitzMax object does not stop explicit destruction.
Its native handles are borrowed. Do not destroy them through a separate native
API and then continue using the wrapper.

`window.GLCreateContext()` creates an owned context associated with that window.
The context retains its window wrapper, and the window tracks all contexts it
created. `context.Free()` removes it from that list. `window.Destroy()` frees
remaining contexts before destroying the native window. This matters because SDL
window destruction detaches the current context and can unload the GL library;
it does not itself provide the wrapper's context ownership policy.

- `context.IsValid()` becomes false after either explicit context cleanup or
  owner-window destruction.
- Repeated `Free`/`Destroy` calls are harmless after successful cleanup.
- `window.GLMakeCurrent(context)` rejects freed contexts and contexts created by
  another window. Cross-window context migration is not exposed by this wrapper.
- `context.SetSwapInterval` requires that context to be current; it cannot silently
  change a different context's interval.
- If native context destruction fails, its handle is retained for retry. Window
  destruction stops instead of destroying a window with an unreleased context.
  Inspect `SDL_GetError` and the handles when diagnosing such a failure.

Use window/context operations on the main thread. These wrappers are not intended
for concurrent destruction or raw-handle ownership transfer. They do not rely on
GC finalizers to perform graphics cleanup.

Window size, pixel-size and position output parameters, and GL attribute outputs,
are zeroed on failure. Always check the returned Int boolean before using them.

Renderer/texture wrappers separately track their owners and reject operations on
invalidated resources. This review does not introduce shared ownership of native
resources or make arbitrary raw-handle mutation safe.

## Callback boundaries

Lifecycle callbacks invoked on the main thread run immediately inside SDL's event
watch. Lifecycle events from other threads are queued for main-thread delivery.
The driver is explicitly rooted while SDL holds its callback userdata and is
released after SDL shuts down its event machinery.

An exception must not unwind through SDL's event-watch code or leave the native
observer dispatcher half-finished. Lifecycle callbacks and managed timer,
joystick and gamepad observers therefore catch exceptions and retain the first
pending exception on the system driver. `PollSystem` or `WaitSystem` rethrows it
after native dispatch returns, or before starting the next poll/wait if the error
was already pending. Other events in the current dispatch may have run before
that rethrow. Additional exceptions while one is pending do not replace the first.

Catch those errors around your polling/event loop if the application can recover.
BRL.System now clears its polling guard before rethrowing, so catching an error
does not permanently disable further polling. Lifecycle callbacks must not poll
recursively. Native third-party observers must contain their own language
exceptions; this policy is implemented by the supplied managed trampolines.

## Timers

SDL's timer thread queues a native event; managed timer work happens during
main-thread polling. Stopping a timer removes its managed registration before
removing the native timer, so already-queued ticks no longer invoke it. It is safe
to stop a timer from its own event hook or to stop it repeatedly.

Timer frequencies must be finite and positive. Frequencies whose millisecond
interval exceeds SDL's UInt32 range fail creation. Sub-millisecond intervals are
limited to one millisecond. A failed creation returns Null and supplies an SDL
error; it does not create a fallback one-hertz timer.

Ticks remain best-effort SDL queue events. Queue saturation, filtering and long
periods without polling can lose or delay ticks; this is not a real-time clock.
Lifecycle queue saturation and wider callback reentrancy/shutdown stress remain
explicit review items, rather than certified behaviour.

## Checks

`tests/callback_lifetime.bmx` covers lifecycle exceptions on both delivery paths,
timer/controller observer exceptions, recovery, stopped queued ticks, stopping
inside a callback, repeated cleanup and invalid timer rates.
`tests/gl_context_lifetime.bmx` requires a desktop GL driver and covers multiple
contexts, current-context checks, owner-first destruction and repeated cleanup.
