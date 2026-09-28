SuperStrict

Framework SDL3.SDL3AudioAudio
Import Audio.WavStream
Import BRL.StandardIO
Import BRL.System
Import "test_helpers.bmx"

' A ten-minute WAV generated on demand: never allocate the complete recording.
Type TVirtualWav Extends TStream
	Field header:Byte[44]
	Field cursor:Long
	Field length:Long
	Field readBytes:Long
	Field closed:Int
	Field failAfter:Long = -1
	Field pattern:Byte[]

	Method New(frames:Int = 48000 * 600, bits:Int = 16)
		length = 44 + Long(frames) * (bits / 8)
		PutTag(0, "RIFF")
		PutInt(4, length - 8)
		PutTag(8, "WAVE")
		PutTag(12, "fmt ")
		PutInt(16, 16)
		header[20] = 1
		header[22] = 1
		PutInt(24, 48000)
		PutInt(28, 48000 * (bits / 8))
		header[32] = bits / 8
		header[34] = bits
		PutTag(36, "data")
		PutInt(40, length - 44)
	End Method

	Method PutTag(offset:Int, value:String)
		For Local i:Int = 0 Until 4
			header[offset + i] = value[i]
		Next
	End Method

	Method PutInt(offset:Int, value:Long)
		For Local i:Int = 0 Until 4
			header[offset + i] = value Shr (8 * i)
		Next
	End Method

	Method Pos:Long() Override
		Return cursor
	End Method

	Method Size:Long() Override
		Return length
	End Method

	Method Seek:Long(position:Long, whence:Int = SEEK_SET_) Override
		If whence <> SEEK_SET_ Or position < 0 Or position > length Then Return -1
		cursor = position
		Return cursor
	End Method

	Method Read:Long(data:Byte Ptr, count:Long) Override
		If failAfter >= 0 And cursor >= failAfter Then Throw "Injected read failure"
		count = Min(count, length - cursor)
		' Partial reads exercise the decoder's read-exact loop too.
		count = Min(count, 137:Long)
		For Local i:Int = 0 Until Int(count)
			If cursor < 44 Then
				data[i] = header[Int(cursor)]
			Else
				If pattern.length Then
					data[i] = pattern[Int((cursor - 44) Mod pattern.length)]
				Else
					data[i] = 0
				End If
			End If
			cursor :+ 1
		Next
		readBytes :+ count
		Return count
	End Method

	Method Close() Override
		closed = True
	End Method
End Type

For Local bits:Int = EachIn [8, 16, 24, 32]
	Local input:TVirtualWav = New TVirtualWav(100, bits)
	input.pattern = New Byte[bits / 8]
	input.pattern[input.pattern.length - 1] = 128
	Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(input)
	Check decoder And decoder.frames = 100 And decoder.channels = 1, "WAV metadata"
	Local pcm:Float[101]
	Check decoder.ReadFrames(pcm, 101) = 100, "WAV frame count"
	Local expected:Float = -1
	If bits = 8 Then expected = 0
	Check pcm[0] = expected And pcm[99] = expected, "PCM conversion"
	Check decoder.ReadFrames(pcm, 1) = 0, "WAV EOF"
	Check decoder.SeekFrame(99) And decoder.ReadFrames(pcm, 2) = 1, "WAV seek"
	decoder.Close()
	Check Not input.closed, "Decoder closed borrowed stream"
	For Local i:Int = 0 Until input.pattern.length
		input.pattern[i] = 255
	Next
	If bits <> 8 Then input.pattern[input.pattern.length - 1] = 127
	input.Seek(0)
	decoder = OpenAudioStreamDecoder(input)
	Check decoder.ReadFrames(pcm, 1) = 1 And pcm[0] >= 0.99 And pcm[0] <= 1.0, "Positive PCM conversion"
	decoder.Close()
Next

Local malformed:TVirtualWav = New TVirtualWav
malformed.header[20] = 3
ExpectInvalid(malformed)
malformed = New TVirtualWav
malformed.length :- 1
ExpectInvalid(malformed)
malformed = New TVirtualWav(2)
malformed.PutInt(40, 3)
ExpectInvalid(malformed)

Function ExpectInvalid(input:TStream)
	Try
		Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(input)
		If decoder Then decoder.Close()
	Catch error:Object
		Check input.Pos() = 0, "Failed probe did not restore position"
		Return
	End Try
	Throw "Malformed WAV was accepted"
End Function

Type TVirtualWavFactory Extends TStreamFactory
	Method CreateStream:TStream(url:Object, proto:String, path:String, readable:Int, writeMode:Int) Override
		If proto = "music-test" And readable And Not writeMode Then Return New TVirtualWav
	End Method
End Type
New TVirtualWavFactory

Check SetAudioDriver("SDL3"), SDL_GetError()
Local urlSound:TSound = LoadSound("music-test::track", SOUND_STREAM)
Check urlSound, SDL_GetError()
Local firstPlayer:TChannel = PlaySound(urlSound)
Local secondPlayer:TChannel = PlaySound(urlSound)
Check firstPlayer And secondPlayer, "URL playbacks should open independent streams"
StopChannel(firstPlayer)
StopChannel(secondPlayer)
Local source:TVirtualWav = New TVirtualWav
Local sound:TSound = LoadSound(source, SOUND_STREAM)
Check sound, SDL_GetError()
Check source.Pos() = 0 And source.readBytes = 44, "LoadSound should read only the header and restore position"
Local second:TSound = LoadSound(source, SOUND_STREAM)
Local channel:TChannel = CueSound(sound)
Check channel, SDL_GetError()
Delay 100
Check Not ChannelPlaying(channel), "Cue must remain paused"
Check Not PlaySound(second), "Borrowed stream must reject overlapping playback"
ResumeChannel(channel)
Delay 100
Check ChannelPlaying(channel), "Streaming channel should play"
PauseChannel(channel)
Local position:Int = channel.Position()
Delay 30
Check channel.Position() = position, "Paused position changed"
StopChannel(channel)
Check Not source.closed, "Stop closed borrowed stream"
Check source.readBytes < 100000, "Streaming read the whole recording or exceeded read-ahead bound"
Check Not SDLAudioStreamingError(channel), SDLAudioStreamingError(channel)
channel = PlaySound(sound)
Check channel, "Borrowed source was not released for replay"
StopChannel(channel)

Local shortSource:TVirtualWav = New TVirtualWav(100)
sound = LoadSound(shortSource, SOUND_STREAM | SOUND_LOOP)
channel = PlaySound(sound)
Check channel, SDL_GetError()
Delay 100
Check ChannelPlaying(channel), "Short streaming loop ended"
StopChannel(channel)

shortSource = New TVirtualWav(4800)
sound = LoadSound(shortSource, SOUND_STREAM)
channel = PlaySound(sound)
Local deadline:Int = MilliSecs() + 3000
While ChannelPlaying(channel) And MilliSecs() < deadline
	Delay 5
Wend
Check Not ChannelPlaying(channel), "One-shot stream did not finish"
Check Not SDLAudioStreamingError(channel), SDLAudioStreamingError(channel)
Check CueSound(sound, channel), "Finished channel was not reusable"
StopChannel(channel)

source = New TVirtualWav
source.failAfter = 10000
sound = LoadSound(source, SOUND_STREAM)
channel = PlaySound(sound)
Check channel, SDL_GetError()
deadline = MilliSecs() + 3000
While Not SDLAudioStreamingError(channel) And MilliSecs() < deadline
	Delay 5
Wend
Check SDLAudioStreamingError(channel) = "Injected read failure", "Worker did not preserve read failure"
StopChannel(channel)
Check Not source.closed, "Failure closed borrowed source"

source = New TVirtualWav
sound = LoadSound(source, SOUND_STREAM)
channel = PlaySound(sound)
Check channel, SDL_GetError()
GCCollect()
SetAudioDriver("Null")
Check Not ChannelPlaying(channel) And Not source.closed, "Shutdown cleanup"
Check SetAudioDriver("SDL3"), SDL_GetError()
For Local attempt:Int = 0 Until 20
	source = New TVirtualWav
	sound = LoadSound(source, SOUND_STREAM)
	channel = PlaySound(sound)
	Check channel, SDL_GetError()
	StopChannel(channel)
	Check Not SDLAudioStreamingError(channel), "Cancellation reported as a read failure"
Next
source = New TVirtualWav
sound = LoadSound(source, SOUND_STREAM | SOUND_LOOP)
Check PlaySound(sound), SDL_GetError()
Print "SDL3 incremental WAV playback tests passed; checking worker cleanup at process exit"
' Leave a live worker for the driver's OnEnd handler.
