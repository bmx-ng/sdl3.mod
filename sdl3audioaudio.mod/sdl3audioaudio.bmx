SuperStrict

Rem
bbdoc: SDL3 playback driver for the standard BRL.Audio API.
about: Import this module and select SetAudioDriver("SDL3"). Supports loaded samples, looping, cueing, reusable channels, pause, volume, stereo balance and playback rate. Existing audio sample loaders retain responsibility for filenames and TStreams. Native callbacks never enter BlitzMax. SOUND_HARDWARE is a hint and is ignored; SOUND_STREAM uses optional Audio.Streams decoder providers and bounded background buffering. SetDepth has no effect on this stereo driver.
End Rem
Module SDL3.SDL3AudioAudio
ModuleInfo "License: zlib/libpng"
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3Audio
Import BRL.Audio
Import "glue.c"
Import "streaming.bmx"

Rem
bbdoc: Returns an asynchronous streaming error for a channel, or an empty string.
about: Streaming read/decoder failures stop playback and are retained here; no exception crosses the audio callback. LoadSound/PlaySound setup failures return Null and describe the error through SDL_GetError.
End Rem
Function SDLAudioStreamingError:String(channel:TChannel)
	Local value:TSDLChannel = TSDLChannel(channel)
	If value And value.job Then Return value.job.Error()
	Return ""
End Function

Private
Global generation:Int
Global active:Int
Global shutdownRegistered:Int

Function ShutdownAudio()
	StopStreamingJobs()
	bmx_SDL3_AudioDriverStop()
	active = False
End Function

Type TSDLStreamingSound Extends TSound
	Field url:Object
	Field origin:Long
	Field serial:Int
	Field loop:Int

	Function Load:TSDLStreamingSound(url:Object, flags:Int)
		Local session:TSDLDecodeSession = New TSDLDecodeSession
		Local sound:TSDLStreamingSound = New TSDLStreamingSound
		Try
			session.Open(url)
			sound.url = url
			sound.origin = session.origin
			sound.serial = generation
			sound.loop = (flags & SOUND_LOOP) <> 0
		Catch error:Object
			bmx_SDL3_AudioStreamingError(error.ToString())
			session.Close(True)
			Return Null
		End Try
		Local closeError:String = session.Close(True)
		If closeError Then
			bmx_SDL3_AudioStreamingError(closeError)
			Return Null
		End If
		Return sound
	End Function

	Method Play:TChannel(channel:TChannel = Null) Override
		Return Start(channel, False)
	End Method

	Method Cue:TChannel(channel:TChannel = Null) Override
		Return Start(channel, True)
	End Method

	Method Start:TChannel(channel:TChannel, paused:Int)
		If Not active Or serial <> generation Then Return Null
		Local target:TSDLChannel = TSDLChannel(channel)
		If channel And (Not target Or target.serial <> generation) Then Return Null
		If Not target Then target = TSDLChannel.Create()
		If Not target Then Return Null
		target.CancelStream()
		Local job:TSDLStreamJob = New TSDLStreamJob
		job.channel = target
		job.handle = target.handle
		job.loop = loop
		Try
			job.session.Open(url, origin)
			job.buffer = New Float[2048 * job.session.decoder.channels]
			If Not bmx_SDL3_AudioStreamingStart(target.handle, job.session.decoder.hertz) Then Throw SDL_GetError()
			If Not job.Fill(2048) Then Throw "Streaming audio source is empty"
			target.job = job
			streamingMutex.Lock()
			streamingJobs.AddLast(job)
			streamingMutex.Unlock()
			job.thread = CreateThread(TSDLStreamJob.Run, job)
			If Not job.thread Or Not job.thread._handle Then Throw "Unable to create audio streaming worker"
			If Not paused Then target.SetPaused(False)
		Catch error:Object
			job.Cancel()
			job.Wait()
			job.session.Close()
			streamingMutex.Lock()
			streamingJobs.Remove(job)
			streamingMutex.Unlock()
			bmx_SDL3_AudioStreamingEnd(target.handle, True)
			bmx_SDL3_AudioStreamingError(error.ToString())
			Return Null
		End Try
		Return target
	End Method
End Type

Type TSDLSound Extends TSound
	Field handle:Byte Ptr
	Field serial:Int

	Method Delete()
		If handle Then bmx_SDL3_AudioSoundFree(handle)
	End Method

	Method Play:TChannel(channel:TChannel = Null) Override
		Return Start(channel, False)
	End Method

	Method Cue:TChannel(channel:TChannel = Null) Override
		Return Start(channel, True)
	End Method

	Method Start:TChannel(channel:TChannel, paused:Int)
		If Not active Or serial <> generation Then Return Null
		Local target:TSDLChannel
		If channel Then
			target = TSDLChannel(channel)
			If Not target Or target.serial <> generation Then Return Null
		Else
			target = TSDLChannel.Create()
		End If
		If Not target Then Return Null
		target.CancelStream()
		If Not bmx_SDL3_AudioChannelPlay(target.handle, handle, paused) Then Return Null
		Return target
	End Method
End Type

Type TSDLChannel Extends TChannel
	Field job:TSDLStreamJob

	Method CancelStream()
		If job Then
			job.Cancel()
			job.Wait()
			job = Null
		End If
	End Method
	Field handle:Byte Ptr
	Field serial:Int

	Function Create:TSDLChannel()
		Local ptr:Byte Ptr = bmx_SDL3_AudioChannelCreate()
		If Not ptr Then Return Null
		Local channel:TSDLChannel = New TSDLChannel
		channel.handle = ptr
		channel.serial = generation
		Return channel
	End Function

	Method Delete()
		If handle Then bmx_SDL3_AudioChannelFree(handle)
	End Method

	Method Stop() Override
		If job Then job.Cancel()
		bmx_SDL3_AudioChannelStop(handle)
		If job Then job.Wait()
	End Method

	Method SetPaused(paused:Int) Override
		bmx_SDL3_AudioChannelSet(handle, 0, Float(paused <> 0))
	End Method

	Method SetVolume(volume:Float) Override
		bmx_SDL3_AudioChannelSet(handle, 1, volume)
	End Method

	Method SetPan(pan:Float) Override
		bmx_SDL3_AudioChannelSet(handle, 2, pan)
	End Method

	Method SetDepth(depth:Float) Override
		' No front/back speaker distinction in this stereo driver.
	End Method

	Method SetRate(rate:Float) Override
		bmx_SDL3_AudioChannelSet(handle, 3, rate)
	End Method

	Method Playing:Int() Override
		Return bmx_SDL3_AudioChannelPlaying(handle)
	End Method

	Method Position:Int() Override
		Return bmx_SDL3_AudioChannelPosition(handle)
	End Method
End Type

Private
Type TSDLAudioDriver Extends TAudioDriver
	Method Name:String() Override
		Return "SDL3"
	End Method

	Method Startup:Int() Override
		active = bmx_SDL3_AudioDriverStart()
		If active Then
			generation :+ 1
			If Not shutdownRegistered Then
				OnEnd(ShutdownAudio)
				shutdownRegistered = True
			End If
		End If
		Return active
	End Method

	Method Shutdown() Override
		ShutdownAudio()
	End Method

	Method LoadSound:TSound(url:Object, flags:Int = 0) Override
		If flags & SOUND_STREAM Then
			If Not active Then Return Null
			Return TSDLStreamingSound.Load(url, flags)
		End If
		Return TSound.Load(url, flags)
	End Method

	Method CreateSound:TSound(sample:TAudioSample, flags:Int) Override
		If Not active Or Not sample Or sample.length <= 0 Or sample.hertz <= 0 Then Return Null
		Local format:Int, channels:Int
		Select sample.format
			Case SF_MONO8, SF_STEREO8
				format = SDL_AUDIO_U8
			Case SF_MONO16LE, SF_STEREO16LE
				format = SDL_AUDIO_S16LE
			Case SF_MONO16BE, SF_STEREO16BE
				format = SDL_AUDIO_S16BE
			Default
				Return Null
		End Select
		channels = ChannelsPerSample[sample.format]
		Local ptr:Byte Ptr = bmx_SDL3_AudioSoundCreate(sample.samples, sample.length, sample.hertz, format, channels, flags & SOUND_LOOP)
		If Not ptr Then Return Null
		Local sound:TSDLSound = New TSDLSound
		sound.handle = ptr
		sound.serial = generation
		Return sound
	End Method

	Method AllocChannel:TChannel() Override
		If Not active Then Return Null
		Return TSDLChannel.Create()
	End Method
End Type

New TSDLAudioDriver

Extern
	Function bmx_SDL3_AudioDriverStart:Int()
	Function bmx_SDL3_AudioDriverStop()
	Function bmx_SDL3_AudioSoundCreate:Byte Ptr(data:Byte Ptr, frames:Int, freq:Int, format:Int, channels:Int, loop:Int)
	Function bmx_SDL3_AudioSoundFree(sound:Byte Ptr)
	Function bmx_SDL3_AudioChannelCreate:Byte Ptr()
	Function bmx_SDL3_AudioChannelFree(channel:Byte Ptr)
	Function bmx_SDL3_AudioChannelPlay:Int(channel:Byte Ptr, sound:Byte Ptr, paused:Int)
	Function bmx_SDL3_AudioChannelStop(channel:Byte Ptr)
	Function bmx_SDL3_AudioChannelSet(channel:Byte Ptr, property:Int, value:Float)
	Function bmx_SDL3_AudioChannelPlaying:Int(channel:Byte Ptr)
	Function bmx_SDL3_AudioChannelPosition:Int(channel:Byte Ptr)
End Extern
