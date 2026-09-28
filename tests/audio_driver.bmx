SuperStrict

Framework SDL3.SDL3AudioAudio
Import BRL.StandardIO
Import BRL.System
Import "test_helpers.bmx"

Check SetAudioDriver("SDL3"), SDL_GetError()
Check String.FromCString(SDL_GetCurrentAudioDriver()) = "dummy", "Run with SDL_AUDIODRIVER=dummy"
Local sample:TAudioSample = CreateAudioSample(4800, 48000, SF_MONO8)
MemClear(sample.samples, Size_T(sample.length))
Local sound:TSound = LoadSound(sample)
Check sound, "Failed: sound"
Local channel:TChannel = AllocChannel()
Check channel And Not ChannelPlaying(channel), "Failed: channel And Not ChannelPlaying(channel)"
SetChannelVolume(channel, 0.25)
SetChannelPan(channel, -1)
SetChannelRate(channel, 2)
Check CueSound(sound, channel) = channel, "Failed: CueSound(sound, channel) = channel"
Check Not ChannelPlaying(channel), "Cue should remain paused"
ResumeChannel(channel)
Local deadline:Int = MilliSecs() + 3000
While ChannelPlaying(channel) And MilliSecs() < deadline
	Delay 10
Wend
Check Not ChannelPlaying(channel), "One-shot sound did not finish"
Check channel.Position() > 0, "Failed: channel.Position() > 0"
Check PlaySound(sound, channel) = channel, "Finished channel could not be reused"
PauseChannel(channel)
Check Not ChannelPlaying(channel), "Failed: Not ChannelPlaying(channel)"
ResumeChannel(channel)
StopChannel(channel)
Check Not ChannelPlaying(channel), "Failed: Not ChannelPlaying(channel)"
Check Not PlaySound(sound, channel), "Stopped channel should be inert"

Local looping:TSound = LoadSound(sample, SOUND_LOOP)
channel = PlaySound(looping)
Check channel, "Failed: channel"
Delay 250
Check ChannelPlaying(channel), "Loop ended at sample boundary"
PauseChannel(channel)
Local position:Int = channel.Position()
Delay 50
Check Not ChannelPlaying(channel) And channel.Position() = position, "Failed: Not ChannelPlaying(channel) And channel.Position() = position"
SetChannelPan(channel, 1)
SetChannelRate(channel, 0.5)
SetChannelVolume(channel, 0)
ResumeChannel(channel)
Check ChannelPlaying(channel), "Failed: ChannelPlaying(channel)"
GCCollect()
Check ChannelPlaying(channel), "Failed: ChannelPlaying(channel)"
SetAudioDriver("Null")
Check Not ChannelPlaying(channel), "Failed: Not ChannelPlaying(channel)"
StopChannel(channel)
Check SetAudioDriver("SDL3"), "Failed: SetAudioDriver(~qSDL3~q)"
Check Not PlaySound(sound), "Sound from previous driver generation should be rejected"
sound = LoadSound(sample)
Check PlaySound(sound), "Failed: PlaySound(sound)"
GCCollect()
Delay 150
SetAudioDriver("Null")
SDL_Quit()
Print "SDL3 BRL.Audio driver tests passed"

Extern "C"
	Function SDL_GetCurrentAudioDriver:Byte Ptr()
End Extern
