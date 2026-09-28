SuperStrict

Module SDL3.SDL3System

ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3
Import BRL.System
Import BRL.Event
?Not haiku And Not ios
Import Pub.NFD
?
Import BRL.StringBuilder

Import "common.bmx"
Include "input.bmx"

Const SDL_EVENT_TERMINATING:Int = $101
Const SDL_EVENT_LOW_MEMORY:Int = $102
Const SDL_EVENT_WILL_ENTER_BACKGROUND:Int = $103
Const SDL_EVENT_DID_ENTER_BACKGROUND:Int = $104
Const SDL_EVENT_WILL_ENTER_FOREGROUND:Int = $105
Const SDL_EVENT_DID_ENTER_FOREGROUND:Int = $106

Rem
bbdoc: An IME composition update. The event's extra field is a TSDLTextEditingEvent.
about: Composition is provisional text, separate from committed EVENT_KEYCHAR events. An empty text clears the displayed composition. Keyboard capture by a native observer suppresses this event too.
End Rem
Global EVENT_SDL3_TEXT_EDITING:Int = AllocUserEventId("SDL3 text editing")

Rem
bbdoc: A copied SDL IME composition payload, safe to retain after event dispatch.
about: windowID identifies the SDL window. start and length preserve SDL's selection offsets, including -1 when unspecified; do not assume they are BlitzMax UTF-16 string indices. The original SDL event's text buffer is never retained.
End Rem
Type TSDLTextEditingEvent
	Field windowID:UInt
	Field text:String
	Field start:Int
	Field length:Int
End Type

Private
Function _TextEditing(windowID:UInt, text:String, start:Int, length:Int)
	Local editing:TSDLTextEditingEvent = New TSDLTextEditingEvent
	editing.windowID = windowID
	editing.text = text
	editing.start = start
	editing.length = length
	EmitEvent(CreateEvent(EVENT_SDL3_TEXT_EDITING, Null, Int(windowID), 0, 0, 0, editing))
End Function
Public

' Set by a video backend with an active SDL window, as in SDL2.SDLSystem.
Global _sdl_WarpMouse(x:Int, y:Int)

Type TSDLSystemDriver Extends TSystemDriver
	Field _lifecycleCallback(data:Object, event:Int)
	Field _eventFilterUserData:Object
	Field _callbackError:Object

	Method New()
		If Not SDL_Init(SDL_INIT_EVENTS) Then Throw "SDL3 events init failed: " + SDL_GetError()
		If Not bmx_SDL3_SetLifecycleWatch(Self) Then Throw "SDL3 lifecycle watch failed: " + SDL_GetError()
?macos
		bmx_SDL3_RegisterCallbacks()
?
		OnEnd(bmx_SDL3_SystemShutdown)
	End Method

	Method Name:String() Override
		Return "SDL3SystemDriver"
	End Method

	Method Poll() Override
		_RaiseCallbackError()
		bmx_SDL3_Poll()
		_RaiseCallbackError()
	End Method

	Method Wait() Override
		_RaiseCallbackError()
		bmx_SDL3_WaitEvent()
		_RaiseCallbackError()
	End Method

	Method SetMouseVisible(visible:Int) Override
		bmx_SDL3_SetMouseVisible(visible)
	End Method

	Method MoveMouse(x:Int, y:Int) Override
		If _sdl_WarpMouse Then _sdl_WarpMouse(x, y)
	End Method

	Method Notify(text:String, serious:Int) Override
		If bmx_SDL3_ShowSimpleMessageBox(text, AppTitle, serious) Then WriteStdout text + "~n"
	End Method

	Method Confirm:Int(text:String, serious:Int) Override
		Return bmx_SDL3_ShowMessageBoxConfirm(text, AppTitle, serious)
	End Method

	Method Proceed:Int(text:String, serious:Int) Override
		Return bmx_SDL3_ShowMessageBoxProceed(text, AppTitle, serious)
	End Method

	Method RequestFile:String(text:String, exts:String, save:Int, file:String) Override
?Not haiku And Not ios
		Local defaultPath:Byte Ptr
		Local filterList:Byte Ptr
		Local outPath:Byte Ptr
		Local result:String
		If file Then defaultPath = file.ToUTF8String()
		If exts Then
			Local sb:TStringBuilder = New TStringBuilder
			For Local group:String = EachIn exts.Split(";")
				Local pos:Int = group.Find(":")
				Local ext:String = group
				If pos >= 0 Then ext = group[pos + 1..]
				If ext <> "*" Then
					If sb.Length() Then sb.Append(";")
					sb.Append(ext)
				End If
			Next
			filterList = sb.ToString().ToUTF8String()
		End If
		Local status:Int
		If save Then
			status = NFD_SaveDialog(filterList, defaultPath, Varptr outPath)
		Else
			status = NFD_OpenDialog(filterList, defaultPath, Varptr outPath)
		End If
		If status = 1 And outPath Then
			result = String.FromUTF8String(outPath)
			free_(outPath)
		End If
		If defaultPath Then MemFree(defaultPath)
		If filterList Then MemFree(filterList)
		Return result
?
	End Method

	Method RequestDir:String(text:String, path:String) Override
?Not haiku And Not ios
		Local defaultPath:Byte Ptr
		Local outPath:Byte Ptr
		Local result:String
		If path Then defaultPath = path.ToUTF8String()
		If NFD_PickFolder(defaultPath, Varptr outPath) = 1 And outPath Then
			result = String.FromUTF8String(outPath)
			free_(outPath)
		End If
		If defaultPath Then MemFree(defaultPath)
		Return result
?
	End Method

	Method OpenURL:Int(url:String) Override
		Return bmx_SDL3_OpenURL(url)
	End Method

	Method DesktopWidth:Int(display:Int) Override
		Return bmx_SDL3_GetDisplayWidth(display)
	End Method
	Method DesktopHeight:Int(display:Int) Override
		Return bmx_SDL3_GetDisplayHeight(display)
	End Method
	Method DesktopDepth:Int(display:Int) Override
		Return bmx_SDL3_GetDisplayDepth(display)
	End Method
	Method DesktopHertz:Int(display:Int) Override
		Return bmx_SDL3_GetDisplayHertz(display)
	End Method

	' Internal main-thread handoff: never unwind through native callback frames.
	Method _DeferCallbackError(error:Object)
		If Not _callbackError Then _callbackError = error
	End Method

	Method _RaiseCallbackError()
		Local error:Object = _callbackError
		_callbackError = Null
		If error Then Throw error
	End Method

	Function _eventFilter:Int(driver:TSDLSystemDriver, event:Int) { nomangle }
		Try
			If driver._lifecycleCallback Then driver._lifecycleCallback(driver._eventFilterUserData, event)
		Catch error:Object
			driver._DeferCallbackError(error)
		End Try
		Return True
	End Function
End Type

Rem
bbdoc: Registers a callback for SDL3 application lifecycle events.
about: SDL3 requires these events to be observed with an event watch. Callbacks from the BlitzMax main thread run immediately; callbacks from other threads are delivered during the next PollSystem or WaitSystem. Exceptions are caught at the native callback boundary; the first pending exception is rethrown by PollSystem or WaitSystem after native dispatch returns. Callbacks must not call PollSystem or WaitSystem recursively.
End Rem
Function SetLifecycleCallback(callback(data:Object, event:Int), data:Object = Null)
	Local driver:TSDLSystemDriver = TSDLSystemDriver(SystemDriver())
	driver._lifecycleCallback = callback
	driver._eventFilterUserData = data
End Function

InitSystemDriver(New TSDLSystemDriver)

Private
Extern
?Not haiku And Not ios
	Function NFD_OpenDialog:Int(filterList:Byte Ptr, defaultPath:Byte Ptr, outPath:Byte Ptr Ptr)
	Function NFD_SaveDialog:Int(filterList:Byte Ptr, defaultPath:Byte Ptr, outPath:Byte Ptr Ptr)
	Function NFD_PickFolder:Int(defaultPath:Byte Ptr, outPath:Byte Ptr Ptr)
	Function free_(buf:Byte Ptr) = "void free(void *)!"
?
End Extern
