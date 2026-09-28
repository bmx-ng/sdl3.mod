SuperStrict

Framework SDL3.SDL3AudioAudio
Import SDL3.SDL3System
Import BRL.StandardIO
Import "test_helpers.bmx"

Check SetAudioDriver("SDL3"), SDL_GetError()
Check String.FromCString(SDL_GetCurrentAudioDriver()) = "dummy", "Run with SDL_AUDIODRIVER=dummy"
Local sample:TAudioSample = CreateAudioSample(4096, 48000, SF_MONO8)
MemClear(sample.samples, Size_T(sample.length))
Local sound:TSound = LoadSound(sample, SOUND_LOOP)
Check sound
Local channel:TChannel = PlaySound(sound)
Check channel
Print "Leaving looping playback active to test automatic shutdown"
' No explicit StopChannel, driver change or SDL_Quit: OnEnd ordering is the test.
Extern "C"
	Function SDL_GetCurrentAudioDriver:Byte Ptr()
End Extern
