SuperStrict

Rem
bbdoc: SDL3 UTF-8 text clipboard access.
about: Initialise SDL video and use these functions on the main thread. Retrieved text is copied into a BlitzMax String. An empty string may mean empty content or failure; use SDL_ClearError before reading and SDL_GetError afterwards if the distinction matters. Setting empty text clears the text clipboard. Binary/MIME clipboard data is not exposed by this module.
End Rem
Module SDL3.SDL3Clipboard

ModuleInfo "CC_OPTS: -I%PWD%/../sdl3.mod/SDL3/include"

Import SDL3.SDL3
Import "glue.c"

Rem
bbdoc: Copies text to the system clipboard. Returns True on success.
End Rem
Function SDLSetClipboardText:Int(text:String)
	Return bmx_SDL3_SetClipboardText(text)
End Function

Rem
bbdoc: Returns a copy of the system clipboard text.
End Rem
Function SDLGetClipboardText:String()
	Return bmx_SDL3_GetClipboardText()
End Function

Rem
bbdoc: Returns whether the clipboard contains nonempty text.
End Rem
Function SDLHasClipboardText:Int()
	Return bmx_SDL3_HasClipboardText()
End Function

Private
Extern
	Function bmx_SDL3_SetClipboardText:Int(text:String)
	Function bmx_SDL3_GetClipboardText:String()
	Function bmx_SDL3_HasClipboardText:Int()
End Extern
