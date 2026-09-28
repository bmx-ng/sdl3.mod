# SDL3 for BlitzMax

Build desktop games and multimedia applications with SDL3: create windows, draw
with hardware-accelerated renderers, handle keyboard, mouse and controller input,
and play sound effects and streaming music.

These modules integrate SDL3 with BlitzMax's graphics, events, joystick and audio
APIs. You can use familiar BlitzMax functions, or work directly with SDL objects
such as `TSDLWindow`, `TSDLRenderer` and `TSDLGamepad`.

**SDL 3.4.16 is included and compiled with your application.** You do not need to
install a separate SDL3 library.

- [Install](#install)
- [Your first window with Max2D](#your-first-window-with-max2d)
- [Use SDL's renderer directly](#use-sdls-renderer-directly)
- [Input and controllers](#input-and-controllers)
- [Sound and music](#sound-and-music)
- [Module guide](#module-guide)
- [Linux dependencies and configuration](#linux-dependencies-and-configuration)

## Install

Use a **bcc2-based BlitzMax NG SDK**, with up-to-date BRL and Pub modules. Linux
builds require **BMK2 4.04 or newer**. The production bcc/bmk toolchain and the
original BlitzMax release are not supported by this SDL3 package.

From your SDK directory, install this repository as `mod/sdl3.mod`:

```sh
git clone https://github.com/bmx-ng/sdl3.mod.git mod/sdl3.mod
```

The main module source should be at `mod/sdl3.mod/sdl3.mod/sdl3.bmx`.

You will also need:

| What you want to use | Additional modules |
| --- | --- |
| Max2D drawing, images and text | [max2d.mod](https://github.com/bmx-ng/max2d.mod), including its documented dependencies |
| Standard BlitzMax audio through SDL3 | [audio.mod](https://github.com/bmx-ng/audio.mod), which provides `Audio.Streams` |
| WAV, Vorbis, FLAC or MP3 music streaming | The corresponding optional provider from `audio.mod` |

Use your SDK's normal native build tools: Xcode Command Line Tools on macOS,
MinGW on Windows, or a C/C++ toolchain and the [development packages below](#linux-dependencies-and-configuration)
on Linux. SDL itself is built from the included sources; CMake is not needed.
The first build takes longer while SDL compiles. Later builds reuse the compiled
modules.

## Your first window with Max2D

For 2D games, start with `Max2D.SDL3RenderMax2D`. It gives you `DrawImage`,
`DrawText`, shapes, cameras and render-to-texture through the new Max2D API.

Install the [Max2D namespace](https://github.com/bmx-ng/max2d.mod) alongside SDL3
if it is not already in your SDK:

```sh
git clone https://github.com/bmx-ng/max2d.mod.git mod/max2d.mod
```

Then try [examples/hello_max2d.bmx](examples/hello_max2d.bmx):

```blitzmax
SuperStrict

Framework Max2D.SDL3RenderMax2D
Import BRL.PolledInput

Graphics 800, 450
SetClsColor 24, 28, 38

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls

	SetColor 55, 170, 240
	DrawRect 40, 40, 160, 100

	SetColor 255, 255, 255
	DrawText "Hello from SDL3 and Max2D!", 40, 170
	DrawText "Press Escape or close the window to quit.", 40, 200

	Flip
Wend

EndGraphics
```

Open the example in your IDE, or build it from the SDK directory:

```sh
./bin/bmk makeapp -r -t gui mod/sdl3.mod/examples/hello_max2d.bmx
```

On Windows, use:

```powershell
.\bin\bmk.exe makeapp -r -t gui mod\sdl3.mod\examples\hello_max2d.bmx
```

Run the executable or application bundle generated beside the source file.

There are two SDL3 backends for the new Max2D namespace:

| Framework | Rendering path |
| --- | --- |
| `Max2D.SDL3RenderMax2D` | Uses SDL's renderer API, which selects an available rendering driver. |
| `Max2D.SDL3GPUMax2D` | Uses SDL's GPU API directly; requires a supported GPU backend. |

Change the `Framework` line to try the GPU backend. See the
[Max2D documentation](https://github.com/bmx-ng/max2d.mod) for feature support,
virtual resolution, cameras, text and texture formats.

Applications that need to retain `BRL.Max2D` can continue using the SDL2 modules.
SDL3's Max2D backends use the new `Max2D` namespace.

## Use SDL's renderer directly

You can also use SDL3 without Max2D. Import `SDL3.SDL3Render` to create your own
windows, renderers and textures:

```blitzmax
Local window:TSDLWindow = TSDLWindow.Create("My window", 800, 450)
If Not window Then Throw SDL_GetError()

Local renderer:TSDLRenderer = TSDLRenderer.Create(window)
If Not renderer Then Throw SDL_GetError()

renderer.SetDrawColor(24, 28, 38)
renderer.Clear()
renderer.Present()
```

The complete [hello_renderer.bmx](examples/hello_renderer.bmx) example adds an
event loop, a coloured rectangle, resizing with letterboxing, and cleanup. It
requires only these SDL3 modules and their BRL/Pub dependencies:

```sh
./bin/bmk makeapp -r -t gui mod/sdl3.mod/examples/hello_renderer.bmx
```

Use [the renderer guide](docs/renderer.md) for textures, uploads, clipping,
geometry and render targets. For integration with `BRL.Graphics`,
`SDL3.SDL3Graphics` supplies `SDLGraphics()` and `SDLGraphicsDriver()`; the driver
exposes its window and renderer. It can also create OpenGL windows using
`SDL_GRAPHICS_GL`.

### Resource ownership and errors

- Create and use windows, renderers and textures on the main thread.
- Object creation can return `Null`. Boolean methods return an `Int`: zero means
  failure and nonzero means success. Read `SDL_GetError()` immediately after a
  failure to obtain the diagnostic.
- For objects you create directly, call `Destroy()` when finished: textures first,
  then their renderer, then the window. GL contexts use `Free()`.
- When using `SDLGraphics()` or Max2D, let `EndGraphics` close the graphics-owned
  window and renderer. Do not destroy those borrowed objects yourself.

See [resource ownership](docs/ownership-and-callbacks.md) for more details.

## Input and controllers

The SDL3 system driver translates SDL events into BlitzMax events. `Graphics()`
(including Max2D and `SDLGraphics()`) enables `BRL.PolledInput`, so `KeyDown`,
`KeyHit`, `MouseX`, `MouseY` and `AppTerminate` work as usual.

Creating a raw `TSDLWindow` does not enable polled input. Use `BRL.EventQueue`
and `PollEvent()` as in [hello_renderer.bmx](examples/hello_renderer.bmx), handling
`EVENT_KEYDOWN`, `EVENT_WINDOWCLOSE` and `EVENT_APPTERMINATE` explicitly.
`EVENT_WINDOWCLOSE` identifies the window by its ID in `EventData()`; it is a
request for your application to close that window. If you choose to use polled
input with raw windows, call `EnablePolledInput()` and still handle per-window
close requests.

Keep the event loop running. `PollEvent()` pumps the system when its queue is
empty; `PollSystem()` and `WaitSystem()` also process SDL events. Avoid consuming
SDL's native event queue independently of the system driver.

- **Text entry:** use committed text events rather than translating key presses
  yourself. Raw windows must call `StartTextInput()`; graphics-managed windows
  start text input automatically. See [text input and clipboard](docs/text-input.md).
- **Joysticks:** import `SDL3.SDL3Joystick` to use the standard `Pub.Joystick`
  functions, including `JoyCount`, `JoyX`, `JoyDown` and `JoyHit`.
- **Mapped gamepads:** import `SDL3.SDL3Gamepad` for `TSDLGamepad`, standardised
  axes/buttons, mappings and rumble. It also installs the joystick driver.
- **Mouse controls:** see [cursors, capture and relative mode](docs/mouse.md).

`SDLJoystickIDs()` and `SDLGamepadIDs()` return SDL instance IDs used to open
SDL device objects. These are different from the zero-based joystick ports used
by `Pub.Joystick`.

For multiple windows, precise wheel input, touch and device events, see the
[input guide](docs/input-events.md).

### Window size and display scaling

`SDLGraphics()` and the Max2D backends use logical window sizes so that windows
retain their intended visible size on scaled displays. Raw `TSDLWindow` calls
use SDL's native window coordinates. Drawable pixel dimensions can differ from
both. Use `GetSizeInPixels()` when you need the actual drawable size, and the
renderer/Max2D coordinate conversion APIs when drawing at a virtual resolution.

See [window controls](docs/windows.md) for resizing, fullscreen and platform
behaviour. On Wayland, window placement is controlled by the compositor.

## Sound and music

Import `SDL3.SDL3AudioAudio` and select the `SDL3` audio driver to use the standard
BlitzMax sound API. For a WAV sound effect:

```blitzmax
Import SDL3.SDL3AudioAudio
Import BRL.WAVLoader

If Not SetAudioDriver("SDL3") Then Throw SDL_GetError()
Local sound:TSound = LoadSound("effect.wav")
If Not sound Then Throw "Could not load effect.wav"
Local channel:TChannel = PlaySound(sound)
```

Keep your application running while the sound plays. `CueSound`, channel volume,
pan, playback rate, pause/resume and looping use the familiar BRL.Audio functions.

For music decoded as it plays, import a streaming provider and pass `SOUND_STREAM`:

```blitzmax
Import Audio.VorbisStream

Local music:TSound = LoadSound("music.ogg", SOUND_STREAM | SOUND_LOOP)
If Not music Then Throw "Could not load music.ogg"
Local musicChannel:TChannel = PlaySound(music)
```

Providers are optional: `Audio.WavStream`, `Audio.VorbisStream`,
`Audio.FlacStream` and `Audio.Mp3Stream`. Importing one does not prevent normal
in-memory sound loading through existing sample loaders.

See [the audio guide](docs/audio.md) for complete examples and streaming behaviour.
For direct PCM streams, recording and device controls, use `SDL3.SDL3Audio`.

## Module guide

Import the modules your application needs; dependencies are imported for you.

| Module | Use it for |
| --- | --- |
| `SDL3.SDL3` | SDL initialisation, errors and core constants. |
| `SDL3.SDL3System` | BlitzMax event-loop and system integration. |
| `SDL3.SDL3Video` | Windows, displays, OpenGL contexts and native window handles. |
| `SDL3.SDL3Graphics` | `BRL.Graphics` integration and managed graphics windows. |
| `SDL3.SDL3Render` | SDL renderers, textures, drawing and render targets. |
| `SDL3.SDL3Surface` | Software surfaces and BMP loading/saving through files or streams. |
| `SDL3.SDL3Rect` | Integer and floating-point rectangles. |
| `SDL3.SDL3Mouse` / `SDL3.SDL3Clipboard` | Cursor/mouse controls and text clipboard access. |
| `SDL3.SDL3Joystick` / `SDL3.SDL3Gamepad` | Raw joysticks and mapped gamepads. |
| `SDL3.SDL3AudioAudio` | SDL3 driver for `BRL.Audio`. |
| `SDL3.SDL3Audio` | Direct PCM audio streams and device control. |
| `SDL3.SDL3Thread` / `SDL3.SDL3Timer` | SDL threads and timers integrated with the BlitzMax runtime. |

Public type names remain familiar—`TSDLWindow`, `TSDLTexture`, `TSDLSurface`—while
the `SDL3` namespace distinguishes these bindings from SDL2. SDL3 API differences
still apply; changing imports alone is not a complete SDL2 migration.

The bindings do not yet expose every SDL3 subsystem. See the
[API coverage list](docs/release-checklist.md) if you need a
particular feature. For example, the new Max2D GPU backend uses SDL's GPU API,
but this repository does not yet provide general-purpose BlitzMax GPU bindings.

## Linux dependencies and configuration

The default build enables **X11, Wayland and KMS/DRM**. Install their development
packages before compiling. On a recent Ubuntu installation:

```sh
sudo apt install pkg-config build-essential libgl-dev libegl-dev libx11-dev \
  libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxext-dev libxss-dev \
  libxtst-dev libasound2-dev libpulse-dev libudev-dev libdbus-1-dev \
  libwayland-dev libxkbcommon-dev libdecor-0-dev libdrm-dev libgbm-dev \
  libfribidi-dev libthai-dev
```

You can build for X11 only or Wayland only to avoid installing unused backend
dependencies. Put these settings in your SDK's `bin/custom.bmk`, or in your
application's `pre.bmk`. For example, for X11 without KMS/DRM:

```text
setoption sdl3.linux.video x11
setoption sdl3.linux.kmsdrm 0
```

| Setting | Values | Default |
| --- | --- | --- |
| `sdl3.linux.video` | `both`, `x11`, `wayland` | `both` |
| `sdl3.linux.kmsdrm` | `1` (enabled), `0` (disabled) | `1` |

Install the shared dependencies plus those for your selected backends:

| Selection | Ubuntu packages |
| --- | --- |
| Shared | `pkg-config build-essential libgl-dev libegl-dev libasound2-dev libpulse-dev libudev-dev libdbus-1-dev` |
| X11 | `libx11-dev libxrandr-dev libxcursor-dev libxi-dev libxfixes-dev libxext-dev libxss-dev libxtst-dev libfribidi-dev libthai-dev` |
| Wayland | `libwayland-dev libxkbcommon-dev libdecor-0-dev` |
| KMS/DRM | `libdrm-dev libgbm-dev` |

For command-line builds you can instead set `SDL3_LINUX_VIDEO` and
`SDL3_LINUX_KMSDRM`:

```sh
SDL3_LINUX_VIDEO=x11 SDL3_LINUX_KMSDRM=0 \
  ./bin/bmk makeapp -r -t gui mod/sdl3.mod/examples/hello_renderer.bmx
```

BMK settings take precedence over environment variables. Keep your selection
consistent across module and application builds; changing it rebuilds the
relevant SDL sources. These are build-time settings. SDL chooses an available
compiled backend at runtime.

Wayland requires version 1.20 or later, xkbcommon 1.0 or later and libdecor 0.1 or
later. The X11 build requires libXi 1.8 or later. Package names may differ on
other distributions. No SDL-specific configuration script is required.

## Further reading

- [Renderer and textures](docs/renderer.md)
- [Windows and fullscreen](docs/windows.md)
- [Input events](docs/input-events.md), [text input](docs/text-input.md) and [mouse controls](docs/mouse.md)
- [Audio and streaming music](docs/audio.md)
- [BMP files and streams](docs/surface-streams.md)
- [Resource ownership and callbacks](docs/ownership-and-callbacks.md)
- [Contributing, builds and tests](docs/development.md)

The bindings use the zlib/libpng licence. Bundled SDL and third-party sources
retain their own licence notices; see [SDL's licence](sdl3.mod/SDL3/LICENSE.txt).
