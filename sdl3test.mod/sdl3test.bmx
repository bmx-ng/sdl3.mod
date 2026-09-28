SuperStrict

Module SDL3.SDL3Test
ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3System
Import "system_events_probe.c"

Extern
	Function probeVideoBackendMask:Int()
	Function probePushController:Int(gamepad:Int)
	Function probePushInput:Int(kind:Int, windowID:UInt, amount:Float = 0)
	Function probeCaptureAllMouse(enabled:Int)
	Function probeIsDummyVideo:Int()
	Function probePushEditing:Int(windowID:UInt, empty:Int)
	Function probeCaptureEditing(enabled:Int)
	Function probeQueueOpenFile:Int()
	Function probeRejectDrops(enabled:Int)
	Function probePushText:Int()
	Function probeInstall()
	Function probeRemove()
	Function probePushKey:Int()
	Function probePushMouse:Int()
	Function probePushQuit:Int()
	Function probePushLifecycle:Int()
	Function probePushLifecycleFromThread:Int()
	Function probeCallCount:Int(index:Int)
	Function probeSetMouseCapture(enabled:Int)
	Function probeInstallSelfRemoving()
	Function probeSelfCallCount:Int()
End Extern
