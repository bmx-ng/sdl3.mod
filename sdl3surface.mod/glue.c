#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>

SDL_Surface *bmx_SDL3_CreateSurface(int width, int height, Uint32 format) {
    return SDL_CreateSurface(width, height, format ? format : SDL_PIXELFORMAT_RGBA32);
}
int bmx_SDL3_SurfaceWidth(SDL_Surface *surface) { return surface ? surface->w : 0; }
int bmx_SDL3_SurfaceHeight(SDL_Surface *surface) { return surface ? surface->h : 0; }
Uint32 bmx_SDL3_SurfaceFormat(SDL_Surface *surface) { return surface ? surface->format : SDL_PIXELFORMAT_UNKNOWN; }
void bmx_SDL3_DestroySurface(SDL_Surface *surface) { SDL_DestroySurface(surface); }
int bmx_SDL3_FillSurfaceRect(SDL_Surface *surface, const SDL_Rect *rect, int red, int green, int blue, int alpha) {
    if (!surface) return 0;
    Uint32 color = SDL_MapSurfaceRGBA(surface, (Uint8)red, (Uint8)green, (Uint8)blue, (Uint8)alpha);
    return SDL_FillSurfaceRect(surface, rect, color) ? 1 : 0;
}
int bmx_SDL3_FillSurface(SDL_Surface *surface, int red, int green, int blue, int alpha) {
    return bmx_SDL3_FillSurfaceRect(surface, NULL, red, green, blue, alpha);
}
int bmx_SDL3_ReadSurfacePixel(SDL_Surface *surface, int x, int y, int *red, int *green, int *blue, int *alpha) {
    Uint8 r = 0, g = 0, b = 0, a = 0;
    if (!SDL_ReadSurfacePixel(surface, x, y, &r, &g, &b, &a)) return 0;
    *red = r; *green = g; *blue = b; *alpha = a;
    return 1;
}
