#include <stdint.h>
#include <gdk/gdkx.h>
#include <SDL3/SDL.h>
#include <sdl3.mod/sdl3system.mod/event_observer.h>

void bmx_SDL3_SetHostedEvents(int enabled);
static SDL_AtomicInt wakePending;
static GSource *wakeSource;

typedef struct CanvasBridge {
	GdkWindow *host;
	Display *display;
	Window xid;
} CanvasBridge;

static gboolean wakePrepare(GSource *source, gint *timeout) {
	*timeout = -1;
	return SDL_GetAtomicInt(&wakePending) != 0;
}

static gboolean wakeCheck(GSource *source) {
	return SDL_GetAtomicInt(&wakePending) != 0;
}

static gboolean wakeDispatch(GSource *source, GSourceFunc callback, gpointer data) {
	SDL_SetAtomicInt(&wakePending, 0);
	return G_SOURCE_CONTINUE;
}

static GSourceFuncs wakeFunctions = {
	.prepare = wakePrepare,
	.check = wakeCheck,
	.dispatch = wakeDispatch
};

static void wakeHost(void) {
	SDL_SetAtomicInt(&wakePending, 1);
	g_main_context_wakeup(g_main_context_default());
}

int bmx_SDL3_GUIStart(void) {
	GdkDisplay *display = gdk_display_get_default();
	if (!display || !GDK_IS_X11_DISPLAY(display)) {
		SDL_SetError("SDL3 MaxGUI: Linux canvas attachment requires GTK X11; launch with GDK_BACKEND=x11");
		return 0;
	}
	if (SDL_WasInit(SDL_INIT_VIDEO) && SDL_strcmp(SDL_GetCurrentVideoDriver(), "x11") != 0) {
		SDL_SetError("SDL3 MaxGUI: an existing SDL video driver must use X11");
		return 0;
	}
	SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "x11");
	SDL_SetHint(SDL_HINT_VIDEO_X11_EXTERNAL_WINDOW_INPUT, "0");
	wakeSource = g_source_new(&wakeFunctions, sizeof(GSource));
	g_source_attach(wakeSource, g_main_context_default());
	bmx_SDL3_SetHostedEvents(1);
	bmx_SDL3_SetHostWakeup(wakeHost);
	return 1;
}

void bmx_SDL3_GUIStop(void) {
	bmx_SDL3_SetHostWakeup(NULL);
	g_source_destroy(wakeSource);
	g_source_unref(wakeSource);
	wakeSource = NULL;
}

void bmx_SDL3_GUIResetWake(void) {
	SDL_SetAtomicInt(&wakePending, 0);
	/* SDL has its own X connection, subscribed only to drawing-window changes.
	 * Pumping it cannot consume GTK's input or run GTK's native event loop. */
	if (SDL_WasInit(SDL_INIT_VIDEO)) SDL_PumpEvents();
}

static void SDLCALL releaseWindow(void *userdata, void *value) {
	CanvasBridge *bridge = value;
	if (!gdk_window_is_destroyed(bridge->host)) {
		XSelectInput(bridge->display, bridge->xid, NoEventMask);
		XFlush(bridge->display);
	}
	g_object_set_data(G_OBJECT(bridge->host), "bmx.sdl3.attached", NULL);
	g_object_unref(bridge->host);
	SDL_free(bridge);
}

SDL_Window *bmx_SDL3_GUIAttach(void *widget) {
	GdkDisplay *display = gdk_display_get_default();
	Window xid = (Window)(uintptr_t)widget;
	GdkWindow *host = gdk_x11_window_lookup_for_display(display, xid);
	if (!host || gdk_window_is_destroyed(host)) {
		SDL_SetError("SDL3 MaxGUI: attach a live GTK X11 canvas");
		return NULL;
	}
	if (g_object_get_data(G_OBJECT(host), "bmx.sdl3.attached")) {
		SDL_SetError("SDL3 MaxGUI: the canvas already has attached graphics");
		return NULL;
	}
	if (!SDL_WasInit(SDL_INIT_VIDEO) && !SDL_InitSubSystem(SDL_INIT_VIDEO)) return NULL;
	if (SDL_strcmp(SDL_GetCurrentVideoDriver(), "x11") != 0) {
		SDL_SetError("SDL3 MaxGUI: Linux canvas attachment requires SDL's X11 video driver");
		return NULL;
	}
	gdk_display_sync(display);
	SDL_PropertiesID props = SDL_CreateProperties();
	SDL_SetNumberProperty(props, SDL_PROP_WINDOW_CREATE_X11_WINDOW_NUMBER, xid);
	SDL_Window *window = SDL_CreateWindowWithProperties(props);
	SDL_DestroyProperties(props);
	if (!window) return NULL;
	CanvasBridge *bridge = SDL_calloc(1, sizeof(*bridge));
	if (!bridge) {
		SDL_DestroyWindow(window);
		return NULL;
	}
	bridge->host = g_object_ref(host);
	bridge->xid = xid;
	bridge->display = SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_X11_DISPLAY_POINTER, NULL);
	if (!SDL_SetPointerPropertyWithCleanup(SDL_GetWindowProperties(window), "bmx.maxgui.bridge", bridge, releaseWindow, NULL)) {
		SDL_DestroyWindow(window);
		return NULL;
	}
	g_object_set_data(G_OBJECT(host), "bmx.sdl3.attached", bridge);
	Display *sdlDisplay = bridge->display;
	/* Event selection is per connection. GTK retains its complete input mask. */
	XSelectInput(sdlDisplay, xid, StructureNotifyMask | ExposureMask);
	XFlush(sdlDisplay);
	return window;
}

void bmx_SDL3_GUISize(SDL_Window *window, int *width, int *height, int pixels) {
	CanvasBridge *bridge = SDL_GetPointerProperty(SDL_GetWindowProperties(window), "bmx.maxgui.bridge", NULL);
	GdkWindow *host = bridge->host;
	int scale = gdk_window_get_scale_factor(host);
	int w = gdk_window_get_width(host) * scale;
	int h = gdk_window_get_height(host) * scale;
	int cachedWidth, cachedHeight;
	SDL_GetWindowSize(window, &cachedWidth, &cachedHeight);
	if (cachedWidth != w || cachedHeight != h) {
		/* Synchronize only after a resize, not on every size query/draw. GTK
		 * and SDL own separate X connections, so finish the host's requests
		 * before consuming the resulting SDL configure notifications. */
		gdk_display_sync(gdk_window_get_display(host));
		Display *display = SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_X11_DISPLAY_POINTER, NULL);
		XSync(display, False);
		SDL_PumpEvents();
	}
	*width = pixels ? w : w / scale;
	*height = pixels ? h : h / scale;
}

SDL_Renderer *bmx_SDL3_GUIRenderer(SDL_Window *window) {
	return SDL_CreateRenderer(window, NULL);
}

int bmx_SDL3_GUIClaimGPU(SDL_GPUDevice *device, SDL_Window *window) {
	return SDL_ClaimWindowForGPUDevice(device, window) ? 1 : 0;
}
