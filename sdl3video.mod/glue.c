#include <SDL3/SDL.h>
#include <stdint.h>
#include <brl.mod/blitz.mod/blitz.h>

SDL_Window *bmx_SDL3_CreateWindow(BBString *title, int width, int height, Uint64 flags) {
    unsigned char *utf8 = bbStringToUTF8String(title);
    SDL_Window *window = SDL_CreateWindow((const char *)utf8, width, height, flags);
    bbMemFree(utf8);
    return window;
}
int bmx_SDL3_GetWindowSize(SDL_Window *window, int *width, int *height) {
	int result = SDL_GetWindowSize(window, width, height) ? 1 : 0;
	if (!result) {
		*width = 0;
		*height = 0;
	}
	return result;
}
int bmx_SDL3_SetWindowSize(SDL_Window *window, int width, int height) {
    return SDL_SetWindowSize(window, width, height) ? 1 : 0;
}
int bmx_SDL3_GetWindowSizeInPixels(SDL_Window *window, int *width, int *height) {
	int result = SDL_GetWindowSizeInPixels(window, width, height) ? 1 : 0;
	if (!result) {
		*width = 0;
		*height = 0;
	}
	return result;
}
int bmx_SDL3_GetWindowPosition(SDL_Window *window, int *x, int *y) {
	int result = SDL_GetWindowPosition(window, x, y) ? 1 : 0;
	if (!result) {
		*x = 0;
		*y = 0;
	}
	return result;
}
int bmx_SDL3_SetWindowPosition(SDL_Window *window, int x, int y) {
    return SDL_SetWindowPosition(window, x, y) ? 1 : 0;
}
BBString *bmx_SDL3_GetWindowTitle(SDL_Window *window) {
    return bbStringFromUTF8String((const unsigned char *)SDL_GetWindowTitle(window));
}
int bmx_SDL3_SetWindowTitle(SDL_Window *window, BBString *title) {
    unsigned char *utf8 = bbStringToUTF8String(title);
    int result = SDL_SetWindowTitle(window, (const char *)utf8) ? 1 : 0;
    bbMemFree(utf8);
    return result;
}
int bmx_SDL3_ShowWindow(SDL_Window *window) { return SDL_ShowWindow(window) ? 1 : 0; }
int bmx_SDL3_HideWindow(SDL_Window *window) { return SDL_HideWindow(window) ? 1 : 0; }
int bmx_SDL3_SetWindowFullscreen(SDL_Window *window, int enabled) {
    return SDL_SetWindowFullscreen(window, enabled != 0) ? 1 : 0;
}
int bmx_SDL3_SetWindowFullscreenMode(SDL_Window *window, int width, int height, int depth, int hertz) {
    SDL_DisplayID display = SDL_GetDisplayForWindow(window);
    SDL_DisplayMode mode;
    if (!display || !SDL_GetClosestFullscreenDisplayMode(display, width, height, (float)hertz, false, &mode)) return 0;
    const SDL_PixelFormatDetails *format = SDL_GetPixelFormatDetails(mode.format);
    if (depth > 0 && (!format || format->bits_per_pixel != depth)) return 0;
    return SDL_SetWindowFullscreenMode(window, &mode) ? 1 : 0;
}
int bmx_SDL3_GLMakeCurrent(SDL_Window *window, SDL_GLContext context) {
    return SDL_GL_MakeCurrent(window, context) ? 1 : 0;
}
int bmx_SDL3_GLSwapWindow(SDL_Window *window) { return SDL_GL_SwapWindow(window) ? 1 : 0; }
int bmx_SDL3_GLSetAttribute(int attribute, int value) {
    return SDL_GL_SetAttribute((SDL_GLAttr)attribute, value) ? 1 : 0;
}
int bmx_SDL3_GLGetAttribute(int attribute, int *value) {
	int result = SDL_GL_GetAttribute((SDL_GLAttr)attribute, value) ? 1 : 0;
	if (!result) *value = 0;
	return result;
}
void *bmx_SDL3_GLGetProcAddress(BBString *name) {
    unsigned char *utf8 = bbStringToUTF8String(name);
    SDL_FunctionPointer pointer = SDL_GL_GetProcAddress((const char *)utf8);
    bbMemFree(utf8);
    return (void *)pointer;
}
int bmx_SDL3_GLSetSwapInterval(int interval) { return SDL_GL_SetSwapInterval(interval) ? 1 : 0; }
int bmx_SDL3_GLDestroyContext(SDL_GLContext context) { return SDL_GL_DestroyContext(context) ? 1 : 0; }
void *bmx_SDL3_GetWindowHandle(SDL_Window *window) {
    SDL_PropertiesID properties = SDL_GetWindowProperties(window);
    const char *driver = SDL_GetCurrentVideoDriver();
    if (!properties || !driver) return NULL;
    if (SDL_strcmp(driver, "cocoa") == 0) return SDL_GetPointerProperty(properties, SDL_PROP_WINDOW_COCOA_WINDOW_POINTER, NULL);
    if (SDL_strcmp(driver, "windows") == 0) return SDL_GetPointerProperty(properties, SDL_PROP_WINDOW_WIN32_HWND_POINTER, NULL);
    if (SDL_strcmp(driver, "wayland") == 0) return SDL_GetPointerProperty(properties, SDL_PROP_WINDOW_WAYLAND_SURFACE_POINTER, NULL);
    if (SDL_strcmp(driver, "x11") == 0) return (void *)(uintptr_t)SDL_GetNumberProperty(properties, SDL_PROP_WINDOW_X11_WINDOW_NUMBER, 0);
    if (SDL_strcmp(driver, "android") == 0) return SDL_GetPointerProperty(properties, SDL_PROP_WINDOW_ANDROID_WINDOW_POINTER, NULL);
    return NULL;
}
void *bmx_SDL3_GetWindowDisplayHandle(SDL_Window *window) {
    SDL_PropertiesID properties = SDL_GetWindowProperties(window);
    const char *driver = SDL_GetCurrentVideoDriver();
    if (!properties || !driver) return NULL;
    if (SDL_strcmp(driver, "x11") == 0) return SDL_GetPointerProperty(properties, SDL_PROP_WINDOW_X11_DISPLAY_POINTER, NULL);
    if (SDL_strcmp(driver, "wayland") == 0) return SDL_GetPointerProperty(properties, SDL_PROP_WINDOW_WAYLAND_DISPLAY_POINTER, NULL);
    return NULL;
}
void bmx_SDL3_WarpMouseInFocus(int x, int y) {
    SDL_Window *window = SDL_GetMouseFocus();
    if (window) SDL_WarpMouseInWindow(window, (float)x, (float)y);
}

int bmx_SDL3_StartTextInput(SDL_Window *window) {
	return SDL_StartTextInput(window) ? 1 : 0;
}
int bmx_SDL3_StopTextInput(SDL_Window *window) {
	return SDL_StopTextInput(window) ? 1 : 0;
}
int bmx_SDL3_TextInputActive(SDL_Window *window) {
	return SDL_TextInputActive(window) ? 1 : 0;
}

int bmx_SDL3_SetTextInputArea(SDL_Window *window, const SDL_Rect *rect, int cursor) {
	return SDL_SetTextInputArea(window, rect, cursor) ? 1 : 0;
}
int bmx_SDL3_GetTextInputArea(SDL_Window *window, SDL_Rect *rect, int *cursor) {
	SDL_zero(*rect);
	*cursor = 0;
	return SDL_GetTextInputArea(window, rect, cursor) ? 1 : 0;
}
int bmx_SDL3_ResetTextInputArea(SDL_Window *window) {
	return SDL_SetTextInputArea(window, NULL, 0) ? 1 : 0;
}
int bmx_SDL3_ClearComposition(SDL_Window *window) {
	return SDL_ClearComposition(window) ? 1 : 0;
}

int bmx_SDL3_SetWindowRelativeMouseMode(SDL_Window *window, int enabled) {
	return SDL_SetWindowRelativeMouseMode(window, enabled != 0) ? 1 : 0;
}
int bmx_SDL3_GetWindowRelativeMouseMode(SDL_Window *window) {
	return SDL_GetWindowRelativeMouseMode(window) ? 1 : 0;
}

int bmx_SDL3_SetWindowResizable(SDL_Window *window, int enabled) {
	return SDL_SetWindowResizable(window, enabled != 0) ? 1 : 0;
}
int bmx_SDL3_SetWindowBordered(SDL_Window *window, int enabled) {
	return SDL_SetWindowBordered(window, enabled != 0) ? 1 : 0;
}
int bmx_SDL3_SetWindowMouseGrab(SDL_Window *window, int enabled) {
	return SDL_SetWindowMouseGrab(window, enabled != 0) ? 1 : 0;
}
int bmx_SDL3_MinimizeWindow(SDL_Window *window) {
	return SDL_MinimizeWindow(window) ? 1 : 0;
}
int bmx_SDL3_MaximizeWindow(SDL_Window *window) {
	return SDL_MaximizeWindow(window) ? 1 : 0;
}
int bmx_SDL3_RestoreWindow(SDL_Window *window) {
	return SDL_RestoreWindow(window) ? 1 : 0;
}
int bmx_SDL3_RaiseWindow(SDL_Window *window) {
	return SDL_RaiseWindow(window) ? 1 : 0;
}
int bmx_SDL3_SyncWindow(SDL_Window *window) {
	return SDL_SyncWindow(window) ? 1 : 0;
}
int bmx_SDL3_SetWindowMinimumSize(SDL_Window *window, int width, int height) {
	return SDL_SetWindowMinimumSize(window, width, height) ? 1 : 0;
}
int bmx_SDL3_GetWindowMinimumSize(SDL_Window *window, int *width, int *height) {
	*width = 0;
	*height = 0;
	return SDL_GetWindowMinimumSize(window, width, height) ? 1 : 0;
}
int bmx_SDL3_SetWindowMaximumSize(SDL_Window *window, int width, int height) {
	return SDL_SetWindowMaximumSize(window, width, height) ? 1 : 0;
}
int bmx_SDL3_GetWindowMaximumSize(SDL_Window *window, int *width, int *height) {
	*width = 0;
	*height = 0;
	return SDL_GetWindowMaximumSize(window, width, height) ? 1 : 0;
}
int bmx_SDL3_SetWindowIcon(SDL_Window *window, SDL_Surface *surface) {
	return SDL_SetWindowIcon(window, surface) ? 1 : 0;
}
int bmx_SDL3_GetWindowMouseGrab(SDL_Window *window) {
	return SDL_GetWindowMouseGrab(window) ? 1 : 0;
}
int bmx_SDL3_SetWindowMouseRect(SDL_Window *window, const SDL_Rect *rect) {
	return SDL_SetWindowMouseRect(window, rect) ? 1 : 0;
}
int bmx_SDL3_ResetWindowMouseRect(SDL_Window *window) {
	return SDL_SetWindowMouseRect(window, NULL) ? 1 : 0;
}
int bmx_SDL3_GetWindowMouseRect(SDL_Window *window, SDL_Rect *rect) {
	SDL_zero(*rect);
	const SDL_Rect *value = SDL_GetWindowMouseRect(window);
	if (!value) return 0;
	*rect = *value;
	return 1;
}
