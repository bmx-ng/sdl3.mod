SuperStrict

Framework SDL3.SDL3Audio
Import BRL.StandardIO
Import BRL.System
Import "test_helpers.bmx"

Local source:SSDLAudioSpec = New SSDLAudioSpec(SDL_AUDIO_U8, 1, 48000)
Local destination:SSDLAudioSpec = New SSDLAudioSpec(SDL_AUDIO_F32, 1, 48000)
Local stream:TSDLAudioStream = TSDLAudioStream.Create(source, destination)
Check stream, SDL_GetError()
Local input:Byte[] = [0:Byte, 128:Byte, 255:Byte]
Check stream.PutData(input)
input[0] = 128
Check stream.Queued() = 3, "Queued count should describe input bytes"
Check stream.Flush()
Local output:Byte[20]
Check stream.GetData(output, 4, 12) = 12
Local samples:Float Ptr = Float Ptr(Varptr output[4])
Check Abs(samples[0] + 1) < 0.0001, "PutData did not copy input or U8 conversion failed"
Check Abs(samples[1]) < 0.0001
Check Abs(samples[2] - 127.0 / 128.0) < 0.0001
Check output[0] = 0 And output[19] = 0, "Output slice overrun"
Check stream.Available() = 0
Check Not stream.PutData(input, -1)
Check Not stream.PutData(input, 0, 4)
Check stream.GetData(output, 0, 3) = -1, "Partial output frame accepted"
Check stream.GetData(output, 21) = -1
Check stream.PutData(New Byte[0])
Check stream.SetGain(0.5) And Abs(stream.GetGain() - 0.5) < 0.001
Check stream.SetFrequencyRatio(2) And Abs(stream.GetFrequencyRatio() - 2) < 0.001
Check Not stream.SetFrequencyRatio(0)
Check Not stream.Resume(), "Independent converter should not control a device"
Local actualSource:SSDLAudioSpec, actualDestination:SSDLAudioSpec
Check stream.GetFormat(actualSource, actualDestination)
Check actualSource.format = source.format And actualDestination.format = destination.format
Check stream.PutData(input) And stream.Clear()
Check stream.Queued() = 0 And stream.Available() = 0
stream.Close()
stream.Close()
Check Not stream.IsValid() And Not stream.PutData(input)
Check stream.GetData(output) = -1
Check Not stream.GetFormat(actualSource, actualDestination)
Check actualSource.freq = 0 And actualDestination.freq = 0

Local scope:TSDLAudioStream = TSDLAudioStream.Create(source, destination)
Try
	Using
		Local value:TSDLAudioStream = scope
	Do
		Throw "scope test"
	End Using
Catch error:String
	Check error = "scope test"
End Try
Check Not scope.IsValid(), "Using did not close after exception"

' This test must be launched with SDL_AUDIODRIVER=dummy.
Check SDL_Init(SDL_INIT_AUDIO), SDL_GetError()
Check CurrentAudioDriver() = "dummy", "Run with SDL_AUDIODRIVER=dummy; no real devices should be opened"
Local devices:UInt[] = SDLAudioPlaybackDevices()
Check devices.length > 0
Check SDLAudioDeviceName(devices[0]).length > 0
Check SDLAudioRecordingDevices().length > 0
Local playback:TSDLAudioStream = TSDLAudioStream.OpenPlayback(source)
Check playback, SDL_GetError()
Check playback.Paused()
Check playback.PutData(New Byte[4800]) And playback.Flush()
Check playback.Resume() And Not playback.Paused()
Local deadline:Int = MilliSecs() + 3000
While playback.Queued() And MilliSecs() < deadline
	Delay 10
Wend
Check playback.Queued() = 0, "Dummy playback did not consume input"
Check playback.Pause() And playback.Paused()
playback.Close()
Check playback.DeviceID() = 0
Check Not TSDLAudioStream.OpenPlayback(source, SDL_AUDIO_DEVICE_DEFAULT_RECORDING)

Local device:TSDLAudioDevice = TSDLAudioDevice.Open()
Check device And device.Pause()
Local frames:Int
Check device.GetFormat(actualSource, frames) And frames > 0
stream = TSDLAudioStream.Create(source, destination)
Check stream And device.Bind(stream)
Check stream.DeviceID() = device.ID()
device.Close()
Check stream.IsValid() And stream.DeviceID() = 0, "Closing device should unbind, not destroy stream"
Check stream.PutData(input) And stream.Flush()
Check stream.GetData(output, 0, 12) = 12
stream.Close()
device.Close()

Local recording:TSDLAudioStream = TSDLAudioStream.OpenRecording(destination)
Check recording And recording.Paused()
Check recording.Resume()
deadline = MilliSecs() + 3000
While recording.Available() < 16 And MilliSecs() < deadline
	Delay 10
Wend
Check recording.Pause()
Check recording.GetData(output, 0, 16) = 16, "Dummy recording did not deliver data"
samples = Float Ptr(output)
For Local i:Int = 0 Until 4
	Check samples[i] = 0, "Dummy recording should be silent"
Next
recording.Close()
SDL_Quit()
Print "SDL3 audio stream tests passed"

Private
Function CurrentAudioDriver:String()
	Local name:Byte Ptr = SDL_GetCurrentAudioDriver()
	If name Then Return String.FromCString(name)
	Return ""
End Function
Extern "C"
	Function SDL_GetCurrentAudioDriver:Byte Ptr()
End Extern
