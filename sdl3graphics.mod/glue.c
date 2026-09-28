#include <SDL3/SDL.h>

/* Wayland compositors choose top-level window placement, including centering. */
int bmx_SDL3_GraphicsInitialPosition(SDL_Window *window, int x, int y) {
    const char *driver = SDL_GetCurrentVideoDriver();
    if (driver && SDL_strcmp(driver, "wayland") == 0) return 1;
    return SDL_SetWindowPosition(window, x, y) ? 1 : 0;
}

/* Five Ints per mode: width, height, depth, refresh rate, display index. */
int bmx_SDL3_GraphicsModes(int *output, int capacity) {
    int display_count = 0;
    SDL_DisplayID *displays = SDL_GetDisplays(&display_count);
    if (!displays) return 0;

    int written = 0;
    for (int display = 0; display < display_count && written < capacity; ++display) {
        int mode_count = 0;
        SDL_DisplayMode **modes = SDL_GetFullscreenDisplayModes(displays[display], &mode_count);
        if (!modes) continue;
        for (int i = 0; i < mode_count && written < capacity; ++i) {
            const SDL_DisplayMode *mode = modes[i];
            const SDL_PixelFormatDetails *format = SDL_GetPixelFormatDetails(mode->format);
            int *entry = output + written * 5;
            entry[0] = mode->w;
            entry[1] = mode->h;
            entry[2] = format ? format->bits_per_pixel : 0;
            entry[3] = (int)(mode->refresh_rate + 0.5f);
            entry[4] = display;
            ++written;
        }
        SDL_free(modes);
    }
    SDL_free(displays);
    return written;
}

/* 0: windowed, 1: exclusive, 2: desktop fullscreen. All bools cross as Int. */
int bmx_SDL3_GraphicsWindowMode(SDL_Window *window, int *depth, int *hertz) {
    *depth = 0; *hertz = 0;
    if (!(SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN)) return 0;
    const SDL_DisplayMode *mode = SDL_GetWindowFullscreenMode(window);
    if (!mode) return 2;
    const SDL_PixelFormatDetails *format = SDL_GetPixelFormatDetails(mode->format);
    *depth = format ? format->bits_per_pixel : 32;
    *hertz = (int)(mode->refresh_rate + 0.5f);
    return 1;
}

int bmx_SDL3_GraphicsSetWindowMode(SDL_Window *window, int requested, int width, int height, int hertz) {
    SDL_DisplayMode chosen = {0}, previous = {0};
    const SDL_DisplayMode *old = SDL_GetWindowFullscreenMode(window);
    int had_mode = old != NULL;
    int was_fullscreen = (SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN) != 0;
    if (old) previous = *old;
    if (requested == 1) {
        int count = 0, found = 0;
        SDL_DisplayMode **modes = SDL_GetFullscreenDisplayModes(SDL_GetDisplayForWindow(window), &count);
        if (!modes) return 0;
        for (int i = 0; i < count; ++i) {
            const SDL_DisplayMode *m = modes[i];
            if (m->w != width || m->h != height || (hertz && (int)(m->refresh_rate + 0.5f) != hertz)) continue;
            if (!found || m->refresh_rate > chosen.refresh_rate) { chosen = *m; found = 1; }
        }
        SDL_free(modes);
        if (!found) { SDL_SetError("Requested fullscreen display mode is unavailable"); return 0; }
    }
    int ok;
    if (requested) {
        ok = SDL_SetWindowFullscreenMode(window, requested == 1 ? &chosen : NULL)
            && SDL_SetWindowFullscreen(window, true) && SDL_SyncWindow(window);
    } else {
        ok = SDL_SetWindowFullscreen(window, false) && SDL_SyncWindow(window);
    }
    if (ok) {
        int depth, hz;
        ok = bmx_SDL3_GraphicsWindowMode(window, &depth, &hz) == requested;
        if (!ok) SDL_SetError("The window system rejected the requested fullscreen state");
    }
    if (!ok) {
        char error[512]; SDL_strlcpy(error, SDL_GetError(), sizeof(error));
        /* Best effort rollback; callers query the actual state even if rollback fails. */
        SDL_SetWindowFullscreenMode(window, had_mode ? &previous : NULL);
        SDL_SetWindowFullscreen(window, was_fullscreen != 0);
        SDL_SyncWindow(window);
        SDL_SetError("%s", error);
    }
    return ok ? 1 : 0;
}

/* Display scale is pixels per logical unit; density is pixels per SDL window unit.
   Their ratio handles pixel-coordinate backends (Windows/X11) and point-coordinate
   backends (macOS/Wayland). Raw TSDLWindow and input coordinates stay native. */
float bmx_SDL3_GraphicsWindowScale(SDL_Window *window) {
    float density = SDL_GetWindowPixelDensity(window);
    float scale = SDL_GetWindowDisplayScale(window);
    if (density > 0.0f && scale > 0.0f) return scale / density;
    return 1.0f;
}
int bmx_SDL3_GraphicsSetLogicalSize(SDL_Window *window, int width, int height) {
    float scale = bmx_SDL3_GraphicsWindowScale(window);
    return SDL_SetWindowSize(window, (int)SDL_roundf(width * scale), (int)SDL_roundf(height * scale))
        && SDL_SyncWindow(window) ? 1 : 0;
}
