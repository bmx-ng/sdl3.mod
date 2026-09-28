SuperStrict

Framework SDL3.SDL3AudioAudio
Import Audio.WavStream
Import Audio.VorbisStream
Import Audio.FlacStream
Import Audio.Mp3Stream
Import BRL.StandardIO
Import BRL.System

' Build as a console application, then pass a WAV, Vorbis, FLAC or MP3 filename.
' Streaming providers are optional imports; ordinary sample loaders are not used.
If AppArgs.length <> 2 Then
	Print "Usage: audio_music_manual <music.wav|music.ogg|music.flac|music.mp3>"
	End
End If
If Not SetAudioDriver("SDL3") Then Throw SDL_GetError()
Local music:TSound = LoadSound(AppArgs[1], SOUND_STREAM)
If Not music Then Throw SDL_GetError()
Local channel:TChannel = PlaySound(music)
If Not channel Then Throw SDL_GetError()
Print "Streaming " + AppArgs[1]
While ChannelPlaying(channel)
	Delay 20
Wend
Local failure:String = SDLAudioStreamingError(channel)
StopChannel(channel)
SetAudioDriver("Null")
If failure Then Throw failure
Print "Finished"
