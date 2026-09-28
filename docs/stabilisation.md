# Input and resource-lifetime fixes

## Behaviour

- BRL graphics windows start SDL text input automatically. Raw `TSDLWindow`
  instances remain opt-in through `StartTextInput`, `StopTextInput` and
  `TextInputActive`. All three cross the C boolean boundary through integer glue.
- macOS open-file requests copy their UTF-8 path before queueing. That copy remains
  valid for native observers and BlitzMax translation, then is freed. Failed pushes
  release immediately; undelivered/flushed entries are reclaimed at system shutdown.
- File events become `EVENT_APPOPENFILE`: `extra` contains the path, `data` contains
  the window ID (zero for application-level opens), and `x`/`y` contain native drop
  coordinates. Native observers must copy borrowed payloads if retaining them.
- Renderer and texture wrappers retain their owners. Operations fail after an owner
  is destroyed; texture size outputs are zero on failure. Cross-renderer texture
  drawing is rejected. Repeated destruction and either renderer-first or window-first
  cleanup are supported. Native handles must not be destroyed behind the wrappers,
  and resources must be closed before SDL_Quit.

SDL 3.4.16 deliberately keeps the renderer allocation after a window is destroyed;
its native `SDL_DestroyRenderer` finishes freeing that allocation. The wrapper
therefore still calls it on explicit renderer destruction, while refusing drawing
and texture access once the window has closed.

## Validation on macOS arm64

Debug and release builds passed these nine tests with `SDL_VIDEODRIVER=dummy` and
`SDL_RENDER_DRIVER=software`:

- `input_lifetime`
- `core_rect`
- `system_events`
- `surface_texture`
- `window_render`
- `graphics_driver`
- `managed_threads`
- `timer_events`
- `joystick_gamepad`

The new test checks text activation/deactivation, committed UTF-8 translation,
copying a queued path before its caller overwrites/frees the original, filtered and
disabled file events, cross-renderer rejection and destruction ordering. It leaves
one queued path unpolled to exercise the shutdown path. This is not a leak-detector
run or a substitute for native OS file-drop testing.

The real Cocoa window in `text_input_manual.bmx` also displayed
`Received: hello world!` after interactive typing. This verifies the path through
SDL text events and BRL `GetChar`, beyond injected-event checks.

The first `window_render` build hit the known shared-helper cache link problem;
rebuilding with `-clean` succeeded. Use `-clean` when switching standalone tests.
The binding audit still reports no direct C bool declarations.

Windows/Linux reruns, native Finder open/drop interaction, dead-key/IME interaction,
input-area controls and composition presentation remain outstanding. No SDK build
settings or Max2D implementation changes were required for these fixes.

## Clipboard and composition follow-up

Added `SDL3.SDL3Clipboard`, input-area set/get/reset, composition dismissal and
`EVENT_SDL3_TEXT_EDITING` with a retained, copied payload. The manual input example
now shows provisional composition separately from committed text.

`clipboard_composition` passes in debug and release on macOS arm64 using the dummy
driver. The existing `input_lifetime` and `system_events` release regressions also
pass after these changes. The updated desktop example builds successfully. The ABI
scan continues to report zero direct C bool signatures.

The earlier outstanding input-area and composition API work is now implemented.
Real IME popup placement, native clipboard integration and Windows/Linux checks
remain unverified in this follow-up. The desktop clipboard was not changed.

## Mouse and cursor follow-up

Added SDL3.SDL3Mouse and per-window relative-mode controls. The dummy-driver
regression passes in release and debug on macOS arm64. The Cocoa manual example
reached its “Cursor checks passed” title, verifying native system/colour creation,
source-surface independence and active/repeated cursor destruction. Relative mode
and capture controls are available in that example; physical behaviour and focus
transitions have not been certified by the dummy-driver tests. Windows/Linux
validation remains outstanding. The direct-bool scan remains clear.

## Desktop window follow-up

Added ordinary window controls, size bounds, icons, transition synchronisation and
mouse confinement. `window_controls` passes in debug and release with the dummy
driver, including unsupported-operation checks. `window_controls_manual` reached
its native “Window checks passed” title on macOS, checking resizable/border flag
changes and size bounds. The example remains available for interactive transition
and confinement checks. No native icon-display or Windows/Linux validation is
claimed by these results.

## BMP stream follow-up

Surface BMP load/save now opens through BRL.Stream and accepts existing seekable
streams. A synchronous SDL I/O adapter catches managed callback exceptions and
retains its context across GC. Caller streams remain open; owned streams close on
success and failure. No full-file buffering is added.

The new `bmp_streams` test and existing file-based `surface_texture` test pass in
debug and release on macOS arm64. Registered stream URLs, partial transfers,
nonzero starting positions, zero-progress writes, GC, exceptions and non-seekable
input/output are covered. Actual archive mounts and Windows/Linux runs remain
unverified here. The direct-bool scan remains clear.

## Direct renderer follow-up

Exposed texture creation, checked packed-byte uploads, target selection,
blend/sampling state and viewport/clip/scale. `renderer_targets` passes in debug
and release with dummy video/software rendering on macOS arm64. It checks pixels,
padded rows, upload rejection, per-target state and ownership. Existing
`surface_texture` and `input_lifetime` release tests pass too. Hardware and
Windows/Linux results are not claimed for this addition.

## Texture modulation and locking follow-up

Added integer/float colour and alpha modulation, plus packed streaming locks with
ICloseable/Using and explicit unlock. `texture_locks` passes in debug and release
with the macOS software renderer, including exception unwinding, texture/renderer/
window destruction, bounds checks and modulated readback. `renderer_targets` also
passes after the additions. Cached raw pointers remain the caller's responsibility;
the safe row-copy path checks scope and owner validity before accessing memory.
Hardware and Windows/Linux validation remains outstanding.

## Geometry and logical presentation follow-up

Added SSDLVertex arrays, indexed/unindexed triangle rendering and logical
presentation with explicit coordinate conversion. `geometry_presentation` passes
in debug and release with the macOS software renderer; its checks include pixel
readback, index rejection, target-local state, letterbox bounds and viewport/scale
roundtrips. Existing renderer-target and texture-lock release tests also pass.
No hardware or Windows/Linux results are claimed for these new entry points.

## Windows/Linux validation pass

On 27–28 September 2026, the standalone suite was rerun against SDL 3.4.16 in the local working tree based
on `6fd16b4`, including the additions described above. Linux uses Ubuntu 26.04.1
arm64 (the VM is still named `Ubuntu_arm64_25_10`), GCC 15.2 and its local BlitzMax
SDK. Windows uses Windows 11 Pro build 26200 on ARM64, running the **x64** BlitzMax
SDK and MinGW-w64 GCC 12.2 through Windows emulation.

Windows and Linux each passed all 16 tests in both debug and release with dummy video/software
rendering: `core_rect`, `system_events`, `window_render`, `timer_events`,
`surface_texture`, `graphics_driver`, `managed_threads`, `joystick_gamepad`,
`input_lifetime`, `clipboard_composition`, `mouse_controls`, `window_controls`,
`bmp_streams`, `renderer_targets`, `texture_locks` and `geometry_presentation`.

The pass found and corrected:

- A Windows `interface` macro collision in the BMP stream adapter. Its local
  variable is now named `ioInterface`.
- Unsigned render-target dimensions passed to OpenGL's signed dimensions in the
  BRL compatibility driver. The driver now checks the range and converts explicitly.
- A missing explicit framework in `core_rect`, which unnecessarily imported legacy
  default modules and encountered an unrelated Linux FreeJoy link failure.
- Exact floating-point assertions in coordinate conversion. Windows produced a
  rounding difference below 0.000001 pixels; computed coordinates now use a 0.001
  pixel tolerance.

Linux's cached SDL library initially reported joystick support disabled despite
its generated configuration enabling it. Regenerating the Linux configuration and
forcing a rebuild of `SDL3.SDL3` resolved this; virtual controller tests then passed
in both configurations.

### Windows desktop OpenGL

`graphics_gl` and `max2d_gl` both passed in debug and release in the interactive
Windows desktop session. The compatibility test reported
`Parallels using Apple M4 Max (Compat)` and checked primitives, uploaded images,
render-to-texture, readback and presentation. These are accelerated VM results,
not native Intel/AMD hardware results.

### Linux desktop OpenGL

`graphics_gl` passed in debug and release using both X11 and Wayland. The
`max2d_gl` BRL compatibility test passed in both configurations on both protocols
with `LIBGL_ALWAYS_SOFTWARE=1`, reporting llvmpipe (LLVM 21.1.8).

With the VM's accelerated `virgl (Apple M4 Max (Compat))` renderer, `max2d_gl`
failed its render-to-texture pixel check under both protocols. A diagnostic run
reported a complete framebuffer and no GL errors, but read back an empty target;
even a direct clear did not appear in that readback. The same test passed with
llvmpipe. This narrows the failure to the accelerated configuration but does not
establish its root cause. Some failing Wayland runs also aborted during Mesa/Rust
thread-local teardown. Accelerated BRL compatibility rendering on this VM remains
unverified; no software fallback has been forced in library code.

These checks do not certify physical controllers, rumble, IME interaction, native
clipboard exchange, file drops, multiple displays, or window-manager transitions.
Earlier per-feature notes above describe their original macOS validation; the VM
results here supersede their outstanding headless Windows/Linux checks only.

Build/run logs and the VM runner scripts are retained in the workspace under
`build-artifacts/sdl3-stabilisation/vm/`. Both headless result files contain 32
passes; Windows desktop results contain four passes. The Linux desktop results in
`linux/desktop-results.tsv` are the eight llvmpipe checks; the separate
`linux/desktop-accelerated/` directory records the virgl failures. The binding
inventory still reports 22 direct SDL declarations and no direct C bool findings.

## Initial audio implementation

`SDL3.SDL3Audio` adds explicit-lifetime PCM streams and devices, including queued
playback, recording and conversion. `SDL3.SDL3AudioAudio` registers the `SDL3`
BRL.Audio driver, using existing sample loaders and native-only callbacks for
looping and stereo balance. SDL supplies mixing, conversion and resampling.

On 28 September 2026, `audio_streams`, `audio_driver` and `audio_exit` passed in
debug and release on macOS arm64, Linux arm64 and Windows x64 under ARM64 VM
emulation. All runs used SDL's dummy audio driver. The exit test leaves a loop
playing with SDL3.SDL3System imported, exercising audio shutdown before SDL quits.
See [audio usage and limitations](audio.md) for the public API, listening example,
ownership rules and remaining native-device checks.

## Audio streaming stabilisation

Added the backend-independent `Audio.Streams` interface and optional
`Audio.WavStream` and `Audio.VorbisStream` providers. `SOUND_STREAM` uses bounded
read-ahead on GC-aware managed workers; no managed callbacks or filesystem reads
run on SDL's audio thread. Ordinary sample loaders remain separate.

All seven audio tests passed in debug and release on macOS arm64, Ubuntu arm64
and Windows x64: 42 runs. This includes 30-second mixed-playback runs covering
three looping tracks, overlapping effects, abandoned one-shots, channel reuse,
pause/rate/pan changes, GC and shutdown. No workers or stream leases survived
shutdown. Native CoreAudio also completed the mixed test on macOS. The user
confirmed audible WAV completion and working Vorbis streaming on macOS.

Physical default-output switching, device disconnect/reconnect and microphone
capture remain manual validation items. Audio providers are in the separate
`audio.mod` namespace and must accompany the SDL3 driver in a distribution.

## FLAC and MP3 streaming providers

Added optional `Audio.FlacStream` and `Audio.Mp3Stream` providers using isolated,
pinned dr_flac 0.13.3 and dr_mp3 0.7.3 releases. Native callbacks borrow TStreams,
preserve nonzero origins and capture exceptions before returning to decoder code.
The shared adapter lives in `Audio.Streams`; existing provider interfaces are
unchanged. New decoder symbols are private to avoid collisions with other copies.

The codec tests cover exact FLAC PCM, mono/stereo CBR/VBR MP3, recognised encoder
delay/padding, unknown MP3 duration, seeks, short reads, malformed input, callback
failures and playback/looping. The expanded eight-test suite passed in debug and
release on macOS arm64, Linux arm64 and Windows x64 (48 runs). MP3 duration is not
calculated by a full-file scan at load; nonzero MP3 seeks currently decode forward
from the beginning. Untagged MP3s do not have guaranteed gapless boundaries.

## Desktop readiness review — 28 September 2026

Refreshed the consolidated macOS standalone headless pass at SDL3 revision
`a45f354`: all 16 tests passed in debug and release (32 runs) on macOS 15.7.4
arm64 with dummy video/software rendering. The runner checks both process success
and the test's pass marker, and rejects unhandled-exception output. Logs and
results are in `build-artifacts/sdl3-readiness/macos/`; the workspace runner is
`build-artifacts/sdl3-readiness/macos.py`. This closes the missing consolidated
macOS headless record; it does not add real desktop interaction coverage.

The binding scan again reports 22 direct SDL declarations and zero direct C bool
findings. Existing Windows/Linux headless and audio results remain as recorded
above; they were reviewed, not rerun during this documentation pass. The user also
confirmed working FLAC and MP3 music playback on macOS.

The updated [release checklist](release-checklist.md) separates completed work,
remaining implementation/review, validation and optional later APIs. The next
implementation priority is preserving wheel/touch/window information, handling
touch cancellation, defining multiple-window focus and adding text drops. Raw GL
context ownership, callback stress, the Linux virgl compatibility failure and
fresh-install dependency validation remain open. No API changes were made by this
review.

## Input fidelity and multiple-window focus

Added copied window-aware keyboard, committed-text, mouse, wheel and touch
payloads, detailed fractional/horizontal wheel events, accumulated legacy wheel
steps per window/device, full-width touch identifiers with stable legacy slots,
cancellation and text drops. Queued focus transfers are coalesced; delivered
held input is released on focus loss/destruction. Capture allows terminal events
for previously delivered input so starting capture mid-gesture cannot leave it
stuck. BRL character events retain UTF-16 code-unit semantics.

On 28 September 2026, all 17 headless tests passed in debug/release on macOS
arm64 (34 runs). The four focused tests — input_fidelity, system_events,
input_lifetime and clipboard_composition — passed in debug/release on Linux
arm64 and Windows x64 in the ARM64 VM (eight runs per VM). Logs and runners are
in `build-artifacts/sdl3-input/`. The binding scan still reports 22 direct SDL
declarations and no C bool signatures.

The new two-window manual example builds on macOS but was not interactively
validated in this pass. Real focus/capture/relative mode, trackpads, touchscreens,
IME and OS text-drop checks remain open. See [input events](input-events.md) for
payload, coordinate, allocation and capture contracts.

## Ownership and callback review — 28 September 2026

The user confirmed that the two-window input example works on macOS. This is a
manual smoke result, not a claim that every IME, touch or capture scenario was
exercised.

This review added explicit GL context/window ownership, current-context guards,
owner-first cleanup and defined zero outputs for failed size/position/GL attribute
queries. Lifecycle userdata is explicitly rooted until SDL shuts down. Lifecycle,
timer, joystick and gamepad callback exceptions are contained before returning to
native code and rethrown at a safe system polling boundary. Timer creation now
rejects nonpositive/nonfinite frequencies and out-of-range intervals.

The recovery regression exposed a BRL.System polling guard that remained set after
an exception. Local BRL commit `d6eefa4` resets it before rethrowing in both
PollSystem and WaitSystem; this companion fix is required for recovery. It changes
no successful polling behaviour.

Validation:

- All 18 macOS headless tests passed debug/release (36 runs). After extending the
  exception checks to controllers, callback_lifetime, joystick_gamepad and
  system_events passed again in both modes (six focused runs).
- The final callback_lifetime, timer_events, system_events and window_controls
  tests passed debug/release on Linux arm64 and Windows x64 in the ARM64 VM (eight
  runs per VM). An earlier Windows run hit shared build-cache interference from a
  concurrent macOS build; the final Windows run was sequential and passed.
- GL context ownership passed debug/release on the native macOS desktop. These
  new GL lifetime cases have not yet been run on the Windows/Linux desktop drivers.
- The binding inventory still finds 22 direct SDL declarations and no direct C
  bool signatures. This remains a narrow ABI check, not a full wrapper certificate.

Logs/runners are under `build-artifacts/sdl3-lifetime/`. The GL executables used
were `/tmp/sdl3-gl-context-lifetime` and `/tmp/sdl3-gl-context-lifetime-debug`.
See [ownership and callbacks](ownership-and-callbacks.md) for developer contracts.
Queue saturation, wider native callback reentrancy/shutdown stress, the remaining
per-wrapper audit and fresh-install validation remain open.

## Conventional Linux module build — 28 September 2026

Replaced the generated `.linux/cc-options` response file and CMake-selected import
list with a checked-in Linux configuration and relative source imports, following
SDL2's bundled-library arrangement. System header paths use pkg-config, as other
BlitzMax modules already do. Checked-in Wayland protocol code preserves upstream
licences; its regeneration script is a maintainer tool, not a build prerequisite.
The former `configure-linux.py` consumer step was removed.

The configuration declares a stable backend/dependency set instead of inheriting
the installed packages and newest libc functions of one build machine. The
README lists Ubuntu development packages and the API baselines. CMake, Python and
wayland-scanner are no longer required to build applications against these modules.
SDL is still compiled directly by BMK; there is no external SDL library dependency.

A fresh source-only SDL3 module was copied to the Linux VM, excluding `.linux`,
object files, archives and BlitzMax build caches. The previous VM module was kept
as `sdl3.mod-before-conventional-build`. The first release build compiled the full
bundled source set and passed the window/render test. Neither the checked-in
source list nor configuration/protocol files contain local absolute paths.

The final configuration passed window_render, callback_lifetime, joystick_gamepad
and audio_driver in debug/release with dummy drivers, plus graphics_gl and
GL context lifetime on both X11 and Wayland in both modes: 16 checks. Desktop GL
used llvmpipe; this does not resolve the separately recorded virgl readback issue.
These are Ubuntu arm64 results, not validation of x64, musl or every distribution.
Logs and scripts are in `build-artifacts/sdl3-linux-build/`.

## Selectable Linux backends — 28 September 2026

Linux builds now require BMK2 4.04 or newer. The module supplies one `module.bmk`
file, using BMK's scoped module configuration support (bmk_src commit `7ee8b55`).
Existing SDK `custom.bmk` or application `pre.bmk` settings select X11, Wayland
or both; SDL3-specific environment variables provide the same choices for
command-line builds. Both desktop backends and KMS/DRM remain enabled by default.
KMS/DRM can be disabled independently. See the README for settings and packages.

The Linux arm64 VM passed the compiled-backend check for X11 only, Wayland only,
both without KMS/DRM, and the default combination with KMS/DRM. Each enabled
desktop backend also passed the OpenGL check using llvmpipe. A rejecting
pkg-config wrapper verified that disabled backend dependency groups were not
queried; development packages were not physically uninstalled. This does not
resolve the previously recorded virgl issue. The macOS window/render smoke test
also passed with the updated BMK.

BMK's module configuration regression suite passed on macOS and Linux, including
configuration isolation, precedence, rebuild/relink tracking, removal, error
reporting and recovery. Updated BMK executables were installed in both development
SDKs with the previous versions preserved as `bmk-before-module-config`. The
Windows BMK executable remains unchanged; this new build-manager feature has
not yet been tested there. Logs and runners are in
`build-artifacts/bmk-module-config/`.

## Retired BRL.Max2D compatibility modules — 28 September 2026

Removed `SDL3.GLSDLGraphics`, `SDL3.GLSDLMax2D` and their dedicated
`tests/max2d_gl.bmx` test. SDL3 Max2D applications should use the new Max2D
namespace; applications requiring BRL.Max2D can retain SDL2. General OpenGL
window/context support remains in `SDL3.SDL3Graphics`, with `graphics_gl` coverage.

Earlier compatibility-driver results in this log are historical, including the
unresolved Linux virgl readback failure. The retired renderer is no longer a
release requirement. No new Max2D backend depended on either removed module.
