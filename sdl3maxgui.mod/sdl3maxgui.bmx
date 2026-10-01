SuperStrict

Rem
bbdoc: Hosts SDL3 rendering in macOS, Windows and Linux/X11 MaxGUI canvases.
about: Import alongside Max2D.SDL3RenderMax2D or Max2D.SDL3GPUMax2D. MaxGUI owns input, windows and the event loop.
SDL service events are drained after native polling, with wakeups for SDL timer and lifecycle events.
Close attached graphics before freeing its gadget. Standalone SDL windows and ImGui input
inside attached canvases are not supported by this initial bridge.
End Rem
Module SDL3.SDL3MaxGUI

ModuleInfo "Version: 0.04"
ModuleInfo "License: zlib/libpng"
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

?macos Or win32 Or linux
Import BRL.SystemDefault
Import MaxGUI.Drivers
Import SDL3.SDL3Graphics
?macos
Import "glue.m"
?win32
Import "glue_win32.c"
?linux
Import "glue_linux.c"
Import "-lX11"
?macos Or win32 Or linux

Private
Extern
	Function bmx_SDL3_SetHostedEvents(enabled:Int)
	Function bmx_SDL3_DrainHostedEvents()
	Function bmx_SDL3_GUIStart:Int()
	Function bmx_SDL3_GUIStop()
	Function bmx_SDL3_GUIResetWake()
	Function bmx_SDL3_GUIAttach:Byte Ptr(widget:Byte Ptr)
	Function bmx_SDL3_GUIRenderer:Byte Ptr(window:Byte Ptr)
	Function bmx_SDL3_GUIClaimGPU:Int(device:Byte Ptr,window:Byte Ptr)
	Function bmx_SDL3_GUISize(window:Byte Ptr,width:Int Var,height:Int Var,pixels:Int)
End Extern

Function Drain:Object(id:Int,data:Object,context:Object)
	Local driver:TSDLSystemDriver=SDLSystemDriver()
	driver._RaiseCallbackError()
	bmx_SDL3_GUIResetWake()
	bmx_SDL3_DrainHostedEvents()
	driver._RaiseCallbackError()
	Return data
End Function

Function CreateRenderer:TSDLRenderer(window:TSDLWindow)
	Local ptr:Byte Ptr=bmx_SDL3_GUIRenderer(window.windowPtr)
	If Not ptr Then Return Null
	Local renderer:TSDLRenderer=New TSDLRenderer
	renderer.rendererPtr=ptr
	renderer._window=window
	Return renderer
End Function

Function Shutdown()
	RemoveHook PollSystemHook,Drain
	bmx_SDL3_GUIStop()
End Function

If Not bmx_SDL3_GUIStart() Then Throw "SDL3 MaxGUI: "+SDL_GetError()
SDLAttachWindow=bmx_SDL3_GUIAttach
SDLAttachedSize=bmx_SDL3_GUISize
SDLAttachRenderer=CreateRenderer
SDLAttachGPUClaim=bmx_SDL3_GUIClaimGPU
AddHook PollSystemHook,Drain
OnEnd(Shutdown)
?
