SuperStrict

Import "glue.c"
?macos
Import "macos_glue.m"
?

Extern
	Function bmx_SDL3_SystemShutdown()
	Function bmx_SDL3_Poll()
	Function bmx_SDL3_WaitEvent()
	Function bmx_SDL3_AddEventObserver(callback:Byte Ptr, userdata:Byte Ptr)
	Function bmx_SDL3_RemoveEventObserver(callback:Byte Ptr)
	Function bmx_SDL3_SetLifecycleWatch:Int(driver:Object)
	Function bmx_SDL3_RegisterCallbacks()
	Function bmx_SDL3_SetMouseVisible(visible:Int)
	Function bmx_SDL3_OpenURL:Int(url:String)
	Function bmx_SDL3_GetDisplayWidth:Int(display:Int)
	Function bmx_SDL3_GetDisplayHeight:Int(display:Int)
	Function bmx_SDL3_GetDisplayDepth:Int(display:Int)
	Function bmx_SDL3_GetDisplayHertz:Int(display:Int)
	Function bmx_SDL3_ShowSimpleMessageBox:Int(text:String, title:String, serious:Int)
	Function bmx_SDL3_ShowMessageBoxConfirm:Int(text:String, title:String, serious:Int)
	Function bmx_SDL3_ShowMessageBoxProceed:Int(text:String, title:String, serious:Int)
End Extern
