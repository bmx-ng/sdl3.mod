#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>

int bmx_sdl3_Init(unsigned int flags) {
    return SDL_Init(flags) ? 1 : 0;
}

int bmx_sdl3_InitSubSystem(unsigned int flags) {
    return SDL_InitSubSystem(flags) ? 1 : 0;
}

BBString *bmx_sdl3_GetError(void) {
    return bbStringFromUTF8String((const unsigned char *)SDL_GetError());
}

int bmx_sdl3_ClearError(void) {
    return SDL_ClearError() ? 1 : 0;
}

void bmx_sdl3_SetEventEnabled(unsigned int event_type, int enabled) {
    SDL_SetEventEnabled(event_type, enabled != 0);
}

int bmx_sdl3_EventEnabled(unsigned int event_type) {
    return SDL_EventEnabled(event_type) ? 1 : 0;
}
