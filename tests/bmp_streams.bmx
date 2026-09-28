SuperStrict

Framework SDL3.SDL3Surface
Import BRL.BankStream
Import BRL.StandardIO
Import "test_helpers.bmx"

Type TProbeStream Extends TBankStream
	Field closed:Int
	Field failRead:Int
	Field stallWrite:Int
	Field failWrite:Int
	Field failSeek:Int
	Field failFlush:Int
	Field noSeek:Int
	Field collect:Int
	Method Read:Long(buf:Byte Ptr, count:Long) Override
		If failRead Then Throw "read failed"
		If collect Then
			collect = False
			GCCollect()
		End If
		If count > 3 Then count = 3
		Return Super.Read(buf, count)
	End Method
	Method Write:Long(buf:Byte Ptr, count:Long) Override
		If failWrite Then Throw "write failed"
		If stallWrite Then Return 0
		If count > 3 Then count = 3
		Return Super.Write(buf, count)
	End Method
	Method Seek:Long(pos:Long, whence:Int = SEEK_SET_) Override
		If failSeek Then Throw "seek failed"
		If noSeek Then Return -1
		Return Super.Seek(pos, whence)
	End Method
	Method Flush() Override
		If failFlush Then Throw "flush failed"
	End Method
	Method Close() Override
		closed :+ 1
	End Method
End Type

Function Probe:TProbeStream()
	Local value:TProbeStream = New TProbeStream
	value._bank = CreateBank(0)
	Return value
End Function

Global virtualStream:TProbeStream
Type TBMPFactory Extends TStreamFactory
	Method CreateStream:TStream(url:Object, proto:String, path:String, readable:Int, writeMode:Int) Override
		If proto = "sdl3bmptest" Then Return virtualStream
	End Method
End Type
New TBMPFactory

Local surface:TSDLSurface = TSDLSurface.Create(4, 3)
Check surface
Check surface.Fill(30, 80, 140, 255)
Local stream:TProbeStream = Probe()
stream.WriteString("prefix")
Local start:Long = stream.Pos()
Check surface.SaveBMP(stream), SDL_GetError()
Check stream.closed = 0, "Caller stream closed after save"
Local finish:Long = stream.Pos()
Check finish > start
stream.Seek(start)
stream.collect = True
Local loaded:TSDLSurface = TSDLSurface.LoadBMP(stream)
Check loaded, SDL_GetError()
Check stream.closed = 0, "Caller stream closed after load"
Check loaded.Width() = 4 And loaded.Height() = 3
Local red:Int, green:Int, blue:Int, alpha:Int
Check loaded.ReadPixel(0, 0, red, green, blue, alpha)
Check red = 30 And green = 80 And blue = 140 And alpha = 255
loaded.Destroy()
stream.Seek(0)
Check stream.ReadString(6) = "prefix", "BMP overwrote stream prefix"

virtualStream = Probe()
Check surface.SaveBMP("sdl3bmptest::image")
Check virtualStream.closed = 1, "Owned output not closed"
virtualStream.Seek(0)
loaded = TSDLSurface.LoadBMP("sdl3bmptest::image")
Check loaded
Check virtualStream.closed = 2, "Owned input not closed"
loaded.Destroy()

For Local mode:Int = 1 To 4
	Local failing:TProbeStream = Probe()
	If mode = 1 Then failing.failRead = True
	If mode = 2 Then failing.failWrite = True
	If mode = 3 Then failing.failSeek = True
	If mode = 4 Then failing.failFlush = True
	Local caught:Int
	Try
		If mode = 1 Then
			TSDLSurface.LoadBMP(failing)
		Else
			surface.SaveBMP(failing)
		End If
	Catch error:Object
		Local expected:String[] = ["", "read failed", "write failed", "seek failed", "flush failed"]
		caught = String(error) = expected[mode]
	End Try
	Check caught, "Stream exception not preserved: " + mode
	Check failing.closed = 0, "Failed caller stream closed"
Next
virtualStream = Probe()
virtualStream.failWrite = True
Local caught:Int
Try
	surface.SaveBMP("sdl3bmptest::broken")
Catch error:Object
	caught = String(error) = "write failed"
End Try
Check caught And virtualStream.closed = 1, "Owned stream not closed on exception"
Local forward:TProbeStream = Probe()
forward.noSeek = True
Check Not TSDLSurface.LoadBMP(forward), "Non-seekable input accepted"
Check Not surface.SaveBMP(forward), "Non-seekable output accepted"
Check forward.closed = 0
Local stalled:TProbeStream = Probe()
stalled.stallWrite = True
Check Not surface.SaveBMP(stalled), "Zero-progress write accepted"
Check stalled.closed = 0
Local truncated:TProbeStream = Probe()
truncated.WriteString("BM")
truncated.Seek(0)
Check Not TSDLSurface.LoadBMP(truncated), "Truncated BMP accepted"
Check truncated.closed = 0
surface.Destroy()
Check Not surface.SaveBMP(stream)
Print "SDL3 BMP stream tests passed"
