#include <SDL3/SDL.h>
#include <sdl3.mod/sdl3system.mod/event_observer.h>

static int calls[2];
static int selfCalls;
static int captureMouse;
static int selfRemoving(void *userdata, SDL_Event *event) {
    ++selfCalls;
    bmx_SDL3_RemoveEventObserver(selfRemoving);
    return 0;
}
static int first(void *userdata, SDL_Event *event) {
    ++calls[0];
    if (event->type == SDL_EVENT_KEY_DOWN) return BMX_SDL3_CAPTURE_KEYBOARD;
    if (captureMouse && event->type == SDL_EVENT_MOUSE_MOTION) return BMX_SDL3_CAPTURE_MOUSE;
    return 0;
}
static int second(void *userdata, SDL_Event *event) {
    ++calls[1];
    return 0;
}
void probeInstall(void) {
    bmx_SDL3_AddEventObserver(first, NULL);
    bmx_SDL3_AddEventObserver(second, NULL);
}
void probeRemove(void) {
    bmx_SDL3_RemoveEventObserver(first);
    bmx_SDL3_RemoveEventObserver(second);
}
int probeCallCount(int index) { return calls[index]; }
void probeSetMouseCapture(int enabled) { captureMouse = enabled; }
void probeInstallSelfRemoving(void) { bmx_SDL3_AddEventObserver(selfRemoving, NULL); }
int probeSelfCallCount(void) { return selfCalls; }
int probePushKey(void) {
    SDL_Event event = {0};
    event.type = SDL_EVENT_KEY_DOWN;
    event.key.key = SDLK_A;
    return SDL_PushEvent(&event) ? 1 : 0;
}
int probePushMouse(void) {
    SDL_Event event = {0};
    event.type = SDL_EVENT_MOUSE_MOTION;
    event.motion.x = 12;
    event.motion.y = 34;
    return SDL_PushEvent(&event) ? 1 : 0;
}
int probePushQuit(void) {
    SDL_Event event = {0};
    event.type = SDL_EVENT_QUIT;
    return SDL_PushEvent(&event) ? 1 : 0;
}
int probePushLifecycle(void) {
    SDL_Event event = {0};
    event.type = SDL_EVENT_WILL_ENTER_BACKGROUND;
    return SDL_PushEvent(&event) ? 1 : 0;
}
static int SDLCALL pushLifecycleThread(void *userdata) {
    SDL_Event event = {0};
    event.type = SDL_EVENT_DID_ENTER_FOREGROUND;
    return SDL_PushEvent(&event) ? 1 : 0;
}
int probePushLifecycleFromThread(void) {
    SDL_Thread *thread = SDL_CreateThread(pushLifecycleThread, "lifecycle-test", NULL);
    if (!thread) return 0;
    int result = 0;
    SDL_WaitThread(thread, &result);
    return result;
}

int probeQueueOpenFile(void) {
	char *path = SDL_strdup("/tmp/SDL3-caf\xc3\xa9.txt");
	int result = bmx_SDL3_QueueOpenFile(path);
	/* Destroy the caller's storage before the test polls the event queue. */
	SDL_memset(path, 'X', SDL_strlen(path));
	SDL_free(path);
	return result;
}
static bool SDLCALL rejectDrop(void *userdata, SDL_Event *event) {
	return event->type != SDL_EVENT_DROP_FILE;
}
void probeRejectDrops(int enabled) {
	SDL_SetEventFilter(enabled ? rejectDrop : NULL, NULL);
}
int probePushText(void) {
	SDL_Event event = {0};
	event.type = SDL_EVENT_TEXT_INPUT;
	event.text.text = "caf\xc3\xa9";
	return SDL_PushEvent(&event) ? 1 : 0;
}

int probeIsDummyVideo(void) {
	const char *driver = SDL_GetCurrentVideoDriver();
	return driver && SDL_strcmp(driver, "dummy") == 0;
}
int probePushEditing(Uint32 windowID, int empty) {
	SDL_Event event = {0};
	event.type = SDL_EVENT_TEXT_EDITING;
	event.edit.windowID = windowID;
	event.edit.text = empty ? "" : "caf\xc3\xa9";
	event.edit.start = empty ? -1 : 1;
	event.edit.length = empty ? -1 : 2;
	return SDL_PushEvent(&event) ? 1 : 0;
}
static int captureEditing(void *userdata, SDL_Event *event) {
	return BMX_SDL3_CAPTURE_KEYBOARD;
}
void probeCaptureEditing(int enabled) {
	if (enabled) bmx_SDL3_AddEventObserver(captureEditing, NULL);
	else bmx_SDL3_RemoveEventObserver(captureEditing);
}

int probePushInput(int kind, Uint32 window, float amount) {
	SDL_Event event = {0};
	switch (kind) {
	case 1:
		event.type = SDL_EVENT_MOUSE_WHEEL;
		event.wheel.windowID = window;
		event.wheel.which = 7;
		event.wheel.x = 0.5f;
		event.wheel.y = amount;
		event.wheel.mouse_x = 12.5f;
		event.wheel.mouse_y = 34.25f;
		event.wheel.direction = SDL_MOUSEWHEEL_FLIPPED;
		break;
	case 2: case 3: case 4: case 5:
		event.type = kind == 2 ? SDL_EVENT_FINGER_DOWN : kind == 3 ? SDL_EVENT_FINGER_MOTION :
			kind == 4 ? SDL_EVENT_FINGER_CANCELED : SDL_EVENT_FINGER_UP;
		event.tfinger.windowID = window;
		event.tfinger.touchID = 0x100000001ULL;
		event.tfinger.fingerID = amount == 0 ? 0x200000001ULL : 0x300000001ULL;
		event.tfinger.x = 0.25f;
		event.tfinger.y = 0.75f;
		event.tfinger.dx = 0.125f;
		event.tfinger.pressure = 0.5f;
		break;
	case 6: case 7:
		event.type = kind == 6 ? SDL_EVENT_WINDOW_FOCUS_GAINED : SDL_EVENT_WINDOW_FOCUS_LOST;
		event.window.windowID = window;
		break;
	case 8: case 9:
		event.type = kind == 8 ? SDL_EVENT_KEY_DOWN : SDL_EVENT_KEY_UP;
		event.key.windowID = window;
		event.key.which = 3;
		event.key.key = SDLK_A;
		event.key.scancode = SDL_SCANCODE_A;
		break;
	case 10:
		event.type = SDL_EVENT_DROP_TEXT;
		event.drop.windowID = window;
		event.drop.data = "caf\xc3\xa9";
		event.drop.x = 4.5f;
		event.drop.y = 8.25f;
		break;
	case 11:
		event.type = SDL_EVENT_TEXT_INPUT;
		event.text.windowID = window;
		event.text.text = "\xf0\x9f\x98\x80";
		break;
	case 12: case 13:
		event.type = kind == 12 ? SDL_EVENT_MOUSE_BUTTON_DOWN : SDL_EVENT_MOUSE_BUTTON_UP;
		event.button.windowID = window;
		event.button.button = SDL_BUTTON_LEFT;
		event.button.x = 1.5f;
		event.button.y = 2.5f;
		break;
	default: return 0;
	}
	return SDL_PushEvent(&event) ? 1 : 0;
}
static int captureAllMouse(void *userdata, SDL_Event *event) {
	return BMX_SDL3_CAPTURE_MOUSE;
}
void probeCaptureAllMouse(int enabled) {
	if (enabled) bmx_SDL3_AddEventObserver(captureAllMouse, NULL);
	else bmx_SDL3_RemoveEventObserver(captureAllMouse);
}

int probePushController(int gamepad) {
	SDL_Event event = {0};
	event.type = gamepad ? SDL_EVENT_GAMEPAD_AXIS_MOTION : SDL_EVENT_JOYSTICK_AXIS_MOTION;
	event.jaxis.which = 123;
	return SDL_PushEvent(&event) ? 1 : 0;
}

int probeVideoBackendMask(void) {
	int mask = 0;
	for (int i = 0; i < SDL_GetNumVideoDrivers(); ++i) {
		const char *name = SDL_GetVideoDriver(i);
		if (!SDL_strcmp(name, "x11")) mask |= 1;
		if (!SDL_strcmp(name, "wayland")) mask |= 2;
		if (!SDL_strcmp(name, "kmsdrm")) mask |= 4;
	}
	return mask;
}
