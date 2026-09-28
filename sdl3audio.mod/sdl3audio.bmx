SuperStrict

Rem
bbdoc: SDL3 audio devices and queued PCM streams.
about: Streams convert interleaved PCM data and can play or record through a device. Explicitly Close resources, optionally with Using, before SDL_Quit. Serialize access to each wrapper, especially Close; native audio processing runs on SDL threads without calling BlitzMax. Importing this module does not select a BRL.Audio driver.
End Rem
Module SDL3.SDL3Audio

ModuleInfo "License: zlib/libpng"
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3
Import "glue.c"

Const SDL_AUDIO_U8:Int = $0008
Const SDL_AUDIO_S8:Int = $8008
Const SDL_AUDIO_S16LE:Int = $8010
Const SDL_AUDIO_S16BE:Int = $9010
Const SDL_AUDIO_S32LE:Int = $8020
Const SDL_AUDIO_S32BE:Int = $9020
Const SDL_AUDIO_F32LE:Int = $8120
Const SDL_AUDIO_F32BE:Int = $9120
?bigendian
Const SDL_AUDIO_S16:Int = SDL_AUDIO_S16BE
Const SDL_AUDIO_S32:Int = SDL_AUDIO_S32BE
Const SDL_AUDIO_F32:Int = SDL_AUDIO_F32BE
?Not bigendian
Const SDL_AUDIO_S16:Int = SDL_AUDIO_S16LE
Const SDL_AUDIO_S32:Int = SDL_AUDIO_S32LE
Const SDL_AUDIO_F32:Int = SDL_AUDIO_F32LE
?
Const SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK:UInt = $FFFFFFFF:UInt
Const SDL_AUDIO_DEVICE_DEFAULT_RECORDING:UInt = $FFFFFFFE:UInt

Rem
bbdoc: Interleaved PCM format, channel count and sample frames per second.
about: These are SDL audio formats, not BRL.AudioSample SF_* constants. A sample frame contains one sample for every channel.
End Rem
Struct SSDLAudioSpec
	Field format:Int
	Field channels:Int
	Field freq:Int

	Method New(format:Int, channels:Int, freq:Int)
		Self.format = format
		Self.channels = channels
		Self.freq = freq
	End Method
End Struct

Rem
bbdoc: Returns a snapshot of physical playback device IDs. Empty on failure or when none exist; inspect SDL_GetError.
End Rem
Function SDLAudioPlaybackDevices:UInt[]()
	Return _AudioDevices(False)
End Function

Rem
bbdoc: Returns a snapshot of physical recording device IDs. Enumeration does not open a microphone.
End Rem
Function SDLAudioRecordingDevices:UInt[]()
	Return _AudioDevices(True)
End Function

Rem
bbdoc: Returns a copied device name, or an empty string on failure.
End Rem
Function SDLAudioDeviceName:String(id:UInt)
	Return bmx_SDL3_AudioDeviceName(id)
End Function

Rem
bbdoc: An owned logical audio device. Close unbinds its streams without destroying them.
about: Devices opened directly start unpaused. Pause before binding if data must not flow yet. Opening the default device allows SDL to follow default-device changes. Explicit recording opens may request OS microphone permission.
End Rem
Type TSDLAudioDevice Implements ICloseable
	Private
	Field _id:UInt
	Public

	Rem
	bbdoc: Opens a device using SDL's preferred hardware format. Stream formats are specified separately.
	End Rem
	Function Open:TSDLAudioDevice(id:UInt = SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK)
		If Not _InitAudio() Then Return Null
		Local value:UInt = bmx_SDL3_OpenAudioDevice(id)
		If Not value Then Return Null
		Local device:TSDLAudioDevice = New TSDLAudioDevice
		device._id = value
		Return device
	End Function

	Method ID:UInt()
		Return _id
	End Method

	Method Close() Override
		If Not _id Then Return
		bmx_SDL3_CloseAudioDevice(_id)
		_id = 0
	End Method

	Rem
	bbdoc: Binds an independent stream; its device-facing format is managed by SDL. Device-owned convenience streams cannot be rebound.
	End Rem
	Method Bind:Int(stream:TSDLAudioStream)
		If Not _id Or Not stream Then Return False
		Return stream.Bind(Self)
	End Method

	Rem
	bbdoc: Gets the current hardware format and device buffer size in sample frames.
	End Rem
	Method GetFormat:Int(spec:SSDLAudioSpec Var, frames:Int Var)
		spec = New SSDLAudioSpec
		frames = 0
		If Not _id Then Return False
		Return bmx_SDL3_GetAudioDeviceFormat(_id, spec, Varptr frames)
	End Method

	Method Pause:Int()
		If Not _id Then Return 0
		Return bmx_SDL3_PauseAudioDevice(_id)
	End Method

	Method Resume:Int()
		If Not _id Then Return 0
		Return bmx_SDL3_ResumeAudioDevice(_id)
	End Method

	Method Paused:Int()
		If Not _id Then Return 0
		Return bmx_SDL3_AudioDevicePaused(_id)
	End Method

	Method GetGain:Float()
		If Not _id Then Return 0
		Return bmx_SDL3_GetAudioDeviceGain(_id)
	End Method

	Rem
	bbdoc: Sets nonnegative device gain; 1 is unchanged, 0 is silence.
	End Rem
	Method SetGain:Int(gain:Float)
		If Not _id Then Return False
		Return bmx_SDL3_SetAudioDeviceGain(_id, gain)
	End Method
End Type

Rem
bbdoc: An owned PCM conversion, playback or recording stream.
about: PutData copies bytes into SDL storage before returning. GetData writes into a caller-provided buffer. No BlitzMax callback is invoked from audio threads. Clear discards queued data; Flush marks the end of input for conversion, it does not wait for playback. There is no GC finalizer: use Close or Using.
End Rem
Type TSDLAudioStream Implements ICloseable
	Private
	Field _handle:Byte Ptr
	Field _ownsDevice:Int
	Public

	Rem
	bbdoc: Creates an independent conversion stream, optionally bound later with TSDLAudioDevice.Bind.
	End Rem
	Function Create:TSDLAudioStream(source:SSDLAudioSpec Var, destination:SSDLAudioSpec Var)
		Return _Wrap(bmx_SDL3_CreateAudioStream(source, destination), False)
	End Function

	Rem
	bbdoc: Opens a paused playback stream. spec describes the bytes supplied by PutData; call Resume after queueing data.
	End Rem
	Function OpenPlayback:TSDLAudioStream(spec:SSDLAudioSpec Var, id:UInt = SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK)
		If Not _InitAudio() Then Return Null
		Return _Wrap(bmx_SDL3_OpenAudioDeviceStream(id, spec, True), True)
	End Function

	Rem
	bbdoc: Opens a paused recording stream. spec describes the bytes returned by GetData; Resume starts capture.
	about: Callers must drain the stream regularly to bound memory use. This can request microphone permission.
	End Rem
	Function OpenRecording:TSDLAudioStream(spec:SSDLAudioSpec Var, id:UInt = SDL_AUDIO_DEVICE_DEFAULT_RECORDING)
		If Not _InitAudio() Then Return Null
		Return _Wrap(bmx_SDL3_OpenAudioDeviceStream(id, spec, False), True)
	End Function

	Method IsValid:Int()
		Return _handle <> Null
	End Method

	Rem
	bbdoc: Destroys the stream and closes its device if created with OpenPlayback or OpenRecording. Safe to call repeatedly.
	End Rem
	Method Close() Override
		If Not _handle Then Return
		bmx_SDL3_DestroyAudioStream(_handle)
		_handle = Null
	End Method

	Rem
	bbdoc: Returns the bound logical device ID, or zero. The ID is borrowed; do not close it outside its owning wrapper.
	End Rem
	Method DeviceID:UInt()
		If Not _handle Then Return 0
		Return bmx_SDL3_GetAudioStreamDevice(_handle)
	End Method

	Rem
	bbdoc: Binds an independent stream to an owned logical device.
	End Rem
	Method Bind:Int(device:TSDLAudioDevice)
		If Not _handle Or _ownsDevice Or Not device Or Not device.ID() Then Return False
		Return bmx_SDL3_BindAudioStream(device.ID(), _handle)
	End Method

	Rem
	bbdoc: Unbinds an independent stream. Returns False for a closed stream or a convenience stream that owns its device.
	End Rem
	Method Unbind:Int()
		If Not _handle Or _ownsDevice Then Return False
		bmx_SDL3_UnbindAudioStream(_handle)
		Return True
	End Method

	Rem
	bbdoc: Gets both PCM formats. Outputs are zeroed on failure.
	End Rem
	Method GetFormat:Int(source:SSDLAudioSpec Var, destination:SSDLAudioSpec Var)
		source = New SSDLAudioSpec
		destination = New SSDLAudioSpec
		If Not _handle Then Return False
		Return bmx_SDL3_GetAudioStreamFormat(_handle, source, destination)
	End Method

	Rem
	bbdoc: Copies whole input sample frames into the stream. count=-1 selects the remaining array; offset and count are bytes.
	End Rem
	Method PutData:Int(data:Byte[], offset:Int = 0, count:Int = -1)
		If Not _handle Then Return False
		If Not _Range(data, offset, count) Then Return False
		Return bmx_SDL3_PutAudioStreamData(_handle, data, offset, count)
	End Method

	Rem
	bbdoc: Reads converted PCM into the array, returning bytes written, zero if none are available, or -1 on failure.
	about: offset and count are bytes; count=-1 selects the remaining array. Capacity must be a whole number of output sample frames. This does not allocate a new array per read.
	End Rem
	Method GetData:Int(data:Byte[], offset:Int = 0, count:Int = -1)
		If Not _handle Then Return -1
		If Not _Range(data, offset, count) Then Return -1
		Return bmx_SDL3_GetAudioStreamData(_handle, data, offset, count)
	End Method

	Method Available:Int()
		If Not _handle Then Return -1
		Return bmx_SDL3_GetAudioStreamAvailable(_handle)
	End Method

	Method Queued:Int()
		If Not _handle Then Return -1
		Return bmx_SDL3_GetAudioStreamQueued(_handle)
	End Method

	Method Clear:Int()
		If Not _handle Then Return False
		Return bmx_SDL3_ClearAudioStream(_handle)
	End Method

	Method Flush:Int()
		If Not _handle Then Return False
		Return bmx_SDL3_FlushAudioStream(_handle)
	End Method

	Method GetGain:Float()
		If Not _handle Then Return -1
		Return bmx_SDL3_GetAudioStreamGain(_handle)
	End Method

	Method GetFrequencyRatio:Float()
		If Not _handle Then Return 0
		Return bmx_SDL3_GetAudioStreamFrequencyRatio(_handle)
	End Method

	Rem
	bbdoc: Controls the device owned by a convenience stream. Use TSDLAudioDevice for independently bound streams.
	End Rem
	Method Pause:Int()
		If Not _handle Or Not _ownsDevice Then Return False
		Return bmx_SDL3_PauseAudioStreamDevice(_handle)
	End Method

	Rem
	bbdoc: Controls the device owned by a convenience stream. Use TSDLAudioDevice for independently bound streams.
	End Rem
	Method Resume:Int()
		If Not _handle Or Not _ownsDevice Then Return False
		Return bmx_SDL3_ResumeAudioStreamDevice(_handle)
	End Method

	Rem
	bbdoc: Controls the device owned by a convenience stream. Use TSDLAudioDevice for independently bound streams.
	End Rem
	Method Paused:Int()
		If Not _handle Or Not _ownsDevice Then Return False
		Return bmx_SDL3_AudioStreamDevicePaused(_handle)
	End Method

	Rem
	bbdoc: Sets nonnegative stream gain; 1 is unchanged.
	End Rem
	Method SetGain:Int(value:Float)
		If Not _handle Then Return False
		Return bmx_SDL3_SetAudioStreamGain(_handle, value)
	End Method

	Rem
	bbdoc: Sets the playback-rate multiplier, from 0.01 to 100. Changes pitch as well as speed.
	End Rem
	Method SetFrequencyRatio:Int(value:Float)
		If Not _handle Then Return False
		Return bmx_SDL3_SetAudioStreamFrequencyRatio(_handle, value)
	End Method

	Private
	Function _Wrap:TSDLAudioStream(handle:Byte Ptr, ownsDevice:Int)
		If Not handle Then Return Null
		Local stream:TSDLAudioStream = New TSDLAudioStream
		stream._handle = handle
		stream._ownsDevice = ownsDevice
		Return stream
	End Function
End Type

Private
Function _InitAudio:Int()
	If SDL_WasInit(SDL_INIT_AUDIO) Then Return True
	Return SDL_InitSubSystem(SDL_INIT_AUDIO)
End Function

Function _Range:Int(data:Byte[], offset:Int, count:Int Var)
	If offset < 0 Or offset > data.length Then Return False
	If count = -1 Then count = data.length - offset
	Return count >= 0 And count <= data.length - offset
End Function

Function _AudioDevices:UInt[](recording:Int)
	If Not _InitAudio() Then Return New UInt[0]
	Local count:Int
	Local ptr:Byte Ptr = bmx_SDL3_AudioDevices(recording, Varptr count)
	Local ids:UInt[] = New UInt[count]
	If count Then MemCopy(ids, ptr, Size_T(count) * 4)
	bmx_SDL3_FreeAudioDevices(ptr)
	Return ids
End Function

Extern
	Function bmx_SDL3_AudioDevices:Byte Ptr(recording:Int, count:Int Ptr)
	Function bmx_SDL3_FreeAudioDevices(ptr:Byte Ptr)
	Function bmx_SDL3_AudioDeviceName:String(id:UInt)
	Function bmx_SDL3_OpenAudioDevice:UInt(id:UInt)
	Function bmx_SDL3_CloseAudioDevice(id:UInt)
	Function bmx_SDL3_BindAudioStream:Int(id:UInt, stream:Byte Ptr)
	Function bmx_SDL3_GetAudioDeviceFormat:Int(id:UInt, spec:SSDLAudioSpec Var, frames:Int Ptr)
	Function bmx_SDL3_CreateAudioStream:Byte Ptr(source:SSDLAudioSpec Var, destination:SSDLAudioSpec Var)
	Function bmx_SDL3_OpenAudioDeviceStream:Byte Ptr(id:UInt, spec:SSDLAudioSpec Var, playback:Int)
	Function bmx_SDL3_DestroyAudioStream(stream:Byte Ptr)
	Function bmx_SDL3_GetAudioStreamDevice:UInt(stream:Byte Ptr)
	Function bmx_SDL3_UnbindAudioStream(stream:Byte Ptr)
	Function bmx_SDL3_GetAudioStreamFormat:Int(stream:Byte Ptr, source:SSDLAudioSpec Var, destination:SSDLAudioSpec Var)
	Function bmx_SDL3_PutAudioStreamData:Int(stream:Byte Ptr, data:Byte Ptr, offset:Int, count:Int)
	Function bmx_SDL3_GetAudioStreamData:Int(stream:Byte Ptr, data:Byte Ptr, offset:Int, count:Int)
	Function bmx_SDL3_PauseAudioDevice:Int(id:UInt)
	Function bmx_SDL3_ResumeAudioDevice:Int(id:UInt)
	Function bmx_SDL3_AudioDevicePaused:Int(id:UInt)
	Function bmx_SDL3_GetAudioDeviceGain:Float(id:UInt)
	Function bmx_SDL3_SetAudioDeviceGain:Int(id:UInt, value:Float)
	Function bmx_SDL3_GetAudioStreamAvailable:Int(stream:Byte Ptr)
	Function bmx_SDL3_GetAudioStreamQueued:Int(stream:Byte Ptr)
	Function bmx_SDL3_ClearAudioStream:Int(stream:Byte Ptr)
	Function bmx_SDL3_FlushAudioStream:Int(stream:Byte Ptr)
	Function bmx_SDL3_GetAudioStreamGain:Float(stream:Byte Ptr)
	Function bmx_SDL3_GetAudioStreamFrequencyRatio:Float(stream:Byte Ptr)
	Function bmx_SDL3_PauseAudioStreamDevice:Int(stream:Byte Ptr)
	Function bmx_SDL3_ResumeAudioStreamDevice:Int(stream:Byte Ptr)
	Function bmx_SDL3_AudioStreamDevicePaused:Int(stream:Byte Ptr)
	Function bmx_SDL3_SetAudioStreamGain:Int(stream:Byte Ptr, value:Float)
	Function bmx_SDL3_SetAudioStreamFrequencyRatio:Int(stream:Byte Ptr, value:Float)
End Extern
