SuperStrict

Framework SDL3.SDL3AudioAudio
Import Audio.VorbisStream
Import BRL.RamStream
Import BRL.StandardIO
Import BRL.System
Import BRL.Math
Import "test_helpers.bmx"

Incbin "../../audio.mod/vorbisstream.mod/tests/data/stereo.ogg"

' Runs quietly on a real device, or silently with SDL_AUDIODRIVER=dummy.
' Pass a duration in seconds for a longer run. Default: 30 seconds.
Local seconds:Int = 30
If AppArgs.length > 1 Then seconds = Max(1, Int(AppArgs[1]))
Check SetAudioDriver("SDL3"), SDL_GetError()
Local url:String = "incbin::../../audio.mod/vorbisstream.mod/tests/data/stereo.ogg"
Local music:TSound = LoadSound(url, SOUND_STREAM | SOUND_LOOP)
Local shortMusic:TSound = LoadSound(url, SOUND_STREAM)
Check music And shortMusic, SDL_GetError()
Local sample:TAudioSample = CreateAudioSample(4800, 48000, SF_MONO8)
For Local i:Int = 0 Until sample.length
	sample.samples[i] = 128 + Int(8 * Sin(i * 360.0 * 220 / 48000))
Next
Local effect:TSound = LoadSound(sample)
Check effect
Local tracks:TChannel[3]
For Local i:Int = 0 Until tracks.length
	tracks[i] = CueSound(music)
	Check tracks[i], SDL_GetError()
	SetChannelVolume(tracks[i], 0.1)
	ResumeChannel(tracks[i])
Next
Local effects:TChannel[8]
Local start:Int = MilliSecs()
Local tick:Int
While MilliSecs() - start < seconds * 1000
	Local index:Int = tick Mod tracks.length
	Local track:TChannel = tracks[index]
	Check Not SDLAudioStreamingError(track), SDLAudioStreamingError(track)
	Select tick Mod 20
		Case 0
			PauseChannel(track)
			Local position:Int = track.Position()
			Delay 10
			Check track.Position() = position, "Paused music moved"
			ResumeChannel(track)
		Case 1
			SetChannelRate(track, 0.5)
		Case 2
			SetChannelRate(track, 2)
		Case 3
			SetChannelPan(track, -1)
		Case 4
			SetChannelPan(track, 1)
		Case 5
			' Replace a live stream with a sample, then with another stream.
			Check CueSound(effect, track), "Stream-to-sample replacement failed"
			Check CueSound(music, track), "Sample-to-stream replacement failed"
			ResumeChannel(track)
		Case 6
			StopChannel(track)
			Check Not SDLAudioStreamingError(track), "Stop reported a decode failure"
			tracks[index] = CueSound(music)
			Check tracks[index], SDL_GetError()
			SetChannelVolume(tracks[index], 0.1)
			ResumeChannel(tracks[index])
		Case 7
			GCCollect()
	End Select
	If tick Mod 4 = 0 Then
		Local slot:Int = (tick / 4) Mod effects.length
		If effects[slot] Then StopChannel(effects[slot])
		effects[slot] = CueSound(effect)
		Check effects[slot], "Effect allocation failed"
		SetChannelVolume(effects[slot], 0.1)
		ResumeChannel(effects[slot])
	End If
	If tick Mod 12 = 0 Then
		' Abandon a one-shot channel; playback must own it until decoding ends.
		Local abandoned:TChannel = CueSound(shortMusic)
		Check abandoned, SDL_GetError()
		SetChannelVolume(abandoned, 0.1)
		ResumeChannel(abandoned)
	End If
	tick :+ 1
	Delay 25
Wend
SetAudioDriver("Null")
streamingMutex.Lock()
Local jobs:Int = streamingJobs.Count()
Local leases:Int = streamingLeases.Count()
streamingMutex.Unlock()
Check jobs = 0 And leases = 0, "Streaming workers or input leases survived shutdown"
For Local track:TChannel = EachIn tracks
	Check Not ChannelPlaying(track), "Music survived driver shutdown"
	Check Not SDLAudioStreamingError(track), SDLAudioStreamingError(track)
Next
GCCollect()
Check SetAudioDriver("SDL3"), "Driver did not restart"
Check Not PlaySound(music), "Old streaming sound survived driver generation change"
SetAudioDriver("Null")
Print "Mixed audio test passed: " + seconds + " seconds, " + tick + " update cycles"
