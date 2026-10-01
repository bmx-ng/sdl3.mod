#include <windows.h>
#include <SDL3/SDL.h>
#include <sdl3.mod/sdl3system.mod/event_observer.h>

void bmx_SDL3_SetHostedEvents(int enabled);
static DWORD hostThread;
static SDL_AtomicInt wakePending;
static const wchar_t bridgeProperty[] = L"BMX.SDL3.MaxGUI";

typedef struct CanvasBridge {
	HWND hwnd;
	WNDPROC hostProc;
	WNDPROC sdlProc;
} CanvasBridge;

static void wakeHost(void) {
	if (SDL_CompareAndSwapAtomicInt(&wakePending, 0, 1)) {
		if (!PostThreadMessageW(hostThread, WM_NULL, 0, 0)) SDL_SetAtomicInt(&wakePending, 0);
	}
}

void bmx_SDL3_GUIResetWake(void) { SDL_SetAtomicInt(&wakePending, 0); }

int bmx_SDL3_GUIStart(void) {
	MSG message;
	hostThread = GetCurrentThreadId();
	/* Create the native queue before an SDL timer can post to it. */
	PeekMessageW(&message, NULL, 0, 0, PM_NOREMOVE);
	SDL_SetHint(SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP, "0");
	/* The host owns process DPI awareness. An empty value leaves it unchanged. */
	SDL_SetHint("SDL_WINDOWS_DPI_AWARENESS", "");
	bmx_SDL3_SetHostedEvents(1);
	bmx_SDL3_SetHostWakeup(wakeHost);
	return 1;
}

void bmx_SDL3_GUIStop(void) { bmx_SDL3_SetHostWakeup(NULL); }

static LRESULT CALLBACK canvasProc(HWND hwnd, UINT message, WPARAM wp, LPARAM lp) {
	CanvasBridge *bridge = (CanvasBridge *)GetPropW(hwnd, bridgeProperty);
	if (!bridge) return DefWindowProcW(hwnd, message, wp, lp);
	/* SDL chains its saved host procedure for size notifications. All other
	 * messages go straight to MaxGUI: SDL must not validate its paint region,
	 * consume text input, change focus, or manage native mouse capture. */
	if (message == WM_WINDOWPOSCHANGED) return CallWindowProcW(bridge->sdlProc, hwnd, message, wp, lp);
	return CallWindowProcW(bridge->hostProc, hwnd, message, wp, lp);
}

static void SDLCALL releaseBridge(void *userdata, void *value) {
	CanvasBridge *bridge = value;
	/* Properties are destroyed before SDL's platform window cleanup. Restore
	 * the host procedure before releasing the router's state. */
	if (IsWindow(bridge->hwnd) && (WNDPROC)GetWindowLongPtrW(bridge->hwnd, GWLP_WNDPROC) == canvasProc) {
		SetWindowLongPtrW(bridge->hwnd, GWLP_WNDPROC, (LONG_PTR)bridge->hostProc);
	}
	RemovePropW(bridge->hwnd, bridgeProperty);
	SDL_free(bridge);
}

SDL_Window *bmx_SDL3_GUIAttach(void *widget) {
	HWND hwnd = widget;
	if (!IsWindow(hwnd) || GetWindowThreadProcessId(hwnd, NULL) != hostThread) {
		SDL_SetError("SDL3 MaxGUI: attach a live canvas on the GUI thread");
		return NULL;
	}
	if (GetPropW(hwnd, bridgeProperty)) {
		SDL_SetError("SDL3 MaxGUI: the canvas already has attached graphics");
		return NULL;
	}
	if (!SDL_WasInit(SDL_INIT_VIDEO) && !SDL_InitSubSystem(SDL_INIT_VIDEO)) return NULL;
	CanvasBridge *bridge = SDL_calloc(1, sizeof(*bridge));
	if (!bridge) return NULL;
	bridge->hwnd = hwnd;
	bridge->hostProc = (WNDPROC)GetWindowLongPtrW(hwnd, GWLP_WNDPROC);
	ULONG touchFlags = 0;
	BOOL touchEnabled = IsTouchWindow(hwnd, &touchFlags);
	SDL_PropertiesID props = SDL_CreateProperties();
	SDL_SetPointerProperty(props, SDL_PROP_WINDOW_CREATE_WIN32_HWND_POINTER, hwnd);
	SDL_Window *window = SDL_CreateWindowWithProperties(props);
	SDL_DestroyProperties(props);
	/* SDL registers external windows for touch. Preserve the host's policy. */
	if (touchEnabled) RegisterTouchWindow(hwnd, touchFlags);
	else UnregisterTouchWindow(hwnd);
	if (!window) {
		SDL_free(bridge);
		return NULL;
	}
	bridge->sdlProc = (WNDPROC)GetWindowLongPtrW(hwnd, GWLP_WNDPROC);
	if (!SetPropW(hwnd, bridgeProperty, bridge)) {
		SDL_DestroyWindow(window);
		SDL_free(bridge);
		SDL_SetError("SDL3 MaxGUI: could not register the canvas bridge");
		return NULL;
	}
	if (!SDL_SetPointerPropertyWithCleanup(SDL_GetWindowProperties(window), "bmx.maxgui.bridge", bridge, releaseBridge, NULL)) {
		SDL_DestroyWindow(window);
		return NULL;
	}
	SetWindowLongPtrW(hwnd, GWLP_WNDPROC, (LONG_PTR)canvasProc);
	return window;
}

void bmx_SDL3_GUISize(SDL_Window *window, int *width, int *height, int pixels) {
	HWND hwnd = SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_WIN32_HWND_POINTER, NULL);
	RECT rect = {0};
	GetClientRect(hwnd, &rect);
	/* MaxGUI's Windows client coordinates and drawable dimensions use the
	 * same units; do not apply standalone SDL window DPI scaling here. */
	*width = rect.right - rect.left;
	*height = rect.bottom - rect.top;
}

SDL_Renderer *bmx_SDL3_GUIRenderer(SDL_Window *window) {
	return SDL_CreateRenderer(window, NULL);
}

int bmx_SDL3_GUIClaimGPU(SDL_GPUDevice *device, SDL_Window *window) {
	return SDL_ClaimWindowForGPUDevice(device, window) ? 1 : 0;
}
