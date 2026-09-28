SuperStrict

Module SDL3.macosmfi

?macos
ModuleInfo "CC_OPTS: -mmmx -msse -msse2 -DTARGET_API_MAC_OSX"
ModuleInfo "CC_OPTS: -fobjc-arc"
ModuleInfo "CC_OPTS: -DSDL_dynapi_h_ -DSDL_DYNAMIC_API=0"

'Import "../sdl3.mod/include/macos/*.h"
'Import "../sdl3.mod/SDL/include/*.h"
Import "../sdl3.mod/SDL/include/*.h"
Import "../sdl3.mod/SDL/src/*.h"
Import "../sdl3.mod/SDL/include/build_config/*.h"
Import "../sdl3.mod/SDL/src/video/khronos/*.h"


' this file must be compiled with ARC enabled ( -fobjc-arc )
' unfortunately, we don't support CC_OPTS on a per-file basis.
Import "../sdl3.mod/SDL/src/joystick/apple/SDL_mfijoystick.m"
Import "../sdl3.mod/SDL/src/video/cocoa/SDL_cocoavideo.m"
Import "../sdl3.mod/SDL/src/video/cocoa/SDL_cocoawindow.m"


?

