SuperStrict

Framework SDL3.SDL3AudioAudio
Import BRL.StandardIO
Import BRL.System
Import BRL.Math

If Not SetAudioDriver("SDL3") Then Throw SDL_GetError()
Local sample:TAudioSample = CreateAudioSample(48000, 48000, SF_MONO8)
For Local frame:Int = 0 Until sample.length
	sample.samples[frame] = Byte(128 + 100 * Sin(Float(frame) * 360 * 440 / 48000))
Next
Local tone:TSound = LoadSound(sample, SOUND_LOOP)
If Not tone Then Throw SDL_GetError()
Local channel:TChannel = CueSound(tone)
If Not channel Then Throw SDL_GetError()
SetChannelVolume(channel, 0.1)
SetChannelPan(channel, -1)
Print "Quiet 440 Hz tone: left"
ResumeChannel(channel)
Delay 1000
Print "Right"
SetChannelPan(channel, 1)
Delay 1000
Print "Centre, one octave higher"
SetChannelPan(channel, 0)
SetChannelRate(channel, 2)
Delay 1000
StopChannel(channel)
SetAudioDriver("Null")
Print "Finished"
