# Developing the SDL3 modules

For installation and application examples, start with the [README](../README.md).
This guide covers building the bindings themselves and maintaining the bundled SDL
sources.

## Build and test

Run commands from a bcc2-based BlitzMax SDK directory. Use `bin/bmk.exe` on Windows.
BMK builds imported modules automatically; to build the SDL core explicitly:

```sh
./bin/bmk makemods -r sdl3.sdl3
```

The `tests/` directory contains automated checks and interactive examples.
`SDL3.SDL3Test` provides native fixtures for those checks; applications do not need
to import it. For a simple automated renderer check:

```sh
./bin/bmk makeapp -r mod/sdl3.mod/tests/window_render.bmx
SDL_VIDEODRIVER=dummy SDL_RENDER_DRIVER=software mod/sdl3.mod/tests/window_render
```

Omit `-r` for a debug build. Tests that create OpenGL contexts or need desktop
interaction must run with a real video driver. Interactive examples include
`text_input_manual.bmx`, `mouse_manual.bmx`, `window_controls_manual.bmx` and
`audio_manual.bmx`. The audio example generates its own tone.

See the [release checklist](release-checklist.md) for outstanding coverage and
[stabilisation notes](stabilisation.md) for historical platform results. Those
results describe specific test configurations rather than a guarantee for every
OS, driver or device.

## Keep the native boundary explicit

SDL3 uses C `bool` in many public functions. The BlitzMax API uses `Int` for boolean
values. Convert between them in C glue:

- Return `0` or `1` to BlitzMax for a C boolean result.
- Convert incoming `Int` values using `value != 0`.
- For `bool *` outputs, receive into a local C `bool`, then copy into the BlitzMax
  `Int` output.

Do not bind C `bool` arguments, results or pointer outputs directly as BlitzMax
`Int`. Check other native types too, including `size_t`, 64-bit IDs and structures.
For native void returns in SuperStrict, omit the return type annotation.

Read [ownership and callbacks](ownership-and-callbacks.md) before adding native
callbacks or resources. SDL threads and callbacks must not invoke managed code
without the required runtime registration or main-thread dispatch.

## Updating bundled SDL

SDL is compiled from `sdl3.mod/SDL3`. Keep upstream sources and licence notices
intact. Platform import lists are maintained separately:

- `sdl3.mod/source_macos.bmx`
- `sdl3.mod/source_windows.bmx`
- `sdl3.mod/source_linux.bmx`

Linux uses a checked-in configuration under `sdl3.mod/include/linux/`.
Its `module.bmk` selects backend definitions, source imports and dependency queries
before compilation. See the README for the supported user settings.

When updating SDL, review its source lists, configuration macros and dependencies
on each platform. Upstream CMake compile commands can help compare source selection;
CMake is a maintainer aid, not an application build requirement. Keep Objective-C
ARC flags and Apple frameworks conditional on macOS.

Generated Wayland bindings live in `sdl3.mod/wayland-generated-protocols/`. After
updating SDL's protocol XML, regenerate the bindings with:

```sh
sh tools/update-wayland-protocols.sh
```

This maintainer step needs `wayland-scanner`; application developers need neither
it nor a protocol-generation step.
