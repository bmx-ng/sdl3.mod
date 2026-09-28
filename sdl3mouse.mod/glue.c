#include <SDL3/SDL.h>

SDL_Cursor *bmx_SDL3_CreateSystemCursor(int shape) {
	return SDL_CreateSystemCursor((SDL_SystemCursor)shape);
}
SDL_Cursor *bmx_SDL3_CreateColorCursor(SDL_Surface *surface, int x, int y) {
	return SDL_CreateColorCursor(surface, x, y);
}
int bmx_SDL3_SetCursor(SDL_Cursor *cursor) {
	return SDL_SetCursor(cursor) ? 1 : 0;
}
void bmx_SDL3_DestroyCursor(SDL_Cursor *cursor) {
	SDL_DestroyCursor(cursor);
}
int bmx_SDL3_ResetCursor(void) {
	SDL_Cursor *cursor = SDL_GetDefaultCursor();
	return cursor && SDL_SetCursor(cursor) ? 1 : 0;
}
int bmx_SDL3_CursorVisibility(int visible) {
	return (visible ? SDL_ShowCursor() : SDL_HideCursor()) ? 1 : 0;
}
int bmx_SDL3_CursorVisible(void) {
	return SDL_CursorVisible() ? 1 : 0;
}
int bmx_SDL3_CaptureMouse(int enabled) {
	return SDL_CaptureMouse(enabled != 0) ? 1 : 0;
}
Uint32 bmx_SDL3_GetMouseState(float *x, float *y) {
	return SDL_GetMouseState(x, y);
}
Uint32 bmx_SDL3_GetRelativeMouseState(float *x, float *y) {
	return SDL_GetRelativeMouseState(x, y);
}
