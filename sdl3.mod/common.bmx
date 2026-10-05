SuperStrict

ModuleInfo "CC_OPTS: -DSDL_dynapi_h_ -DSDL_DYNAMIC_API=0"

?macos
Import "source_macos.bmx"
?win32
Import "source_windows.bmx"
?linux And Not android
Import "source_linux.bmx"
?android
Import "source_android.bmx"
?Not macos And Not win32 And Not linux And Not android
Import "source.bmx"
?
