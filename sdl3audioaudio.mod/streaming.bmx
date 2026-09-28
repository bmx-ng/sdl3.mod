SuperStrict

Import Audio.Streams
Import BRL.Threads
Import BRL.LinkedList
Import BRL.System

' Internal helpers for SDL3.SDL3AudioAudio. Resource state lives in objects so
' cleanup remains valid across exceptions in optimized builds.
Global streamingMutex:TMutex = CreateMutex()
Global streamingJobs:TList = New TList
Global streamingLeases:TList = New TList

Type TSDLDecodeSession
	Field stream:TStream
	Field decoder:TAudioStreamDecoder
	Field borrowed:TStream
	Field leased:Int
	Field origin:Long

	Method Open(url:Object, start:Long = -1)
		borrowed = TStream(url)
		streamingMutex.Lock()
		If borrowed And streamingLeases.Contains(borrowed) Then
			streamingMutex.Unlock()
			Throw "This audio stream is already in use"
		End If
		If borrowed Then streamingLeases.AddLast(borrowed)
		leased = True
		streamingMutex.Unlock()
		stream = ReadStream(url)
		If Not stream Then Throw "Unable to open streaming audio source"
		origin = stream.Pos()
		If start >= 0 Then origin = start
		If origin < 0 Or stream.Seek(origin) <> origin Then Throw "Streaming audio requires a seekable source"
		decoder = OpenAudioStreamDecoder(stream)
		If Not decoder Then Throw "No imported streaming decoder recognises this audio source"
		If decoder.hertz <= 0 Or decoder.channels < 1 Or decoder.channels > 2 Or decoder.frames = 0 Then Throw "Unsupported or empty streaming audio"
	End Method

	Method Close:String(restore:Int = False)
		Local errorText:String
		Try
			If decoder Then decoder.Close()
		Catch error:Object
			errorText = error.ToString()
		End Try
		decoder = Null
		Try
			If stream And restore Then
				If stream.Seek(origin) <> origin Then Throw "Unable to restore audio stream position"
			End If
		Catch error:Object
			If Not errorText Then errorText = error.ToString()
		End Try
		Try
			If stream Then stream.Close()
		Catch error:Object
			If Not errorText Then errorText = error.ToString()
		End Try
		stream = Null
		streamingMutex.Lock()
		If leased And borrowed Then streamingLeases.Remove(borrowed)
		leased = False
		streamingMutex.Unlock()
		Return errorText
	End Method
End Type

Type TSDLStreamJob
	Field session:TSDLDecodeSession = New TSDLDecodeSession
	Field channel:Object
	Field handle:Byte Ptr
	Field thread:TThread
	Field loop:Int
	Field buffer:Float[]
	Field mutex:TMutex = CreateMutex()
	Field cancelled:Int
	Field failure:String

	Method Cancel()
		mutex.Lock()
		cancelled = True
		mutex.Unlock()
	End Method

	Method Cancelled:Int()
		mutex.Lock()
		Local value:Int = cancelled
		mutex.Unlock()
		Return value
	End Method

	Method SetError(message:String)
		mutex.Lock()
		If Not failure Then failure = message
		mutex.Unlock()
	End Method

	Method Error:String()
		mutex.Lock()
		Local value:String = failure
		mutex.Unlock()
		Return value
	End Method

	Method Wait()
		If thread Then thread.Wait()
	End Method

	Method Fill:Int(count:Int)
		Local got:Int = session.decoder.ReadFrames(buffer, count)
		If got < 0 Or got > count Then Throw "Invalid streaming decoder frame count"
		If Not got And loop Then
			If Not session.decoder.SeekFrame(0) Then Throw "Streaming decoder cannot loop this source"
			got = session.decoder.ReadFrames(buffer, count)
			If got <= 0 Or got > count Then Throw "Looping audio source produced no frames"
		End If
		If got Then
			If Not bmx_SDL3_AudioStreamingPut(handle, buffer, got, session.decoder.channels) Then Throw "Unable to queue streaming audio"
		End If
		Return got
	End Method

	Function Run:Object(value:Object)
		Local job:TSDLStreamJob = TSDLStreamJob(value)
		Try
			Local ended:Int
			While Not job.Cancelled()
				If ended Then
					If bmx_SDL3_AudioStreamingFinished(job.handle) Then Exit
					Delay 5
					Continue
				End If
				Local space:Int = bmx_SDL3_AudioStreamingSpace(job.handle)
				If space < 0 Then Exit
				If space < 2048 Then
					Delay 5
					Continue
				End If
				If Not job.Fill(2048) Then
					bmx_SDL3_AudioStreamingEnd(job.handle, False)
					ended = True
				End If
			Wend
		Catch error:Object
			If Not job.Cancelled() Then
				job.SetError(error.ToString())
				bmx_SDL3_AudioStreamingEnd(job.handle, True)
			End If
		Finally
			Local closeError:String = job.session.Close()
			If closeError Then job.SetError(closeError)
			streamingMutex.Lock()
			streamingJobs.Remove(job)
			streamingMutex.Unlock()
		End Try
		Return Null
	End Function
End Type

Function StopStreamingJobs()
	streamingMutex.Lock()
	Local jobs:TList = streamingJobs.Copy()
	streamingMutex.Unlock()
	For Local job:TSDLStreamJob = EachIn jobs
		job.Cancel()
	Next
	For Local job:TSDLStreamJob = EachIn jobs
		job.Wait()
	Next
End Function

Extern
	Function bmx_SDL3_AudioStreamingStart:Int(voice:Byte Ptr, freq:Int)
	Function bmx_SDL3_AudioStreamingSpace:Int(voice:Byte Ptr)
	Function bmx_SDL3_AudioStreamingPut:Int(voice:Byte Ptr, data:Float Ptr, frames:Int, channels:Int)
	Function bmx_SDL3_AudioStreamingEnd(voice:Byte Ptr, failure:Int)
	Function bmx_SDL3_AudioStreamingFinished:Int(voice:Byte Ptr)
	Function bmx_SDL3_AudioStreamingError(message:String)
End Extern
