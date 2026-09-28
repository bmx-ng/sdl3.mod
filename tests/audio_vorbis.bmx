SuperStrict

Framework SDL3.SDL3AudioAudio
Import Audio.VorbisStream
Import Audio.WavStream
Import BRL.BankStream
Import BRL.RamStream
Import BRL.StandardIO
Import BRL.System
Import "test_helpers.bmx"

Incbin "../../audio.mod/vorbisstream.mod/tests/data/mono.ogg"
Incbin "../../audio.mod/vorbisstream.mod/tests/data/stereo.ogg"

Type TObservedInput Extends TStream
	Field source:TStream
	Field closed:Int
	Field failRead:Int
	Field failSeek:Int
	Field reads:Long

	Method New(bank:TBank)
		source = CreateBankStream(bank)
	End Method

	Method Read:Long(output:Byte Ptr, count:Long) Override
		If failRead Then Throw "Injected Vorbis read failure"
		Local got:Long = source.Read(output, Min(count, 37:Long))
		reads :+ got
		Return got
	End Method

	Method Pos:Long() Override
		Return source.Pos()
	End Method

	Method Size:Long() Override
		Return source.Size()
	End Method

	Method Seek:Long(offset:Long, whence:Int = SEEK_SET_) Override
		If failSeek Then Throw "Injected Vorbis seek failure"
		Return source.Seek(offset, whence)
	End Method

	Method Close() Override
		closed = True
	End Method
End Type

Local mono:TBank = LoadBank("incbin::../../audio.mod/vorbisstream.mod/tests/data/mono.ogg")
Local stereo:TBank = LoadBank("incbin::../../audio.mod/vorbisstream.mod/tests/data/stereo.ogg")
Check mono And stereo, "Missing Vorbis fixtures"
For Local channels:Int = 1 To 2
	Local data:TBank = mono
	Local rate:Int = 48000
	If channels = 2 Then
		data = stereo
		rate = 44100
	End If
	' Exercise a nonzero starting position and short stream reads.
	Local prefixed:TBank = CreateBank(Int(data.Size()) + 13)
	MemCopy(prefixed.Buf() + 13, data.Buf(), data.Size())
	Local input:TObservedInput = New TObservedInput(prefixed)
	input.Seek(13)
	Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(input)
	Check decoder, "Vorbis open failed"
	Check decoder.channels = channels And decoder.hertz = rate And decoder.frames = rate / 4, "Vorbis metadata"
	Local pcm:Float[] = New Float[257 * channels]
	Local total:Long
	Local energy:Double
	Repeat
		Local got:Int = decoder.ReadFrames(pcm, 257)
		If Not got Then Exit
		Check got > 0 And got <= 257, "Invalid frame count"
		For Local i:Int = 0 Until got * channels
			Check pcm[i] >= -1 And pcm[i] <= 1, "Invalid float PCM"
			energy :+ pcm[i] * pcm[i]
		Next
		total :+ got
	Forever
	Check total = decoder.frames And energy > 1, "Incorrect decoded audio length or silence"
	Check decoder.SeekFrame(1000), "Vorbis seek failed"
	Check decoder.ReadFrames(pcm, 1) = 1, "Read after seek failed"
	Local sample:Float = pcm[0]
	Check decoder.SeekFrame(1000) And decoder.ReadFrames(pcm, 1) = 1, "Repeated seek failed"
	Check Abs(pcm[0] - sample) < 0.000001, "Seek was not sample accurate"
	Check Not decoder.SeekFrame(-1) And Not decoder.SeekFrame(decoder.frames + 1), "Out-of-range seek accepted"
	decoder.Close()
	decoder.Close()
	Check Not input.closed, "Decoder closed borrowed stream"
Next

' Distinct serial numbers are required for a valid chained stream.
Local chain:TBank = CreateBank(Int(mono.Size()) * 2)
MemCopy(chain.Buf(), mono.Buf(), mono.Size())
MemCopy(chain.Buf() + mono.Size(), mono.Buf(), mono.Size())
' Re-serialise the second link and regenerate its Ogg page checksums in native code.
Reserialise(chain.Buf() + mono.Size(), Int(mono.Size()))
Local input:TObservedInput = New TObservedInput(chain)
Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(input)
Check decoder And decoder.frames = 24000, "Homogeneous chain metadata"
Local pcm:Float[2048]
Local total:Long
Repeat
	Local got:Int = decoder.ReadFrames(pcm, 2048)
	If Not got Then Exit
	total :+ got
Forever
Check total = 24000, "Chained audio lost frames: " + total
Check decoder.SeekFrame(13000) And decoder.ReadFrames(pcm, 1) = 1, "Seek into second link failed"
decoder.Close()

Local mixed:TBank = CreateBank(Int(mono.Size() + stereo.Size()))
MemCopy(mixed.Buf(), mono.Buf(), mono.Size())
MemCopy(mixed.Buf() + mono.Size(), stereo.Buf(), stereo.Size())
ExpectFailure(New TObservedInput(mixed))
Local truncated:TBank = CreateBank(100)
MemCopy(truncated.Buf(), mono.Buf(), 100)
ExpectFailure(New TObservedInput(truncated))
input = New TObservedInput(mono)
input.failRead = True
ExpectFailure(input)

input = New TObservedInput(mono)
decoder = OpenAudioStreamDecoder(input)
input.failSeek = True
ExpectSeekFailure(decoder)
decoder.Close()
Check Not input.closed, "Seek failure closed caller stream"
input = New TObservedInput(mono)
decoder = OpenAudioStreamDecoder(input)
input.failRead = True
ExpectReadFailure(decoder)
decoder.Close()
Check Not input.closed, "Read failure closed caller stream"

Check SetAudioDriver("SDL3"), SDL_GetError()
input = New TObservedInput(stereo)
Local sound:TSound = LoadSound(input, SOUND_STREAM)
Check sound And input.Pos() = 0, SDL_GetError()
Local channel:TChannel = PlaySound(sound)
Check channel, SDL_GetError()
Local deadline:Int = MilliSecs() + 3000
While ChannelPlaying(channel) And MilliSecs() < deadline
	Delay 5
Wend
Check Not ChannelPlaying(channel) And Not SDLAudioStreamingError(channel), "Vorbis playback did not finish cleanly"
Check CueSound(sound, channel), "Vorbis replay failed"
StopChannel(channel)
Check Not input.closed, "Playback closed borrowed input"
input.Seek(0)
sound = LoadSound(input, SOUND_STREAM | SOUND_LOOP)
Check sound, SDL_GetError()
channel = PlaySound(sound)
Check channel, SDL_GetError()
Delay 600
Check ChannelPlaying(channel), "Vorbis loop ended"
PauseChannel(channel)
Local position:Int = channel.Position()
Delay 20
Check channel.Position() = position, "Paused Vorbis position changed"
StopChannel(channel)
Check Not SDLAudioStreamingError(channel), SDLAudioStreamingError(channel)
SetAudioDriver("Null")
Print "Vorbis decoder and SDL3 streaming tests passed"

Function ExpectFailure(input:TObservedInput)
	Try
		Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(input)
		If Not decoder Then
			Check Not input.closed And input.Pos() = 0, "Unrecognised input was not restored"
			Return
		End If
		decoder.Close()
	Catch error:Object
		Check Not input.closed And input.Pos() = 0, "Failed open did not preserve input ownership/position"
		Return
	End Try
	Throw "Expected invalid Vorbis input to fail"
End Function

Function ExpectReadFailure(decoder:TAudioStreamDecoder)
	Try
		decoder.SeekFrame(0)
		Local pcm:Float[2048]
		While decoder.ReadFrames(pcm, 2048)
		Wend
	Catch error:Object
		Check error.ToString() = "Injected Vorbis read failure", "Read exception was lost"
		Return
	End Try
	Throw "Expected read callback failure"
End Function

Function ExpectSeekFailure(decoder:TAudioStreamDecoder)
	Try
		decoder.SeekFrame(0)
	Catch error:Object
		Check error.ToString() = "Injected Vorbis seek failure", "Seek exception was lost"
		Return
	End Try
	Throw "Expected seek callback failure"
End Function

Import "audio_vorbis_fixture.c"
Extern
	Function Reserialise(data:Byte Ptr, length:Int) = "test_vorbis_reserialise"
End Extern
