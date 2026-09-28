#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>

int bmx_SDL3_SetClipboardText(BBString *text) {
	unsigned char *utf8 = bbStringToUTF8String(text);
	int result = SDL_SetClipboardText((const char *)utf8) ? 1 : 0;
	bbMemFree(utf8);
	return result;
}
BBString *bmx_SDL3_GetClipboardText(void) {
	char *text = SDL_GetClipboardText();
	if (!text) return &bbEmptyString;
	BBString *result = bbStringFromUTF8String((const unsigned char *)text);
	SDL_free(text);
	return result;
}
int bmx_SDL3_HasClipboardText(void) {
	return SDL_HasClipboardText() ? 1 : 0;
}
