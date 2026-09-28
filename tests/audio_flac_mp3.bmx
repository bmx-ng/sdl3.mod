SuperStrict

Framework SDL3.SDL3AudioAudio
Import Audio.FlacStream
Import Audio.Mp3Stream
Import Audio.WavStream
Import Audio.VorbisStream
Import BRL.BankStream
Import BRL.RamStream
Import BRL.StandardIO
Import BRL.System
Import "test_helpers.bmx"

Incbin "../../audio.mod/flacstream.mod/tests/data/mono.flac"
Incbin "../../audio.mod/flacstream.mod/tests/data/stereo.flac"
Incbin "../../audio.mod/mp3stream.mod/tests/data/mono.mp3"
Incbin "../../audio.mod/mp3stream.mod/tests/data/stereo.mp3"
Incbin "../../audio.mod/mp3stream.mod/tests/data/unknown.mp3"

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
		If failRead Then Throw "Injected decoder read failure"
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
		If failSeek Then Throw "Injected decoder seek failure"
		Return source.Seek(offset, whence)
	End Method

	Method Close() Override
		closed = True
	End Method
End Type


Check SetAudioDriver("SDL3"), SDL_GetError()
For Local codec:String = EachIn ["flac", "mp3"]
	For Local channels:Int = 1 To 2
		Local name:String = "mono"
		Local rate:Int = 44100
		If channels = 2 Then
			name = "stereo"
			rate = 48000
		End If
		Local url:String = "incbin::../../audio.mod/" + codec + "stream.mod/tests/data/" + name + "." + codec
		Local bank:TBank = LoadBank(url)
		Check bank, "Missing fixture"
		Local prefixed:TBank = CreateBank(Int(bank.Size()) + 13)
		MemCopy(prefixed.Buf() + 13, bank.Buf(), bank.Size())
		Local input:TObservedInput = New TObservedInput(prefixed)
		input.Seek(13)
		Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(input)
		Check decoder, "Decoder not found: " + codec
		Check decoder.channels = channels And decoder.hertz = rate, "PCM format: " + codec
		Check decoder.frames = rate, "Duration/MP3 delay-padding: " + codec + " got " + decoder.frames
		Local pcm:Float[] = New Float[257 * channels]
		Local reference:Float[2]
		Local total:Int
		Local energy:Double
		Repeat
			Local got:Int = decoder.ReadFrames(pcm, 257)
			If Not got Then Exit
			For Local i:Int = 0 Until got
				For Local c:Int = 0 Until channels
					Local value:Float = pcm[i * channels + c]
					Check value > -2 And value < 2, "Invalid PCM sample"
					energy :+ value * value
					If codec = "flac" Then
						Local expected:Float = (((total + i + c * 37) Mod 200) - 100) * 100 / 32768.0
						Check value = expected, "FLAC lossless conversion mismatch"
					End If
					If total + i = 5000 Then reference[c] = value
				Next
			Next
			total :+ got
		Forever
		Check total = rate And energy > 10, "Decoded frame count/energy: " + codec + " got " + total
		For Local attempt:Int = 0 Until 2
			Check decoder.SeekFrame(5000), "Seek failed: " + codec
			Check decoder.ReadFrames(pcm, 1) = 1, "Read after seek failed"
			For Local c:Int = 0 Until channels
				Check Abs(pcm[c] - reference[c]) < 0.000001, "Seek is not sample accurate: " + codec
			Next
		Next
		Check decoder.SeekFrame(0), "Rewind failed"
		Check Not decoder.SeekFrame(-1) And Not decoder.SeekFrame(rate + 1), "Out of range seek accepted"
		decoder.Close()
		decoder.Close()
		Check Not input.closed, "Decoder closed caller input"
		CheckReadFailure(bank)
		Local bad:TBank = CreateBank(4)
		MemCopy(bad.Buf(), bank.Buf(), 4)
		CheckInvalid(bad)

		Local sound:TSound = LoadSound(url, SOUND_STREAM)
		Check sound, SDL_GetError()
		Local channel:TChannel = CueSound(sound)
		Check channel And Not ChannelPlaying(channel), "Cue failed"
		ResumeChannel(channel)
		Local deadline:Int = MilliSecs() + 4000
		While ChannelPlaying(channel) And MilliSecs() < deadline
			Delay 5
		Wend
		Check Not ChannelPlaying(channel), "One shot did not finish"
		Check Not SDLAudioStreamingError(channel), SDLAudioStreamingError(channel)
		Check CueSound(sound, channel), "Finished channel reuse failed"
		StopChannel(channel)
		sound = LoadSound(url, SOUND_STREAM | SOUND_LOOP)
		channel = PlaySound(sound)
		Check channel, SDL_GetError()
		Delay 1100
		Check ChannelPlaying(channel), "Loop ended"
		StopChannel(channel)
		Check Not SDLAudioStreamingError(channel), SDLAudioStreamingError(channel)
		Print codec + " " + name + " passed"
	Next
Next

Local unknownFlac:TBank = LoadBank("incbin::../../audio.mod/flacstream.mod/tests/data/mono.flac")
' Clear the 36-bit STREAMINFO frame count, retaining sample rate/channels/depth.
unknownFlac.PokeByte(21, unknownFlac.PeekByte(21) & 240)
For Local i:Int = 22 Until 26
	unknownFlac.PokeByte(i, 0)
Next
Local flacDecoder:TAudioStreamDecoder = OpenAudioStreamDecoder(CreateBankStream(unknownFlac))
Check flacDecoder And flacDecoder.frames = -1, "FLAC missing frame count"
Local flacPCM:Float[1]
Check flacDecoder.SeekFrame(5001), "Unknown-length FLAC seek failed"
Check flacDecoder.ReadFrames(flacPCM, 1) = 1, "Unknown-length FLAC read failed"
Check flacPCM[0] = -9900 / 32768.0, "Unknown-length FLAC seek was clamped to start"
Check flacDecoder.SeekFrame(5037) And flacDecoder.ReadFrames(flacPCM, 1) = 1, "Second unknown-length FLAC seek failed"
Check flacPCM[0] = -6300 / 32768.0, "Unknown-length FLAC seek position mismatch"
flacDecoder.Close()

Local unknown:TStream = ReadStream("incbin::../../audio.mod/mp3stream.mod/tests/data/unknown.mp3")
Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(unknown)
Check decoder And decoder.frames = -1, "Missing MP3 duration must remain unknown"
Local pcm:Float[1024]
Local count:Int
Repeat
	Local got:Int = decoder.ReadFrames(pcm, 1024)
	If Not got Then Exit
	count :+ got
Forever
Check count >= 44100, "Untagged MP3 ended early"
Check decoder.SeekFrame(0) And decoder.ReadFrames(pcm, 1) = 1, "Untagged MP3 rewind failed"
decoder.Close()
unknown.Close()
SetAudioDriver("Null")
Print "FLAC/MP3 decoder and SDL3 streaming tests passed"

Function CheckInvalid(bank:TBank)
	Local input:TObservedInput = New TObservedInput(bank)
	Try
		Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(input)
		If Not decoder Then Return
		decoder.Close()
	Catch error:Object
		Check input.Pos() = 0 And Not input.closed, "Failed probe cleanup"
		Return
	End Try
	Throw "Malformed input was accepted"
End Function

Function CheckReadFailure(bank:TBank)
	Local input:TObservedInput = New TObservedInput(bank)
	Local decoder:TAudioStreamDecoder = OpenAudioStreamDecoder(input)
	Check decoder
	input.failRead = True
	Try
		decoder.SeekFrame(0)
		Local pcm:Float[] = New Float[2048 * decoder.channels]
		While decoder.ReadFrames(pcm, 2048)
		Wend
	Catch error:Object
		decoder.Close()
		Check error.ToString() = "Injected decoder read failure", "Callback failure lost: " + error.ToString()
		Check Not input.closed, "Failure closed caller stream"
		Return
	End Try
	decoder.Close()
	Throw "Read error was not reported"
End Function
