SuperStrict

Module SDL3.SDL3Surface
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3Rect
Import BRL.Stream
Import "stream.bmx"
Import "glue.c"

Rem
bbdoc: An owned SDL3 software surface.
End Rem
Type TSDLSurface
	Field surfacePtr:Byte Ptr

	Function _create:TSDLSurface(ptr:Byte Ptr)
		If Not ptr Then Return Null
		Local surface:TSDLSurface = New TSDLSurface
		surface.surfacePtr = ptr
		Return surface
	End Function

	Rem
	bbdoc: Creates a surface. Format 0 selects SDL's native RGBA32 byte order.
	End Rem
	Function Create:TSDLSurface(width:Int, height:Int, format:UInt = 0)
		Return _create(bmx_SDL3_CreateSurface(width, height, format))
	End Function

	Rem
	bbdoc: Loads BMP data from a filename, stream URL or TStream at its current position.
	about: Uses BRL.Stream and its BRL.IO integration. The stream must support seeking. Caller streams remain open; internally opened streams are closed. Returns Null for SDL decode/open failures. Stream exceptions are rethrown after native cleanup. Failure may change the stream position.
	End Rem
	Function LoadBMP:TSDLSurface(url:Object)
		Local stream:TStream = ReadStream(url)
		If Not stream Then
			bmx_SDL3_BMPStreamOpenError()
			Return Null
		End If
		Local context:TSDLBMPStream = New TSDLBMPStream
		context.stream = stream
		Local ptr:Byte Ptr = bmx_SDL3_LoadBMPStream(context)
		Try
			stream.Close()
		Catch error:Object
			If ptr Then bmx_SDL3_DestroySurface(ptr)
			If context.error Then Throw context.error
			Throw error
		End Try
		If context.error Then
			If ptr Then bmx_SDL3_DestroySurface(ptr)
			Throw context.error
		End If
		Return _create(ptr)
	End Function

	Rem
	bbdoc: Saves BMP data to a filename, stream URL or TStream at its current position.
	about: The output must be seekable. Caller streams remain open and are flushed on success; internally opened streams are closed. Returns False on SDL failure. Stream exceptions are rethrown after cleanup. A failed write can leave partial output; no rollback or truncation of caller streams is performed.
	End Rem
	Method SaveBMP:Int(url:Object)
		If Not surfacePtr Then
			bmx_SDL3_BMPInvalidSurface()
			Return False
		End If
		Local stream:TStream = WriteStream(url)
		If Not stream Then
			bmx_SDL3_BMPStreamOpenError()
			Return False
		End If
		Local context:TSDLBMPStream = New TSDLBMPStream
		context.stream = stream
		Local result:Int = bmx_SDL3_SaveBMPStream(surfacePtr, context)
		Try
			If result Then stream.Flush()
		Catch error:Object
			context.error = error
		End Try
		Try
			stream.Close()
		Catch error:Object
			If Not context.error Then context.error = error
		End Try
		If context.error Then Throw context.error
		Return result
	End Method

	Method Width:Int()
		Return bmx_SDL3_SurfaceWidth(surfacePtr)
	End Method

	Method Height:Int()
		Return bmx_SDL3_SurfaceHeight(surfacePtr)
	End Method

	Method Format:UInt()
		Return bmx_SDL3_SurfaceFormat(surfacePtr)
	End Method

	Method Fill:Int(red:Int, green:Int, blue:Int, alpha:Int = 255)
		Return bmx_SDL3_FillSurface(surfacePtr, red, green, blue, alpha)
	End Method

	Method FillRect:Int(rect:SSDLRect Var, red:Int, green:Int, blue:Int, alpha:Int = 255)
		Return bmx_SDL3_FillSurfaceRect(surfacePtr, rect, red, green, blue, alpha)
	End Method

	Method ReadPixel:Int(x:Int, y:Int, red:Int Var, green:Int Var, blue:Int Var, alpha:Int Var)
		Return bmx_SDL3_ReadSurfacePixel(surfacePtr, x, y, Varptr red, Varptr green, Varptr blue, Varptr alpha)
	End Method

	Method Destroy()
		If surfacePtr Then
			bmx_SDL3_DestroySurface(surfacePtr)
			surfacePtr = Null
		End If
	End Method
End Type

Extern
	Function bmx_SDL3_CreateSurface:Byte Ptr(width:Int, height:Int, format:UInt)
	Function bmx_SDL3_LoadBMPStream:Byte Ptr(context:Object)
	Function bmx_SDL3_SaveBMPStream:Int(surface:Byte Ptr, context:Object)
	Function bmx_SDL3_BMPStreamOpenError()
	Function bmx_SDL3_BMPInvalidSurface()
	Function bmx_SDL3_SurfaceWidth:Int(surface:Byte Ptr)
	Function bmx_SDL3_SurfaceHeight:Int(surface:Byte Ptr)
	Function bmx_SDL3_SurfaceFormat:UInt(surface:Byte Ptr)
	Function bmx_SDL3_FillSurface:Int(surface:Byte Ptr, red:Int, green:Int, blue:Int, alpha:Int)
	Function bmx_SDL3_FillSurfaceRect:Int(surface:Byte Ptr, rect:SSDLRect Var, red:Int, green:Int, blue:Int, alpha:Int)
	Function bmx_SDL3_ReadSurfacePixel:Int(surface:Byte Ptr, x:Int, y:Int, red:Int Ptr, green:Int Ptr, blue:Int Ptr, alpha:Int Ptr)
	Function bmx_SDL3_DestroySurface(surface:Byte Ptr)
End Extern
