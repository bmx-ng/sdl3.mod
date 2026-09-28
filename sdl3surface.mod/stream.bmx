SuperStrict

Import BRL.Stream
Import "stream.c"

Type TSDLBMPStream
	Field stream:TStream
	Field error:Object
End Type

Private

Function _StreamSize:Long(context:TSDLBMPStream)
	If context.error Then Return -1
	Try
		Return context.stream.Size()
	Catch error:Object
		context.error = error
	End Try
	Return -1
End Function

Function _StreamSeek:Long(context:TSDLBMPStream, offset:Long, whence:Int)
	If context.error Then Return -1
	Try
		Local base:Long
		Select whence
			Case 0
			Case 1
				base = context.stream.Pos()
			Case 2
				base = context.stream.Size()
			Default
				Return -1
		End Select
		If base < 0 Then Return -1
		If offset > 0 And base > $7FFFFFFFFFFFFFFF:Long - offset Then Return -1
		If offset < -base Then Return -1
		Local target:Long = base + offset
		Local actual:Long = context.stream.Seek(target)
		If actual <> target Then Return -1
		Return actual
	Catch error:Object
		context.error = error
	End Try
	Return -1
End Function

Function _StreamTransfer:Long(context:TSDLBMPStream, buffer:Byte Ptr, count:Long, writing:Int)
	If context.error Then Return -1
	Try
		Local done:Long
		While done < count
			Local amount:Long
			If writing Then
				amount = context.stream.Write(buffer + done, count - done)
			Else
				amount = context.stream.Read(buffer + done, count - done)
			End If
			If amount < 0 Or amount > count - done Then Throw "Invalid stream transfer count"
			If amount = 0 Then Exit
			done :+ amount
		Wend
		Return done
	Catch error:Object
		context.error = error
	End Try
	Return -1
End Function
Public
