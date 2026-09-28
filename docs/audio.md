# Audio

## Use the standard BlitzMax sound API

Import `SDL3.SDL3AudioAudio` and select the `SDL3` driver. Existing audio sample
loaders continue to decode your files and streams:

```blitzmax
SuperStrict

Framework SDL3.SDL3AudioAudio
Import BRL.WAVLoader
Import BRL.StandardIO
Import BRL.System

If Not SetAudioDriver("SDL3") Then Throw SDL_GetError()
Local sound:TSound = LoadSound("effect.wav")
If Not sound Then Throw "Could not load effect.wav"
Local channel:TChannel = CueSound(sound)
If Not channel Then Throw SDL_GetError()
SetChannelVolume(channel, 0.5)
SetChannelPan(channel, -0.5)
ResumeChannel(channel)
While ChannelPlaying(channel)
	Delay 10
Wend
StopChannel(channel)
```

`LoadSound` accepts a filename, registered stream URL, `TStream`, or
`TAudioSample` through BRL's existing loading path. Import the appropriate decoder
for your format. This driver does not replace those loaders or add a second file
access mechanism.

The driver supports:

- Mono/stereo, unsigned 8-bit and signed 16-bit samples in either byte order.
- `PlaySound`, `CueSound`, `AllocChannel` and reuse of finished channels.
- `SOUND_LOOP`, pause/resume, volume and stereo pan.
- Playback-rate multipliers from 0.01 to 100, affecting speed and pitch together.
- Channel position in source sample frames (an estimate, not a hardware playback
  timestamp), and `ChannelPlaying` returning false while paused or finished.

`StopChannel` makes the channel inert, as specified by BRL.Audio. Allocate another
channel to play again after an explicit stop. Sounds from a previous driver
session are rejected after switching drivers; reload them for the new session.

Volume is clamped to 0–1 and pan to -1–1. Pan acts as stereo balance: moving left
attenuates the right channel, and vice versa. Changes affect future audio; samples
already queued to the device may still be heard briefly. Completion means SDL
has consumed the queued source data, not that every hardware buffer is empty.

This is a stereo software driver. `SetChannelDepth` has no effect and
`SOUND_HARDWARE` is ignored. Ordinary loaded sounds use native float stereo PCM,
which can take more memory than the original sample. Use `SOUND_STREAM` for
incremental file decoding as described below.

The native layer copies loaded sound data and retains it while a channel uses it.
Dropping the sample or sound wrapper does not invalidate playback. Dropping a
channel wrapper does not stop its sound; finished unowned channels are reclaimed
on subsequent channel allocation/release or driver shutdown. Loops continue until
stopped or the driver shuts down, so retain their channel if you need to stop them.

Audio callbacks contain native code only. SDL handles conversion, resampling and
mixing; the callback supplies PCM and implements looping/pan. It does not call
BlitzMax, allocate managed objects or require GC thread registration. Driver
shutdown waits for stream callbacks before releasing their data. Standard BRL
sound/channel methods should be called from the application's main thread.

The self-contained `tests/audio_manual.bmx` generates a quiet tone: left, right,
then centre at double pitch. It needs no media file or decoder import.

## Stream music without loading the whole file

Import `Audio.WavStream`, `Audio.VorbisStream`, `Audio.FlacStream` or
`Audio.Mp3Stream` for the formats you need, then use the
standard sound API:

```blitzmax
Import SDL3.SDL3AudioAudio
Import Audio.WavStream

If Not SetAudioDriver("SDL3") Then Throw SDL_GetError()
Local music:TSound = LoadSound("music.wav", SOUND_STREAM | SOUND_LOOP)
If Not music Then Throw SDL_GetError()
Local channel:TChannel = PlaySound(music)
If Not channel Then Throw SDL_GetError()
' Keep your game running. StopChannel(channel) stops and releases the source.
```

`LoadSound` inspects the header. Playback primes one small chunk and starts a
BlitzMax worker for further reads and decoding. SDL consumes queued PCM without
calling managed code. The worker uses the normal GC-aware thread API; a threaded
BlitzMax build is required. Each active playback has one worker and reusable
buffers, with at most 16,384 float stereo input frames (128 KiB) queued. Decoder
scratch space and SDL's conversion/device buffers are additional. Memory use does
not grow with the recording's duration. Slow reads can still cause underruns;
this first implementation does not share a worker pool between tracks.

- WAV support covers mono/stereo integer PCM: unsigned 8-bit and signed 16-, 24-
  and 32-bit little-endian samples. Compressed, floating-point, extensible and
  RF64 WAV files are not supported yet.
- `Audio.VorbisStream` adds mono/stereo Ogg Vorbis, including chains with identical
  sample rates and channel counts. It uses the existing `Pub.OggVorbis` library.
  Its native tell callback limits compressed inputs to 2 GiB minus one byte on
  Windows; oversized files fail explicitly. Ogg Opus is not supported.
- `Audio.FlacStream` adds mono/stereo native FLAC (not Ogg-encapsulated FLAC).
  `Audio.Mp3Stream` adds mono/stereo MP3, trimming recognised encoder delay and
  padding. Files without usable gapless metadata may retain those samples.
  MP3 duration stays unknown if absent from metadata; loading does not scan the
  whole track just to find its length. Nonzero MP3 seeks decode forward from the
  beginning, using bounded memory but potentially taking time. Both providers
  require seekable streams with a known byte length and use isolated dr_libs
  decoders, without importing SoLoud or Raylib.
- Providers are optional imports, registered through `Audio.Streams`. Importing
  `BRL.WAVLoader` or `BRL.OGGLoader` alone does not register a streaming decoder. Missing providers
  cause `LoadSound` to fail; there is no fallback to loading the entire file.
- Filenames and registered stream URLs use `ReadStream`, including BRL.IO-backed
  sources. Each playback reopens the source and owns that opened stream. Multiple
  playbacks are independent when the URL supplies independent streams.
- A supplied `TStream` stays open. Loading restores its initial position; playback
  starts there each time. The driver prevents overlapping use of the same stream
  object. Do not read, seek or close it while playback is active. Custom streams
  must allow reads on a worker thread. Wrapping the same underlying stream in
  different objects does not make concurrent access safe.
- Inputs must be seekable. `SOUND_LOOP` rewinds the decoder. Cue, pause, volume,
  pan, rate and finished-channel reuse work through the usual BRL.Audio calls.
  Queued samples retain their pan until consumed, so pan changes have read-ahead
  latency. Streaming positions count consumed frames across loops and saturate
  at the `Int` limit; they are approximate, not hardware timestamps.
- Setup failures return `Null` and set `SDL_GetError()`. Later read/decoder failures
  stop playback; call `SDLAudioStreamingError(channel)` to retrieve the message.
  An empty string means no recorded failure. Explicitly stopping a stream waits
  for its worker; a blocking custom read must finish before stop can return.

Try `tests/audio_music_manual.bmx` as a console application with a WAV, Ogg Vorbis, FLAC or MP3
filename argument. It streams the track once and reports any decoder error.

## Use SDL3 audio streams directly

Import `SDL3.SDL3Audio` for conversion, recording or application-supplied PCM.
This does not register or select a BRL.Audio driver.

```blitzmax
Local format:SSDLAudioSpec = New SSDLAudioSpec(SDL_AUDIO_S16, 2, 48000)
Using
	Local output:TSDLAudioStream = TSDLAudioStream.OpenPlayback(format)
Do
	If Not output Then Throw SDL_GetError()
	' pcm contains interleaved signed 16-bit stereo samples.
	If Not output.PutData(pcm) Then Throw SDL_GetError()
	output.Flush()
	output.Resume()
	' Keep the stream alive while playing; service your normal application loop.
End Using
```

The example fragment's `pcm` is a caller-supplied `Byte[]`. Leaving `Using` closes
playback immediately; do not leave the block while audio should still play.

`SSDLAudioSpec` describes format, channel count and sample frames per second.
A frame contains one sample for each channel. Audio-format constants are SDL's
`SDL_AUDIO_*` values, not BRL's `SF_*` values. Native-endian aliases are provided
alongside explicit little/big-endian constants.

- `Create(source, destination)` makes an independent converter. It needs no device.
- `OpenPlayback(spec)` opens a paused default playback stream. Queue data, then
  call `Resume`. `OpenRecording(spec)` similarly opens a paused recording stream;
  OS microphone permission may be required. Enumeration alone does not record.
- `PutData` copies from a `Byte[]`. `GetData` writes into a reusable `Byte[]` and
  returns the byte count, zero for no output, or -1 on failure. Both accept a byte
  offset/count; transfers must contain whole sample frames. Invalid array ranges
  are rejected before calling native code.
- `Queued()` reports unconverted input bytes. `Available()` reports output bytes
  currently obtainable after conversion. Neither is a hardware playhead.
- `Flush()` marks a temporary end of input so the converter releases its tail;
  it does not block until playback finishes. Use it at the end of a finite sound,
  not after every chunk of a continuous source. `Clear()` discards queued data.
- Gain and frequency-ratio controls are available on each stream.

Drain recording streams regularly and limit queued playback data to keep memory
bounded. No per-read array allocation is needed. This is PCM streaming; use an
appropriate decoder yourself for compressed file streaming.

## Separate devices and streams

`SDLAudioPlaybackDevices()` and `SDLAudioRecordingDevices()` return snapshots of
physical IDs; `SDLAudioDeviceName(id)` copies the name. IDs can change as devices
are disconnected. Empty enumeration results can mean no devices or an error;
inspect SDL_GetError if needed.

`TSDLAudioDevice.Open()` creates a logical device. It starts unpaused, so pause
before binding if data should not flow yet. Bind independent streams with
`device.Bind(stream)` or `stream.Bind(device)`. SDL manages each stream's
device-facing format. Several streams can share the device; device pause and gain
affect all of them. Closing it unbinds streams without destroying them.

Convenience streams created by `OpenPlayback`/`OpenRecording` own their logical
device. Closing them closes that device; they cannot be rebound or unbound.
Their Pause/Resume methods control that owned device. Independent streams instead
use their explicit device wrapper for pause/resume. Returned device IDs are
borrowed, not additional ownership handles.

Default-device opens allow SDL to follow system default-device changes. Physical
hotplug and migration have not yet been verified with real devices.

Both wrapper types implement `ICloseable`. Close them explicitly or with `Using`
before `SDL_Quit`; they have no GC finalizers. Serialize wrapper calls and cleanup
on your application thread. For the BRL driver, switch away from `SDL3` before
manually calling SDL_Quit. A shutdown callback also closes the driver at normal
process exit.

## Validation

`tests/audio_streams.bmx` checks PCM conversion, buffer slices, input copying,
invalid transfers, scoped cleanup, dummy playback/capture and device ownership.
`tests/audio_driver.bmx` checks standard BRL playback, cueing, looping, reuse,
pause, shutdown, driver switching and GC interaction. `tests/audio_exit.bmx`
checks normal exit with looping audio and SDL3.SDL3System both active.
`tests/audio_music.bmx` checks incremental PCM decoding, bounded read-ahead,
stream ownership, independent URL playbacks, looping, replay, worker failures,
cancellation and exit cleanup. `tests/audio_missing_decoder.bmx` verifies that
streaming fails without a provider instead of loading the whole file.
`tests/audio_vorbis.bmx` covers Vorbis decoding, seeking, chained streams, callback
failures and playback through the driver. `tests/audio_mixed.bmx` runs three looping
Vorbis tracks alongside repeated effects and abandoned one-shot streams for 30
seconds (or a supplied duration). It exercises pause, pan, rate, replacement of
streams by samples and back, repeated stopping, GC, shutdown and driver restart.
`tests/audio_flac_mp3.bmx` checks lossless FLAC output, MP3 delay/padding and
unknown duration, nonzero input origins, short reads, seeking, malformed inputs,
callback failures and playback/looping. Run with
`SDL_AUDIODRIVER=dummy`; these tests do not request microphone access or produce
sound. Actual listening, native capture and device hotplug need separate checks.

On 28 September 2026, all eight automated tests passed in debug and release on
macOS arm64, Ubuntu 26.04.1 arm64 and Windows 11 x64 (running in the ARM64 VM):
48 passing runs with SDL's dummy audio driver. Linux streaming validation was
completed after restarting the VM restored its guest command service.

The user also confirmed audible WAV playback to completion and working Ogg Vorbis
streaming on macOS. The 30-second mixed-playback test also passed through native CoreAudio on macOS;
that confirms the real-device path completed without reported errors, but is not
an independent listening assessment. Native microphone recording, hardware
latency and physical device changes still need verification.
Logs are retained in the workspace's `build-artifacts/sdl3-audio/` directory.
The ABI inventory reports no direct C bool bindings.

### Check output-device changes manually

Run the music example with a long track, then change the default output using the
operating system's sound settings. Confirm audio moves to the new output and
playback continues. If you have a removable output device, also disconnect it
while playing, check fallback to the available default output, then reconnect it
and select it again. Check for unexpected silence, hangs and decoder errors.

The driver opens the default playback device. SDL preserves that default-device
choice when opening the per-channel logical devices, so SDL handles migration.
Physical switching/reconnection still needs the checks above; dummy-device tests
do not exercise it. Stop playback and close the application after testing.
