SuperStrict

Module SDL3.SDL3

ModuleInfo "Version: 0.1"
ModuleInfo "License: zlib/libpng"

' SDL's bool is converted to Int by glue.c at the BlitzMax boundary.
ModuleInfo "CC_OPTS: -I%PWD%/SDL3/include -I%PWD%/SDL3/include/build_config -DSDL_dynapi_h_ -DSDL_DYNAMIC_API=0"

?linux And Not android
ModuleInfo "CC_OPTS: -include %PWD%/include/linux/SDL_build_config.h -DSDL_STATIC_LIB -DUSING_GENERATED_CONFIG_H -D_REENTRANT -fno-strict-aliasing"
ModuleInfo "CC_OPTS: -I%PWD%/SDL3/src -I%PWD%/wayland-generated-protocols -idirafter %PWD%/SDL3/src/video/khronos"
ModuleInfo "CC_OPTS: `pkg-config --cflags dbus-1 egl gl alsa libpulse libudev`"
?linux And Not android And sdl3_x11
ModuleInfo "CC_OPTS: `pkg-config --cflags fribidi libthai x11 xext xcursor xi xfixes xrandr xscrnsaver xtst`"
?linux And Not android And sdl3_wayland
ModuleInfo "CC_OPTS: `pkg-config --cflags libdecor-0 xkbcommon wayland-client wayland-cursor wayland-egl`"
?linux And Not android And sdl3_kmsdrm
ModuleInfo "CC_OPTS: `pkg-config --cflags libdrm gbm`"
?macos
ModuleInfo "CC_OPTS: -fobjc-arc"
Import "-framework AppKit"
Import "-framework AVFoundation"
Import "-framework AudioToolbox"
Import "-framework CoreAudio"
Import "-framework CoreHaptics"
Import "-framework CoreMedia"
Import "-framework CoreVideo"
Import "-framework ForceFeedback"
Import "-framework GameController"
Import "-framework IOKit"
Import "-framework Metal"
Import "-framework QuartzCore"
Import "-framework UniformTypeIdentifiers"
?android
ModuleInfo "CC_OPTS: -I%PWD%/SDL3/src -idirafter %PWD%/SDL3/src/video/khronos -DGL_GLEXT_PROTOTYPES -fno-strict-aliasing"
Import "-lOpenSLES"
?win32
Import "-lkernel32"
Import "-luser32"
Import "-lgdi32"
Import "-lwinmm"
Import "-limm32"
Import "-lole32"
Import "-loleaut32"
Import "-lversion"
Import "-luuid"
Import "-ladvapi32"
Import "-lsetupapi"
Import "-lshell32"
Import "-ldinput8"
?

Import "common.bmx"
Import "glue.c"

Const SDL_INIT_AUDIO:UInt = $00000010
Const SDL_INIT_VIDEO:UInt = $00000020
Const SDL_INIT_JOYSTICK:UInt = $00000200
Const SDL_INIT_HAPTIC:UInt = $00001000
Const SDL_INIT_GAMEPAD:UInt = $00002000
Const SDL_INIT_EVENTS:UInt = $00004000
Const SDL_INIT_SENSOR:UInt = $00008000
Const SDL_INIT_CAMERA:UInt = $00010000
Const SDL_EVENT_KEY_DOWN:UInt = $300

Extern
	Function SDL_Init:Int(flags:UInt) = "bmx_sdl3_Init"
	Function SDL_InitSubSystem:Int(flags:UInt) = "bmx_sdl3_InitSubSystem"
	Function SDL_WasInit:UInt(flags:UInt)
	Function SDL_QuitSubSystem(flags:UInt)
	Function SDL_Quit()
	Function SDL_GetVersion:Int()
	Function SDL_GetError:String() = "bmx_sdl3_GetError"
	Function SDL_ClearError:Int() = "bmx_sdl3_ClearError"
	Function SDL_SetEventEnabled(eventType:UInt, enabled:Int) = "bmx_sdl3_SetEventEnabled"
	Function SDL_EventEnabled:Int(eventType:UInt) = "bmx_sdl3_EventEnabled"
End Extern
