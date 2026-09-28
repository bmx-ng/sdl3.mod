# SDL3 desktop release checklist

Reviewed on 28 September 2026 against the bundled SDL 3.4.16 sources. This is a
checklist for the first supported desktop release, not a requirement to wrap every
SDL API. SDL is built from the included sources; no system SDL library is required.

## Where things stand

The everyday window, rendering, input, threading and audio foundations are in
place. The automated headless tests pass on macOS arm64, Linux arm64 and Windows
x64 under ARM64 VM emulation. Audio includes both ordinary BRL.Audio sound effects
and optional streamed WAV, Vorbis, FLAC and MP3 playback.

**Input fidelity and multiple-window focus now have an implementation and
synthetic regressions.** Real desktop interaction remains to be validated. A first supported release also needs a final ownership/ABI review,
real desktop interaction checks and a reproducible installation from clean source
checkouts. Passing dummy-driver tests does not certify those behaviours.

## Available functionality

| Area | Available now | Limits and follow-up |
| --- | --- | --- |
| Core | Initialisation, shutdown, version, errors, event enable/disable | General hints, logging and properties APIs are not exposed |
| System/input | BRL event pump, keyboard/mouse/touch/window/display events, lifecycle callbacks, native observers and capture | Copied input payloads and focus-transfer policy implemented; real interaction checks remain |
| Text | Per-window activation, input area, copied composition events, BRL committed-text integration | Real IME and non-BMP interaction need validation |
| Desktop helpers | Text clipboard, cursors, message boxes, URLs, file/folder dialogs through Pub.NFD | Text drops and native desktop interaction checks remain |
| Windows/graphics | Window controls, BRL.Graphics integration, DPI/logical sizing, renderer/GL/GPU windows, exclusive/borderless fullscreen | Native widget attachment is unavailable; multiple-window checks remain |
| OpenGL | Window/context creation, context controls and native handles | Desktop context checks pass on Windows and Linux VMs |
| Surfaces | Create/fill/read pixels, BMP load/save using paths or streams | General locking, conversion, blitting and pixmap interoperability remain limited |
| Renderer/textures | Uploads, targets/readback, copy, modulation/blend/sampling, streaming locks, viewport/clip/scale, geometry and logical presentation | Broader properties and hardware validation remain |
| Controllers | Pub.Joystick integration, raw joystick and mapped gamepad APIs, virtual devices, events, basic rumble | Physical hotplug/rumble unverified; advanced device features deferred |
| Threads/timers | GC/runtime-aware managed thread entry, join/results/exceptions/detach; timer delivery through main-thread events | Cancellation/queue-pressure/reentrancy stress review remains; managed SDL threads unavailable on Switch |
| Audio | PCM conversion/playback/recording/device controls, BRL.Audio driver, bounded streaming with optional decoders | Physical device changes and microphone capture unverified; richer layouts deferred |

Compiling a subsystem into SDL does not expose it to BlitzMax. SDL functions used
only by native Max2D glue are not public standalone SDL3 bindings. The new
`Max2D.SDL3RenderMax2D` and `Max2D.SDL3GPUMax2D` backends live in the separate
`max2d.mod` repository. BRL.Max2D applications can continue using SDL2.

## Completed foundations

- [x] Convert SDL C booleans through glue to BlitzMax Int values.
- [x] Activate BRL text input and expose per-window text/composition controls.
- [x] Keep macOS application open-file paths alive through queued dispatch and
  clean up failed pushes and unconsumed paths at shutdown.
- [x] Deliver file drops with a copied path, window ID and drop coordinates.
- [x] Guard renderer/texture ownership, reject cross-renderer operations, and test
  owner-first destruction, repeated cleanup and streaming texture locks.
- [x] Support BMP I/O through BRL streams while preserving caller ownership.
- [x] Register managed SDL threads with the GC and BlitzMax thread-local runtime.
- [x] Provide BRL.Audio effects and bounded music streaming. Keep filesystem work
  and managed decoding away from SDL's audio thread.

See [text input](text-input.md), [audio](audio.md) and the chronological
[stabilisation notes](stabilisation.md) for usage and validation details.

## Remaining implementation and review work

### Input fidelity and window focus

Implemented in the [event translator](../sdl3system.mod/glue.c); see the
[developer guide](input-events.md) for contracts and examples.

- [x] Preserve both wheel axes, fractions, direction, position and window in a
  copied payload, with accumulated legacy integer steps per window/mouse.
- [x] Preserve full-width touch IDs and pressure; use stable positive legacy slots.
- [x] Translate touch cancellation and include it in capture classification.
- [x] Preserve window identity in keyboard, committed-text and mouse payloads.
- [x] Coalesce queued focus transfers, release held input on focus loss and allow
  terminal events through capture when their input was already delivered to BRL.
- [x] Add copied text-drop events while retaining existing file-drop fields.
- [x] Preserve UTF-16 KEYCHAR semantics and test non-BMP surrogate-pair delivery;
  expose the complete committed string alongside its legacy character events.
- [ ] Complete device-specific validation. The user confirmed that the two-window
  manual example works on macOS; detailed coverage was not reported. Check capture, relative
  mode, touch and scrolling devices. Synthetic tests do not prove OS behaviour.

### Ownership, ABI and callbacks

- [ ] Finish signature checks for signedness, size_t, full-width flags/IDs,
  pointer outputs, structure layout and platform calling conventions.
- [ ] Finish failure-path checks: null handles, creation rollback and defined
  output values after failure.
- [x] Define and test GL context/window ownership, owner-first destruction and
  current-context guards; see [ownership and callbacks](ownership-and-callbacks.md).
- [x] Contain lifecycle/timer/controller callback exceptions and allow polling to
  recover. Explicitly root lifecycle userdata and validate timer frequency ranges.
- [ ] Check callback roots, removal/reentrancy, shutdown order and queue failures.
  Timers and lifecycle handoff have basic regressions, not a complete race/stress
  certification.

The refreshed binding inventory finds **22 direct SDL declarations and no direct
C bool signatures**. This is a useful guard, not proof of every wrapper's ABI.
Run it against the bundled headers when adding bindings:

```sh
python3 /path/to/sdl3.mod/tools/audit-bindings.py
python3 /path/to/sdl3.mod/tools/audit-bindings.py --json > sdl3-api-inventory.json
```

The script does not preprocess platform branches or validate callback typedefs,
macro signatures or wrapper conversions. Internal/test glue references count;
separate Max2D glue is excluded. New boolean pointer outputs still require local
C bool storage and explicit copying to BlitzMax Int.

## Recorded validation

Results below were recorded on 27–28 September 2026. Each count includes both
debug and release configurations; the audio tests are additional to the 16-test
headless suite.

| Platform | Standalone headless | Audio | Scope |
| --- | --- | --- | --- |
| macOS 15.7.4 arm64 | 32 passes | 16 passes | Dummy/software tests; native CoreAudio mixed test and user listening checks also completed |
| Windows 11 ARM64 VM | 32 passes | 16 passes | x64 SDK under emulation; not native Windows ARM64 or physical x64 hardware validation |
| Ubuntu 26.04.1 arm64 VM | 32 passes | 16 passes | Headless drivers; desktop X11/Wayland results tracked separately |

The standalone suite covers core rectangles, system events, window rendering,
timers, surfaces/textures, BRL graphics, managed threads, controllers, input
lifetime, clipboard/composition, mouse/window controls, BMP streams, renderer
targets, texture locks and geometry/presentation. The audio suite includes codec,
stream ownership, playback/control, mixed-load and shutdown checks. The user
confirmed audible WAV, Vorbis, FLAC and MP3 playback on macOS.

Desktop OpenGL results are narrower:

- Windows VM: GL context checks pass debug/release.
- Linux VM: GL context checks pass on X11 and Wayland.

The former BRL compatibility renderer and its test have been removed. Their
historical results, including the unresolved virgl readback failure, remain in
[stabilisation notes](stabilisation.md). That retired driver is no longer part of
the SDL3 release scope; its removal does not establish a fix for virgl or certify
any new Max2D backend.

- [ ] Validate real typing/dead keys, IME commit/cancel, non-BMP text and capture.
- [ ] Validate OS clipboard exchange, file/text drops, macOS application file opens
  and native dialog accept/cancel behaviour.
- [ ] Record real focus, resize/DPI, fullscreen return and close/reopen checks on
  the final SDL3 candidate, including multiple windows.
- [ ] Test physical controllers, multiple displays, audio output migration,
  unplug/reconnect and microphone capture where available; clearly label any
  unverified device-specific capabilities in release claims.
- [ ] Recheck the new Max2D renderer/GPU examples after shared window/input changes.

Workspace logs: `build-artifacts/sdl3-readiness/macos/` for the refreshed macOS
headless pass, `build-artifacts/sdl3-stabilisation/vm/` for the VM suite and desktop
results, and `build-artifacts/sdl3-audio/` for audio. These local artifacts are not
part of the distributed modules.

## Installation and publishing gate

`SDL3.SDL3AudioAudio` requires **Audio.Streams**, even when only playing resident
sound effects. The WAV/Vorbis/FLAC/MP3 providers are optional imports; Vorbis also
uses Pub.OggVorbis. Desktop system helpers use Pub.NFD; joystick and GL integration
use the corresponding Pub modules. The new Max2D namespace is separate and is not
required to use the standalone SDL3 bindings.

These are tested source snapshots, **not established minimum SDK versions**.
The callback exception-recovery path requires the BRL.System polling-guard fix
recorded below:

| Repository | Reviewed/tested revision |
| --- | --- |
| sdl3.mod | a45f354 |
| audio.mod | ffdfc75 |
| brl.mod | d6eefa4 (includes polling exception recovery) |
| pub.mod | 59be848 |
| max2d.mod (separate integration) | 9f9a136 |

- [ ] Establish the supported SDK/compiler baseline and publish installation
  instructions with the required companion modules and versions.
- [ ] Build the final candidate from fresh checkouts on each supported desktop
  platform, without relying on shared build caches or developer-local files.
- [x] Replace the experimental Linux response-file/configuration step with a
  checked-in configuration, source list and Wayland bindings. A source-only Linux
  installation builds without `.linux`, Python, CMake or wayland-scanner.
- [x] Support selectable Linux X11/Wayland dependencies with one `module.bmk`.
  Requires BMK2 4.04 or newer. Backend combinations passed on Ubuntu arm64;
  the build-manager feature still needs Windows validation.
- [ ] Complete final-candidate checks on the other desktop platforms; ensure
  host-only flags do not leak into other platforms.
- [ ] Finish public bbdoc, ownership rules and runnable examples for the release API.
- [ ] Review licences and package contents; exclude caches, machine-specific configurations,
  test binaries and local paths. Record the bundled SDL version.
- [ ] Publish supported platforms/features and known limitations. No remote push
  is implied by completing this checklist.

## Deferred APIs

A first desktop release need not include general SDL GPU bindings, HID, sensors,
haptics, camera, tray, storage, process or asynchronous I/O wrappers. Advanced
controller effects, MIME clipboard access, SDL-native asynchronous dialogs,
native widget attachment, broader surface operations and richer audio layouts
can be scoped separately. Pub.NFD already provides file/folder dialogs; the new
Max2D GPU backend already uses SDL GPU internally.

## Suggested order

1. Validate input fidelity, multi-window focus and text drops with real desktop input.
2. Complete the focused ABI/lifetime/callback review and desktop interaction checks.
3. Validate fresh installations and the final candidate across the three desktops,
   then finish release documentation and packaging.
