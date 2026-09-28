SuperStrict

Module SDL3.SDL3Timer
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3System
Import BRL.Timer
Import BRL.Map
Import "glue.c"

Private
Global _timers:TMap = New TMap

Extern
	Function bmx_SDL3_TimerInit:Int()
	Function bmx_SDL3_TimerStart:UInt(hertz:Float)
	Function bmx_SDL3_TimerStop:Int(id:UInt)
End Extern

Function _TimerFired(id:UInt)
	Local timer:TSDLTimer = TSDLTimer(_timers.ValueForKey(String(id)))
	If timer Then
		Try
			timer.Fire()
		Catch error:Object
			TSDLSystemDriver(SystemDriver())._DeferCallbackError(error)
		End Try
	End If
End Function

Public
Type TSDLTimer Extends TTimer
	Field _id:UInt
	Field _ticks:Int
	Field _waitTicks:Int
	Field _event:TEvent

	Method Ticks:Int() Override
		Return _ticks
	End Method

	Method Stop() Override
		If Not _id Then Return
		_timers.Remove(String(_id))
		bmx_SDL3_TimerStop(_id)
		_id = 0
		_event = Null
	End Method

	Method Fire() Override
		If Not _id Then Return
		_ticks :+ 1
		If _event Then
			EmitEvent(_event)
		Else
			EmitEvent(CreateEvent(EVENT_TIMERTICK, Self, _ticks))
		End If
	End Method

	Method Wait:Int() Override
		If Not _id Then Return 0
		Local count:Int
		Repeat
			WaitSystem()
			count = _ticks - _waitTicks
		Until count Or Not _id
		_waitTicks :+ count
		Return count
	End Method

	Function Create:TTimer(hertz:Float, event:TEvent = Null) Override
		Local timer:TSDLTimer = New TSDLTimer
		timer._event = event
		timer._id = bmx_SDL3_TimerStart(hertz)
		If Not timer._id Then Return Null
		_timers.Insert(String(timer._id), timer)
		Return timer
	End Function
End Type

Type TSDLTimerFactory Extends TTimerFactory
	Method GetName:String() Override
		Return "SDL3Timer"
	End Method
	Method Create:TTimer(hertz:Float, event:TEvent = Null) Override
		Return TSDLTimer.Create(hertz, event)
	End Method
End Type

If Not bmx_SDL3_TimerInit() Then Throw "SDL3 timer event init failed: " + SDL_GetError()
New TSDLTimerFactory
