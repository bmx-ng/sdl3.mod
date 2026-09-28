# SDL3 modules for BlitzMax NG

This repository contains the SDL3 bindings for BlitzMax NG, currently under development. It contains the unmodified SDL 3.4.16 release in `sdl3.mod/SDL3` and compiles SDL directly from those sources with `bmk`, as `sdl.mod` does for SDL2. It does not require a system SDL3 library.

The working slice includes `SDL3.SDL3` initialization and event-enable functions, `SDL3.SDL3Rect`, an `SDL3.SDL3System` driver, `SDL3.SDL3Video` windows, `SDL3.SDL3Surface` software surfaces and BMP I/O, `SDL3.SDL3Render` textures and software rendering, `SDL3.SDL3Graphics` integration with `BRL.Graphics`, `SDL3.SDL3Thread` managed SDL threads, `SDL3.SDL3Timer`, `SDL3.SDL3Joystick`, `SDL3.SDL3Gamepad`, `SDL3.SDL3Clipboard`, and `SDL3.SDL3Mouse`. Graphics integration has been exercised on macOS and Windows/Linux VMs during the new Max2D work. General SDL3 API coverage remains partial. The 16 standalone headless tests and eight audio tests pass in debug and release on macOS arm64, Linux arm64 and Windows x64 under ARM64 VM emulation. Real desktop/device checks, the final ownership/ABI review and clean-install validation remain on the release checklist. See [input events](docs/input-events.md) for precise wheel/touch data and multiple-window focus handling. See the [coverage audit and release checklist](docs/release-checklist.md) for supported functionality, concrete findings and the next implementation steps.

Public BlitzMax types keep the SDL2 names where they represent the same concept: `TSDLWindow`, `TSDLSurface`, `TSDLRenderer`, `TSDLTexture`, `TSDLGraphics`, `TSDLGraphicsDriver`, `TSDLTimer`, and `TSDLSystemDriver`. The `SDL3` module names identify which implementation is imported. Methods still follow SDL3 where its API differs.

`SDL3.SDL3Graphics` creates an SDL3 renderer by default and exposes it through `SDLGraphicsDriver().GetSDLRenderer()`. With `SDL_GRAPHICS_GL`, it creates an OpenGL window and `TSDLGLContext`, makes the context current in `SetGraphics()`, and swaps it in `Flip()`. Window resize and move events update `BRL.Graphics` settings. SDL3 window properties provide native handles for Cocoa, Win32, X11, Wayland, and Android; validation of each native-handle route is tracked separately from ordinary window rendering. Native widget attachment is still pending. Fullscreen display modes are enumerated through SDL3, and exclusive fullscreen selection uses SDL3's closest mode. The driver maps BlitzMax graphics flags explicitly to SDL3 window flags because their bit values overlap.

For Max2D rendering with SDL3, use `Max2D.SDL3RenderMax2D` or `Max2D.SDL3GPUMax2D` from the separate `max2d.mod` repository. Applications that need the existing `BRL.Max2D` implementation can continue using SDL2. `SDL3.SDL3Graphics` provides general `BRL.Graphics` integration and OpenGL window/context support independently of Max2D.

`SDL3.SDL3Thread` offers `TSDLThread.Create(entry, data, name)`, `Wait()`, and `Detach()`. The C entry registers both the GC and BlitzMax's thread-local runtime state before calling the managed entry, then unregisters before exit. The thread object is retained until its entry finishes; `Wait()` returns its result or rethrows its caught exception. Detached threads release their retained object when they finish. Normal BlitzMax work can still use `BRL.Threads`; SDL timer and lifecycle callbacks continue to queue work to the main thread. Managed SDL thread creation is unavailable on Switch until BlitzMax provides an external-thread registration path there. Managed-thread tests pass in debug and release on macOS arm64, Linux arm64 and Windows x64 (in the ARM64 VM).

`SDL3.SDL3Joystick` installs an `SDL3 Joystick` driver for the standard `Pub.Joystick` functions (`JoyCount`, `JoyX`, `JoyDown`, `JoyHit`, and others). It also exposes `TSDLJoystick` for raw axes, buttons, and hats, and `TSDLVirtualJoystick` for virtual devices. `SDL3.SDL3Gamepad` adds `TSDLGamepad` for SDL3's mapped gamepad axes, buttons, rumble, and mappings. Importing the gamepad module also installs the joystick driver. `SDLJoystickIDs()` and `SDLGamepadIDs()` return SDL3 instance IDs; use these IDs to open devices. `Pub.Joystick` uses its usual zero-based port numbers, which can change when devices connect or disconnect. Both modules emit BlitzMax events for device and input changes while `PollSystem()` or `WaitSystem()` processes SDL events. Their event `data` contains the instance ID, `mods` the control index, and `x` the control value. The virtual-device test covers these interfaces without physical hardware. Rumble and physical hotplug still need hardware validation.

The system driver reads SDL3's event queue and maps keyboard, mouse, touch, window, display, and quit events into BlitzMax events. Native observers all see events during polling, without priority ordering. They may request that keyboard or mouse input be withheld from BlitzMax's event stream, which leaves room for an ImGui SDL3 backend to honor its input-capture flags. SDL3 lifecycle events use `SDL_AddEventWatch`, as required by SDL3. `SetLifecycleCallback` runs immediately when SDL invokes the watch on the BlitzMax main thread. Events delivered from another thread are queued for the next `PollSystem` or `WaitSystem`, avoiding a managed callback on an unregistered thread. The macOS terminate hook forwards to SDL3 events. Open-file forwarding keeps a private UTF-8 copy alive until dispatch (or shutdown for undelivered events). File drops emit `EVENT_APPOPENFILE`, with the path in `extra`, window ID in `data` (zero for application-level opens), and native drop coordinates in `x`/`y`. BRL graphics windows automatically start committed-text input. Raw `TSDLWindow` users explicitly call `StartTextInput`, `StopTextInput` and `TextInputActive`; composition/preedit is delivered through `EVENT_SDL3_TEXT_EDITING`, and windows expose input-area and composition-dismissal controls. See [text input and clipboard usage](docs/text-input.md). SDL3 timers also cross from SDL's timer thread through the native event queue before touching BlitzMax objects.

See [resource ownership and callback errors](docs/ownership-and-callbacks.md) for
GL context lifetime, cleanup and safe exception propagation.

## Boolean ABI

SDL3 uses C `bool` in many public functions. The BlitzMax API uses `Int` for boolean values. Every SDL3 `bool` that crosses the language boundary must go through C glue that converts it to `0` or `1`; incoming `Int` values are converted with `value != 0`. A `bool *` output must first be received in a local C `bool`, then copied into a BlitzMax `Int` output. Do not bind a C `bool` return, argument, or pointer output directly as BlitzMax `Int`.

Other ABI types, including `size_t`, 64-bit IDs, and SDL structures, also require explicit review before exposing them to BlitzMax.

## Audio

`SDL3.SDL3AudioAudio` provides the standard `BRL.Audio` driver selected with
`SetAudioDriver("SDL3")`. `SDL3.SDL3Audio` separately exposes PCM streams,
conversion, playback, recording and device controls. See [audio usage and
limitations](docs/audio.md), including runnable tone and streaming music examples.
Import `Audio.WavStream`, `Audio.VorbisStream`, `Audio.FlacStream` or
`Audio.Mp3Stream` for the formats you need with
`LoadSound(url, SOUND_STREAM)`;
optional decoders register through `Audio.Streams`. The BRL.Audio driver requires
`Audio.Streams` from the separate `audio.mod` repository even when no streaming
decoder is imported.

## Build and smoke test

From the BlitzMax NG SDK root:

```sh
./bin/bmk makemods -r sdl3.sdl3rect
./bin/bmk makeapp -r -o /private/tmp/sdl3-core-rect mod/sdl3.mod/tests/core_rect.bmx
/private/tmp/sdl3-core-rect
./bin/bmk makemods -r sdl3.sdl3test
./bin/bmk makeapp -r -o /private/tmp/sdl3-system-events mod/sdl3.mod/tests/system_events.bmx
/private/tmp/sdl3-system-events
./bin/bmk makeapp -r -o /private/tmp/sdl3-window-render mod/sdl3.mod/tests/window_render.bmx
SDL_VIDEODRIVER=dummy /private/tmp/sdl3-window-render
./bin/bmk makeapp -r -o /private/tmp/sdl3-timer-events mod/sdl3.mod/tests/timer_events.bmx
/private/tmp/sdl3-timer-events
./bin/bmk makeapp -r -o /private/tmp/sdl3-surface-texture mod/sdl3.mod/tests/surface_texture.bmx
SDL_VIDEODRIVER=dummy /private/tmp/sdl3-surface-texture
./bin/bmk makeapp -r -o /private/tmp/sdl3-graphics-driver mod/sdl3.mod/tests/graphics_driver.bmx
SDL_VIDEODRIVER=dummy /private/tmp/sdl3-graphics-driver
./bin/bmk makeapp -r -o /private/tmp/sdl3-graphics-gl mod/sdl3.mod/tests/graphics_gl.bmx
SDL_VIDEODRIVER=cocoa /private/tmp/sdl3-graphics-gl
./bin/bmk makeapp -clean -r -o /private/tmp/sdl3-managed-threads mod/sdl3.mod/tests/managed_threads.bmx
/private/tmp/sdl3-managed-threads
./bin/bmk makeapp -clean -r -o /private/tmp/sdl3-joystick-gamepad mod/sdl3.mod/tests/joystick_gamepad.bmx
/private/tmp/sdl3-joystick-gamepad
```

Omit `-r` for a debug build. Use `-clean` if switching between test applications produces a stale shared-helper link error. The tests cover version and boolean conversion, rectangle results, native event observation and selective input capture, lifecycle delivery, a headless window and renderer, graphics window and flip behavior, OpenGL context creation and native handle lookup, managed thread registration and object lifetime, BMP roundtrip, texture pixels, timer events, and virtual joystick and gamepad input. The OpenGL tests need a real video driver; the others can use SDL's dummy driver. The shared `Check` helper keeps checks active in release builds. `SDL3.SDL3Test` contains only native test fixtures.

The macOS source import list in `sdl3.mod/source_macos.bmx` was checked against the SDL 3.4.16 CMake static-library `compile_commands.json` for macOS arm64. When SDL is updated, compare the new CMake source list and platform dependencies with this import list. Windows and Linux have since gained dedicated source selection below; clean-build validation for each supported target remains a release gate.

Runtime window transitions are available through `TSDLGraphics.SetFullscreen` and
`SetBorderlessFullscreen`. Runtime exclusive selection requires an exact enumerated
size/rate; the original creation path still selects SDL's closest mode. Transitions
wait for SDL window synchronization and refresh actual dimensions and mode metadata.
All SDL bool results cross the BlitzMax boundary as Int.

### Platform source selection

SDL3 is compiled directly from the bundled sources. `source_macos.bmx` and
`source_windows.bmx` select the platform sources separately. Linux uses
`source_linux.bmx` and a configuration generated on the Linux build machine; other
platforms retain the existing `source.bmx` path. Objective-C ARC and Apple frameworks are macOS-only.
The Windows list follows upstream SDL platform groups and excludes standalone HID
test programs; required Win32 system libraries are linked by the SDL3 module.

SDL3 graphics windows use logical client sizes, converted from SDL display scale
and pixel density. `TSDLGraphics.Resize` accepts logical sizes; exclusive modes
retain display-mode pixel dimensions. Raw `TSDLWindow` sizes, desktop positions
and mouse input remain SDL-native coordinates. The Max2D adapter maps native mouse
coordinates separately from drawable pixels and logical window dimensions.

### Linux build

Like SDL2, this module ships its Linux configuration header and source list.
BMK compiles the bundled SDL sources directly. There is no separate configuration
step, compiler response file, generated `.linux` directory or external SDL library.
`pkg-config` supplies system dependency include paths, including distribution- and
architecture-specific DBus headers.

Linux builds require **BMK2 4.04 or newer**, which supports module-local `module.bmk` files. The bundled
`sdl3.mod/module.bmk` defaults to X11 and Wayland together, with KMS/DRM enabled.
It uses the ordinary checked-in configuration and sources; no configuration
script or response file is generated.

Choose a backend using the existing SDK `bin/custom.bmk` or an application's
`pre.bmk`:

```text
setoption sdl3.linux.video x11
setoption sdl3.linux.kmsdrm 0
```

`video` accepts `both`, `x11` or `wayland`; `kmsdrm` accepts `1` or `0`.
There is just one configuration file shipped with the module. These settings
select its C defines, source imports and dependency queries together. They stay
local to SDL3 and do not change other modules' configuration.

For a command-line build, the equivalent environment settings are:

```sh
SDL3_LINUX_VIDEO=x11 SDL3_LINUX_KMSDRM=0 ./bin/bmk makemods -r sdl3.sdl3
```

Explicit BMK settings take precedence over environment variables. Keep the same
selection when building applications; a module built X11-only can otherwise be
rebuilt with the default selection on its next import. Changing a selection
rebuilds affected sources automatically; an unconditional `-a` is not needed.

Install a C/C++ compiler, pkg-config and the development dependencies. On Ubuntu:

```sh
sudo apt install pkg-config build-essential libgl-dev libegl-dev libx11-dev \
  libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxext-dev libxss-dev \
  libxtst-dev libasound2-dev libpulse-dev libudev-dev libdbus-1-dev \
  libwayland-dev libxkbcommon-dev libdecor-0-dev libdrm-dev libgbm-dev \
  libfribidi-dev libthai-dev
./bin/bmk makeapp -r mod/sdl3.mod/tests/window_render.bmx
```

The default configuration enables X11, Wayland, KMS/DRM, desktop GL/GLES/Vulkan, ALSA,
PulseAudio, Linux input, joystick/HID, DBus and IME support, plus dummy/software
backends. Only the selected video backends require their development packages. Shared
audio, DBus, GL/EGL and Linux input dependencies remain required. SDL dynamically loads the configured backend libraries at runtime;
compiling support does not guarantee a backend/device is available.

For a smaller installation, split the packages as follows:

| Selection | Ubuntu packages |
| --- | --- |
| Shared | `pkg-config build-essential libgl-dev libegl-dev libasound2-dev libpulse-dev libudev-dev libdbus-1-dev` |
| X11 | `libx11-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxext-dev libxss-dev libxtst-dev libfribidi-dev libthai-dev` |
| Wayland | `libwayland-dev libxkbcommon-dev libdecor-0-dev` |
| KMS/DRM | `libdrm-dev libgbm-dev` |

The X11-only selection makes no Wayland, xkbcommon or libdecor pkg-config query;
Wayland-only makes no X11, FriBidi or libthai query. Runtime availability remains
separate from compiled support.

The header uses the xkbcommon 1.0 and libdecor 0.1 API baselines; newer optional
entry points are not assumed merely because the development machine has them.
Wayland generated bindings require the modern `wl_proxy_marshal_flags` API
(Wayland 1.20 or later), and XInput gesture declarations require libXi 1.8 or later.
The tested platform is glibc-based Ubuntu arm64. Other distributions/architectures
still require validation; this is not a claim of support for every Linux libc.

Linux build inputs are checked in under `sdl3.mod/include/linux/`,
`sdl3.mod/source_linux.bmx` and `sdl3.mod/wayland-generated-protocols/`. The latter
contains generated code from SDL's bundled protocol XML with its licence notices
preserved. Maintainers updating the XML can regenerate it using
`sh tools/update-wayland-protocols.sh` and `wayland-scanner`; developers building
applications need neither that tool, Python nor CMake.

After updating from the earlier experimental configuration, rebuild the SDL
module once with `bmk makemods -a -r sdl3.sdl3`. Old `.linux` directories are unused
and can be removed. Custom CMake arguments to the former configuration script no
longer apply; use the module settings above to select supported video backends.

On Wayland, the compositor chooses top-level window placement. Initial position
requests therefore do not prevent window creation, but cannot guarantee a location.

`SDL3.SDL3Graphics` also accepts `SDL_GRAPHICS_GPU` to create an ordinary managed
SDL window without attaching an SDL renderer or OpenGL context. The caller owns
its GPU device and must release its window claim before closing the graphics.
Direct `Flip` on this window does nothing; the GPU owner presents it.
`Max2D.SDL3GPUMax2D` uses this path while retaining SDL window events and sizing.

### Input and resource-lifetime regressions

`tests/input_lifetime.bmx` covers text activation, synthetic UTF-8 delivery,
queued open-file buffer ownership, rejected/disabled file events and both
renderer-first and window-first texture cleanup. Run with SDL's dummy video and
software renderer for an automated check. `tests/text_input_manual.bmx` uses a
real desktop window: type to see committed text in its title; Escape closes it.
The title also shows IME composition separately from committed text.

Renderer and texture wrappers retain their owning wrapper. `IsValid()` checks
that ownership chain before use; drawing/query methods return failure after an
owner closes. Call `Destroy()` explicitly, before `SDL_Quit`. Raw native handles
are borrowed and must not be freed independently of their wrappers.

### Mouse and cursors

`SDL3.SDL3Mouse` provides owned system/colour cursors, floating-point mouse state,
relative deltas, visibility and capture. `TSDLWindow` exposes per-window relative
mode. See [mouse usage and ownership](docs/mouse.md) and `tests/mouse_manual.bmx`.

### Desktop window controls

`TSDLWindow` supports resizing/decorations, size limits, minimise/maximise/restore,
raise/synchronisation, icons and mouse confinement. See [window controls](docs/windows.md)
for coordinate conventions and platform limitations, and
`tests/window_controls_manual.bmx` for an interactive example.

### BMP stream I/O

Surface BMP load/save accepts filenames, stream URLs and existing seekable
`TStream` objects through BRL.Stream/BRL.IO. Caller streams remain open. See
[BMP stream ownership and errors](docs/surface-streams.md).

### Direct renderer and texture APIs

The public renderer now supports texture creation and checked packed-pixel uploads,
render targets, blend/sampling state, viewport, clipping and scale. See
[direct renderer usage](docs/renderer.md) and `tests/renderer_targets.bmx`.

Texture colour/alpha modulation supports integer and floating-point channels.
Streaming textures offer `TSDLTextureLock` for `Using` or explicit unlock, with
checked row copying and owner-lifetime validation. See [renderer usage](docs/renderer.md).

Direct renderer geometry uses `SSDLVertex[]` with optional checked `Int[]` indices.
Logical presentation supports stretch, letterbox, overscan and integer scaling,
with explicit window/render coordinate conversion. See [renderer usage](docs/renderer.md).
