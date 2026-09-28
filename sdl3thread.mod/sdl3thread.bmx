SuperStrict

Module SDL3.SDL3Thread
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3
Import "glue.c"

Type TSDLThread
	Field _handle:Byte Ptr
	Field _entry:Object(data:Object)
	Field _data:Object
	Field _result:Object
	Field _error:Object
	Field _detached:Int

	Function Create:TSDLThread(entry:Object(data:Object), data:Object = Null, name:String = "")
		If Not entry Then Return Null
		Local thread:TSDLThread = New TSDLThread
		thread._entry = entry
		thread._data = data
		thread._handle = bmx_SDL3_CreateManagedThread(thread, name)
		If Not thread._handle Then Return Null
		Return thread
	End Function

	Method Wait:Object()
		If _detached Then Throw "Cannot wait for a detached SDL3 thread"
		If _handle Then
			bmx_SDL3_WaitThread(_handle)
			_handle = Null
		End If
		If _error Then Throw _error
		Return _result
	End Method

	Method Detach()
		If Not _handle Then Return
		bmx_SDL3_DetachThread(_handle)
		_handle = Null
		_detached = True
	End Method

	Method Delete()
		Detach()
	End Method
End Type

Private
Function _RunManagedThread:Int(value:Object)
	Local thread:TSDLThread = TSDLThread(value)
	Try
		thread._result = thread._entry(thread._data)
	Catch error:Object
		thread._error = error
	End Try
	Return 0
End Function
Public

Extern
	Function bmx_SDL3_CreateManagedThread:Byte Ptr(thread:Object, name:String)
	Function bmx_SDL3_WaitThread(handle:Byte Ptr)
	Function bmx_SDL3_DetachThread(handle:Byte Ptr)
End Extern
