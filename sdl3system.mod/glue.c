#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>
#include <brl.mod/event.mod/event.h>
#include <brl.mod/keycodes.mod/keycodes.h>
#include "event_observer.h"
#include <stdlib.h>
#include <limits.h>
#include <math.h>

void sdl3_sdl3system__TextEditing(Uint32 windowID, BBString *text, int start, int length);

BBObject *sdl3_sdl3system__InputKeyboard(Uint32 windowID, Uint64 timestamp, Uint32 keyboardID, int scancode, Uint32 keycode, int modifiers, int repeated);
BBObject *sdl3_sdl3system__InputMouse(Uint32 windowID, Uint64 timestamp, Uint32 mouseID, float x, float y, float dx, float dy, Uint32 buttons, int button, int clicks);
BBObject *sdl3_sdl3system__InputWheel(Uint32 windowID, Uint64 timestamp, Uint32 mouseID, float x, float y, float mouseX, float mouseY, int direction);
BBObject *sdl3_sdl3system__InputTouch(Uint32 windowID, Uint64 timestamp, Uint64 touchID, Uint64 fingerID, float x, float y, float dx, float dy, float pressure, int canceled);
BBObject *sdl3_sdl3system__InputTextInput(Uint32 windowID, Uint64 timestamp, BBString * text);
BBObject *sdl3_sdl3system__InputTextDrop(Uint32 windowID, Uint64 timestamp, BBString * text, float x, float y);
void sdl3_sdl3system__WheelEvent(BBObject *payload);
void sdl3_sdl3system__TextDropEvent(BBObject *payload);
static void clearInputState(void);

int brl_event_EmitEvent(BBObject *event);
BBObject *brl_event_CreateEvent(int id, BBObject *source, int data, int mods, int x, int y, BBObject *extra);
int sdl3_sdl3system_TSDLSystemDriver__eventFilter(BBObject *driver, int eventType);

typedef struct EventObserverNode {
    BMX_SDL3_EventObserver cb;
    void *userdata;
    struct EventObserverNode *next;
    struct EventObserverNode *retiredNext;
    int removed;
} EventObserverNode;
static EventObserverNode *eventObservers;
static EventObserverNode *retiredObservers;
static int dispatchDepth;
static SDL_ThreadID mainThread;
static Uint32 lifecycleWakeEvent;
static BBObject *lifecycleDriver;

/* Only the main thread produces these application open-file events.
 * SDL copies event structs, but does not own arbitrary caller string buffers. */
typedef struct PendingOpenFile {
	char *path;
	struct PendingOpenFile *next;
} PendingOpenFile;
static PendingOpenFile *pendingOpenFiles;

static PendingOpenFile *takeOpenFile(const char *path) {
	PendingOpenFile **slot = &pendingOpenFiles;
	while (*slot) {
		if ((*slot)->path == path) {
			PendingOpenFile *item = *slot;
			*slot = item->next;
			return item;
		}
		slot = &(*slot)->next;
	}
	return NULL;
}
static void freeOpenFile(PendingOpenFile *item) {
	if (!item) return;
	SDL_free(item->path);
	SDL_free(item);
}
int bmx_SDL3_QueueOpenFile(const char *path) {
	if (!SDL_IsMainThread() || !SDL_EventEnabled(SDL_EVENT_DROP_FILE)) return 0;
	PendingOpenFile *item = SDL_calloc(1, sizeof(*item));
	if (!item) return 0;
	item->path = SDL_strdup(path);
	if (!item->path) {
		SDL_free(item);
		return 0;
	}
	item->next = pendingOpenFiles;
	pendingOpenFiles = item;
	SDL_Event event = {0};
	event.type = SDL_EVENT_DROP_FILE;
	event.drop.data = item->path;
	if (!SDL_PushEvent(&event)) {
		freeOpenFile(takeOpenFile(item->path));
		return 0;
	}
	return 1;
}
void bmx_SDL3_SystemShutdown(void) {
	clearInputState();
	SDL_Quit();
	if (lifecycleDriver) {
		bbGCRelease(lifecycleDriver);
		lifecycleDriver = NULL;
	}
	lifecycleWakeEvent = 0;
	/* Also releases paths whose events were flushed or never polled. */
	while (pendingOpenFiles) {
		PendingOpenFile *item = pendingOpenFiles;
		pendingOpenFiles = item->next;
		freeOpenFile(item);
	}
}

void bmx_SDL3_AddEventObserver(BMX_SDL3_EventObserver callback, void *userdata) {
    EventObserverNode *node = malloc(sizeof(*node));
    if (!node) return;
    node->cb = callback;
    node->userdata = userdata;
    node->removed = 0;
    node->retiredNext = NULL;
    EventObserverNode **slot = &eventObservers;
    while (*slot) slot = &(*slot)->next;
    node->next = *slot;
    *slot = node;
}

void bmx_SDL3_RemoveEventObserver(BMX_SDL3_EventObserver callback) {
    EventObserverNode **slot = &eventObservers;
    while (*slot) {
        if ((*slot)->cb == callback) {
            EventObserverNode *node = *slot;
            *slot = node->next;
            node->removed = 1;
            if (dispatchDepth) {
                node->retiredNext = retiredObservers;
                retiredObservers = node;
            } else {
                free(node);
            }
            return;
        }
        slot = &(*slot)->next;
    }
}

static void emit(int id, BBObject *source, int data, int mods, int x, int y) {
    brl_event_EmitEvent(brl_event_CreateEvent(id, source, data, mods, x, y, &bbNullObject));
}

static int keymods(SDL_Keymod mods) {
    int result = 0;
    if (mods & SDL_KMOD_SHIFT) result |= MODIFIER_SHIFT;
    if (mods & SDL_KMOD_CTRL) result |= MODIFIER_CONTROL;
    if (mods & SDL_KMOD_ALT) result |= MODIFIER_OPTION;
    if (mods & SDL_KMOD_GUI) result |= MODIFIER_SYSTEM;
    return result;
}

static int keycode(SDL_Keycode key) {
    if (key >= SDLK_A && key <= SDLK_Z) return KEY_A + (int)(key - SDLK_A);
    if (key >= SDLK_0 && key <= SDLK_9) return KEY_0 + (int)(key - SDLK_0);
    if (key >= SDLK_F1 && key <= SDLK_F12) return KEY_F1 + (int)(key - SDLK_F1);
    if (key >= SDLK_KP_1 && key <= SDLK_KP_9) return KEY_NUM1 + (int)(key - SDLK_KP_1);
    switch (key) {
    case SDLK_BACKSPACE: return KEY_BACKSPACE;
    case SDLK_TAB: return KEY_TAB;
    case SDLK_RETURN: case SDLK_RETURN2: case SDLK_KP_ENTER: return KEY_ENTER;
    case SDLK_ESCAPE: return KEY_ESC;
    case SDLK_SPACE: return KEY_SPACE;
    case SDLK_PAGEUP: return KEY_PAGEUP;
    case SDLK_PAGEDOWN: return KEY_PAGEDOWN;
    case SDLK_END: return KEY_END;
    case SDLK_HOME: return KEY_HOME;
    case SDLK_LEFT: return KEY_LEFT;
    case SDLK_UP: return KEY_UP;
    case SDLK_RIGHT: return KEY_RIGHT;
    case SDLK_DOWN: return KEY_DOWN;
    case SDLK_INSERT: return KEY_INSERT;
    case SDLK_DELETE: return KEY_DELETE;
    case SDLK_LGUI: return KEY_LSYS;
    case SDLK_RGUI: return KEY_RSYS;
    case SDLK_KP_0: return KEY_NUM0;
    case SDLK_KP_MULTIPLY: return KEY_NUMMULTIPLY;
    case SDLK_KP_PLUS: return KEY_NUMADD;
    case SDLK_KP_MINUS: return KEY_NUMSUBTRACT;
    case SDLK_KP_PERIOD: return KEY_NUMDECIMAL;
    case SDLK_KP_DIVIDE: return KEY_NUMDIVIDE;
    case SDLK_LSHIFT: return KEY_LSHIFT;
    case SDLK_RSHIFT: return KEY_RSHIFT;
    case SDLK_LCTRL: return KEY_LCONTROL;
    case SDLK_RCTRL: return KEY_RCONTROL;
    case SDLK_LALT: return KEY_LALT;
    case SDLK_RALT: return KEY_RALT;
    case SDLK_AC_BACK: return KEY_BROWSER_BACK;
    case SDLK_AC_FORWARD: return KEY_BROWSER_FORWARD;
    case SDLK_AC_HOME: return KEY_BROWSER_HOME;
    case SDLK_AC_REFRESH: return KEY_BROWSER_REFRESH;
    case SDLK_AC_SEARCH: return KEY_BROWSER_SEARCH;
    case SDLK_AC_STOP: return KEY_BROWSER_STOP;
    case SDLK_GRAVE: return KEY_TILDE;
    case SDLK_MINUS: return KEY_MINUS;
    case SDLK_EQUALS: return KEY_EQUALS;
    case SDLK_LEFTBRACKET: return KEY_OPENBRACKET;
    case SDLK_RIGHTBRACKET: return KEY_CLOSEBRACKET;
    case SDLK_BACKSLASH: return KEY_BACKSLASH;
    case SDLK_SEMICOLON: return KEY_SEMICOLON;
    case SDLK_APOSTROPHE: return KEY_QUOTES;
    case SDLK_COMMA: return KEY_COMMA;
    case SDLK_PERIOD: return KEY_PERIOD;
    case SDLK_SLASH: return KEY_SLASH;
    default: return 0;
    }
}

static int mouseButton(Uint8 button) {
    static const int buttons[] = {0, 1, 3, 2, 4, 5};
    return button < SDL_arraysize(buttons) ? buttons[button] : button;
}

/* Polling and all translation state belong to the main thread. */
typedef struct InputWindow {
	Uint32 id;
	unsigned char keys[256];
	unsigned char buttons[5];
	struct InputWindow *next;
} InputWindow;
typedef struct WheelState {
	Uint32 window, mouse;
	double remainder;
	struct WheelState *next;
} WheelState;
typedef struct TouchState {
	Uint64 device, finger;
	Uint32 window;
	int legacy;
	struct TouchState *next;
} TouchState;
static InputWindow *inputWindows;
static WheelState *wheelStates;
static TouchState *touchStates;
static Uint32 focusedWindow;
static int applicationFocused, focusLossPending;

static InputWindow *inputWindow(Uint32 id) {
	for (InputWindow *item = inputWindows; item; item = item->next) {
		if (item->id == id) return item;
	}
	InputWindow *item = SDL_calloc(1, sizeof(*item));
	if (item) {
		item->id = id;
		item->next = inputWindows;
		inputWindows = item;
	}
	return item;
}
static void inputEmit(int id, int data, int mods, int x, int y, BBObject *extra) {
	brl_event_EmitEvent(brl_event_CreateEvent(id, &bbNullObject, data, mods, x, y, extra));
}
static void removeTouch(TouchState *item);
static void releaseWindowInput(Uint32 window) {
	InputWindow *item = inputWindow(window);
	if (!item) return;
	for (int key = 1; key < 256; ++key) {
		if (item->keys[key]) {
			item->keys[key] = 0;
			inputEmit(BBEVENT_KEYUP, key, 0, 0, 0,
				sdl3_sdl3system__InputKeyboard(window, 0, 0, 0, 0, 0, 0));
		}
	}
	for (int button = 0; button < 5; ++button) {
		if (item->buttons[button]) {
			item->buttons[button] = 0;
			inputEmit(BBEVENT_MOUSEUP, button + 1, 0, 0, 0,
				sdl3_sdl3system__InputMouse(window, 0, 0, 0, 0, 0, 0, 0, 0, 0));
		}
	}
	/* Cancel delivered contacts before discarding their legacy slots. */
	for (;;) {
		TouchState *touch = touchStates;
		while (touch && touch->window != window) touch = touch->next;
		if (!touch) break;
		int legacy = touch->legacy;
		Uint64 device = touch->device, finger = touch->finger;
		removeTouch(touch);
		inputEmit(BBEVENT_TOUCHUP, legacy, 0, 0, 0,
			sdl3_sdl3system__InputTouch(window, 0, device, finger, 0, 0, 0, 0, 0, 1));
	}
	for (WheelState *wheel = wheelStates; wheel; wheel = wheel->next) {
		if (wheel->window == window) wheel->remainder = 0;
	}
}
static void finishFocus(void) {
	if (!focusLossPending) return;
	focusLossPending = 0;
	SDL_Window *window = SDL_GetKeyboardFocus();
	if (window) {
		focusedWindow = SDL_GetWindowID(window);
		return;
	}
	focusedWindow = 0;
	if (applicationFocused) {
		applicationFocused = 0;
		emit(BBEVENT_APPSUSPEND, &bbNullObject, 0, 0, 0, 0);
	}
}
static int wheelSteps(SDL_MouseWheelEvent *event) {
	WheelState *state = wheelStates;
	while (state && (state->window != event->windowID || state->mouse != event->which)) state = state->next;
	if (!state) {
		state = SDL_calloc(1, sizeof(*state));
		if (!state) return 0;
		state->window = event->windowID;
		state->mouse = event->which;
		state->next = wheelStates;
		wheelStates = state;
	}
	if (!isfinite(event->y)) return 0;
	/* Legacy wheel direction follows SDL y, including natural scrolling. */
	state->remainder += event->y;
	double whole = trunc(state->remainder);
	int steps = whole > INT_MAX ? INT_MAX : whole < INT_MIN ? INT_MIN : (int)whole;
	state->remainder -= whole;
	return steps;
}
static TouchState *touchState(SDL_TouchFingerEvent *event) {
	int legacy = 0;
	for (TouchState *item = touchStates; item; item = item->next) {
		if (item->device == event->touchID && item->finger == event->fingerID) return item;
	}
	if (event->type == SDL_EVENT_FINGER_UP || event->type == SDL_EVENT_FINGER_CANCELED) return NULL;
	/* Reuse the smallest free positive slot, never truncate a native ID. */
	for (;;) {
		if (legacy == INT_MAX) return NULL;
		++legacy;
		TouchState *item = touchStates;
		while (item && item->legacy != legacy) item = item->next;
		if (!item) break;
	}
	TouchState *item = SDL_calloc(1, sizeof(*item));
	if (!item) return NULL;
	item->device = event->touchID;
	item->finger = event->fingerID;
	item->window = event->windowID;
	item->legacy = legacy;
	item->next = touchStates;
	touchStates = item;
	return item;
}
static void removeTouch(TouchState *item) {
	TouchState **slot = &touchStates;
	while (*slot && *slot != item) slot = &(*slot)->next;
	if (*slot) {
		*slot = item->next;
		SDL_free(item);
	}
}
static void clearInputState(void) {
	while (inputWindows) {
		InputWindow *item = inputWindows;
		inputWindows = item->next;
		SDL_free(item);
	}
	while (wheelStates) {
		WheelState *item = wheelStates;
		wheelStates = item->next;
		SDL_free(item);
	}
	while (touchStates) removeTouch(touchStates);
	focusedWindow = 0;
	applicationFocused = focusLossPending = 0;
}

static void emitEvent(SDL_Event *event) {
    BBObject *source = &bbNullObject;
    int mods = 0, key = 0, character = 0;
    switch (event->type) {
    case SDL_EVENT_DROP_FILE: {
		BBString *path = bbStringFromUTF8String((const unsigned char *)event->drop.data);
		brl_event_EmitEvent(brl_event_CreateEvent(BBEVENT_APPOPENFILE, source,
			(int)event->drop.windowID, 0, (int)event->drop.x, (int)event->drop.y, (BBObject *)path));
		return;
	}
	case SDL_EVENT_DROP_TEXT:
		sdl3_sdl3system__TextDropEvent(sdl3_sdl3system__InputTextDrop(event->drop.windowID,
			event->drop.timestamp, bbStringFromUTF8String((const unsigned char *)event->drop.data),
			event->drop.x, event->drop.y));
		return;
    case SDL_EVENT_QUIT:
        emit(BBEVENT_APPTERMINATE, source, 0, 0, 0, 0); return;
    case SDL_EVENT_KEY_DOWN:
        switch (event->key.key) {
        case SDLK_BACKSPACE: character = 8; break;
        case SDLK_DELETE: character = 127; break;
        case SDLK_RETURN: case SDLK_RETURN2: case SDLK_KP_ENTER: character = 13; break;
        case SDLK_ESCAPE: character = 27; break;
        }
        /* fall through */
    case SDL_EVENT_KEY_UP:
        key = keycode(event->key.key);
        mods = keymods(event->key.mod);
		{
			BBObject *payload = sdl3_sdl3system__InputKeyboard(event->key.windowID, event->key.timestamp,
				event->key.which, event->key.scancode, event->key.key, event->key.mod, event->key.repeat ? 1 : 0);
			InputWindow *window = inputWindow(event->key.windowID);
			if (key && window) window->keys[key] = event->type == SDL_EVENT_KEY_DOWN;
			if (key) inputEmit(event->key.repeat ? BBEVENT_KEYREPEAT :
				(event->type == SDL_EVENT_KEY_DOWN ? BBEVENT_KEYDOWN : BBEVENT_KEYUP), key, mods, 0, 0, payload);
			if (character) inputEmit(BBEVENT_KEYCHAR, character, mods, 0, 0, payload);
		}
		return;
    case SDL_EVENT_TEXT_EDITING:
		sdl3_sdl3system__TextEditing(event->edit.windowID,
			bbStringFromUTF8String((const unsigned char *)event->edit.text),
			event->edit.start, event->edit.length);
		return;
    case SDL_EVENT_TEXT_INPUT: {
        BBString *str = bbStringFromUTF8String((const unsigned char *)event->text.text);
		BBObject *payload = sdl3_sdl3system__InputTextInput(event->text.windowID, event->text.timestamp, str);
		for (int i = 0; i < str->length; ++i) inputEmit(BBEVENT_KEYCHAR, str->buf[i], 0, 0, 0, payload);
		return;
	}
	case SDL_EVENT_MOUSE_MOTION:
		inputEmit(BBEVENT_MOUSEMOVE, 0, 0, (int)event->motion.x, (int)event->motion.y,
			sdl3_sdl3system__InputMouse(event->motion.windowID, event->motion.timestamp,
				event->motion.which, event->motion.x, event->motion.y, event->motion.xrel,
				event->motion.yrel, event->motion.state, 0, 0));
		return;
	case SDL_EVENT_MOUSE_BUTTON_DOWN: case SDL_EVENT_MOUSE_BUTTON_UP: {
		int button = mouseButton(event->button.button);
		InputWindow *window = inputWindow(event->button.windowID);
		if (window && button >= 1 && button <= 5) window->buttons[button - 1] = event->type == SDL_EVENT_MOUSE_BUTTON_DOWN;
		/* BRL.PolledInput has five button slots. Other buttons remain visible to native observers. */
		if (button < 1 || button > 5) return;
		inputEmit(event->type == SDL_EVENT_MOUSE_BUTTON_DOWN ? BBEVENT_MOUSEDOWN : BBEVENT_MOUSEUP,
			button, 0, (int)event->button.x, (int)event->button.y,
			sdl3_sdl3system__InputMouse(event->button.windowID, event->button.timestamp,
				event->button.which, event->button.x, event->button.y, 0, 0, 0,
				event->button.button, event->button.clicks));
		return;
	}
	case SDL_EVENT_MOUSE_WHEEL: {
		BBObject *payload = sdl3_sdl3system__InputWheel(event->wheel.windowID, event->wheel.timestamp,
			event->wheel.which, event->wheel.x, event->wheel.y, event->wheel.mouse_x,
			event->wheel.mouse_y, event->wheel.direction);
		int steps = wheelSteps(&event->wheel);
		sdl3_sdl3system__WheelEvent(payload);
		if (steps) inputEmit(BBEVENT_MOUSEWHEEL, steps, 0, (int)event->wheel.mouse_x, (int)event->wheel.mouse_y, payload);
		return;
	}
	case SDL_EVENT_FINGER_DOWN: case SDL_EVENT_FINGER_UP: case SDL_EVENT_FINGER_MOTION: case SDL_EVENT_FINGER_CANCELED: {
		TouchState *touch = touchState(&event->tfinger);
		if (!touch) return;
		int ended = event->type == SDL_EVENT_FINGER_UP || event->type == SDL_EVENT_FINGER_CANCELED;
		int legacy = touch->legacy;
		if (ended) removeTouch(touch);
		inputEmit(event->type == SDL_EVENT_FINGER_DOWN ? BBEVENT_TOUCHDOWN : ended ? BBEVENT_TOUCHUP : BBEVENT_TOUCHMOVE,
			legacy, 0, (int)(event->tfinger.x * 10000), (int)(event->tfinger.y * 10000),
			sdl3_sdl3system__InputTouch(event->tfinger.windowID, event->tfinger.timestamp,
				event->tfinger.touchID, event->tfinger.fingerID, event->tfinger.x, event->tfinger.y,
				event->tfinger.dx, event->tfinger.dy, event->tfinger.pressure, event->type == SDL_EVENT_FINGER_CANCELED));
		return;
	}
	case SDL_EVENT_WINDOW_DESTROYED: {
		releaseWindowInput(event->window.windowID);
		InputWindow **slot = &inputWindows;
		while (*slot && (*slot)->id != event->window.windowID) slot = &(*slot)->next;
		if (*slot) {
			InputWindow *item = *slot;
			*slot = item->next;
			SDL_free(item);
		}
		WheelState **wheel = &wheelStates;
		while (*wheel) {
			if ((*wheel)->window == event->window.windowID) {
				WheelState *item = *wheel;
				*wheel = item->next;
				SDL_free(item);
			} else wheel = &(*wheel)->next;
		}
		if (focusedWindow == event->window.windowID) focusLossPending = 1;
		return;
	}
	case SDL_EVENT_WINDOW_FOCUS_GAINED:
		focusedWindow = event->window.windowID;
		focusLossPending = 0;
		if (!applicationFocused) {
			applicationFocused = 1;
			emit(BBEVENT_APPRESUME, source, 0, 0, 0, 0);
		}
		return;
	case SDL_EVENT_WINDOW_FOCUS_LOST:
		releaseWindowInput(event->window.windowID);
		if (focusedWindow == event->window.windowID || !focusedWindow) focusLossPending = 1;
		return;
    case SDL_EVENT_WINDOW_RESIZED:
        emit(BBEVENT_WINDOWSIZE, source, event->window.windowID, 0, event->window.data1, event->window.data2); return;
    case SDL_EVENT_WINDOW_MOVED:
        emit(BBEVENT_WINDOWMOVE, source, event->window.windowID, 0, event->window.data1, event->window.data2); return;
    case SDL_EVENT_WINDOW_MOUSE_ENTER: emit(BBEVENT_MOUSEENTER, source, event->window.windowID, 0, 0, 0); return;
    case SDL_EVENT_WINDOW_MOUSE_LEAVE: emit(BBEVENT_MOUSELEAVE, source, event->window.windowID, 0, 0, 0); return;
    case SDL_EVENT_WINDOW_MINIMIZED: emit(BBEVENT_WINDOWMINIMIZE, source, event->window.windowID, 0, 0, 0); return;
    case SDL_EVENT_WINDOW_MAXIMIZED: emit(BBEVENT_WINDOWMAXIMIZE, source, event->window.windowID, 0, 0, 0); return;
    case SDL_EVENT_WINDOW_RESTORED: emit(BBEVENT_WINDOWRESTORE, source, event->window.windowID, 0, 0, 0); return;
    case SDL_EVENT_WINDOW_CLOSE_REQUESTED: emit(BBEVENT_WINDOWCLOSE, source, event->window.windowID, 0, 0, 0); return;
    case SDL_EVENT_WINDOW_DISPLAY_CHANGED: emit(BBEVENT_WINDOWDISPLAYCHANGE, source, event->window.windowID, 0, 0, 0); return;
    case SDL_EVENT_WINDOW_ICCPROF_CHANGED: emit(BBEVENT_WINDOWICCPROFCHANGE, source, event->window.windowID, 0, 0, 0); return;
    case SDL_EVENT_DISPLAY_ORIENTATION: emit(BBEVENT_DISPLAYORIENTATION, source, event->display.displayID, 0, 0, 0); return;
    case SDL_EVENT_DISPLAY_ADDED: emit(BBEVENT_DISPLAYCONNECT, source, event->display.displayID, 0, 0, 0); return;
    case SDL_EVENT_DISPLAY_REMOVED: emit(BBEVENT_DISPLAYDISCONNECT, source, event->display.displayID, 0, 0, 0); return;
    case SDL_EVENT_DISPLAY_MOVED: emit(BBEVENT_DISPLAYMOVED, source, event->display.displayID, 0, 0, 0); return;
    default: return;
    }
}

static int keyboardEvent(Uint32 type) {
    return type == SDL_EVENT_KEY_DOWN || type == SDL_EVENT_KEY_UP ||
        type == SDL_EVENT_TEXT_INPUT || type == SDL_EVENT_TEXT_EDITING;
}
static int mouseEvent(Uint32 type) {
    return type == SDL_EVENT_MOUSE_BUTTON_DOWN || type == SDL_EVENT_MOUSE_BUTTON_UP ||
        type == SDL_EVENT_MOUSE_MOTION || type == SDL_EVENT_MOUSE_WHEEL ||
        type == SDL_EVENT_FINGER_DOWN || type == SDL_EVENT_FINGER_UP || type == SDL_EVENT_FINGER_MOTION ||
		type == SDL_EVENT_FINGER_CANCELED;
}
static void dispatchEvent(SDL_Event *event) {
    if (event->type == lifecycleWakeEvent && lifecycleWakeEvent) {
        sdl3_sdl3system_TSDLSystemDriver__eventFilter(lifecycleDriver, event->user.code);
        return;
    }
    int capture = 0;
    ++dispatchDepth;
    for (EventObserverNode *node = eventObservers; node; ) {
        EventObserverNode *next = node->next;
        if (!node->removed) capture |= node->cb(node->userdata, event);
        node = next;
    }
    if (!--dispatchDepth) {
        while (retiredObservers) {
            EventObserverNode *node = retiredObservers;
            retiredObservers = node->retiredNext;
            free(node);
        }
    }
	int captured = ((capture & BMX_SDL3_CAPTURE_KEYBOARD) && keyboardEvent(event->type)) ||
		((capture & BMX_SDL3_CAPTURE_MOUSE) && mouseEvent(event->type));
	/* Capture may begin during a gesture. Finish input already delivered to BRL,
	 * otherwise held keys/buttons/contacts would remain stuck indefinitely. */
	if (captured && event->type == SDL_EVENT_KEY_UP) {
		int key = keycode(event->key.key);
		for (InputWindow *item = inputWindows; item; item = item->next) {
			if (key && item->id == event->key.windowID && item->keys[key]) captured = 0;
		}
	}
	if (captured && event->type == SDL_EVENT_MOUSE_BUTTON_UP) {
		int button = mouseButton(event->button.button);
		for (InputWindow *item = inputWindows; item; item = item->next) {
			if (button >= 1 && button <= 5 && item->id == event->button.windowID && item->buttons[button - 1]) captured = 0;
		}
	}
	if (captured && (event->type == SDL_EVENT_FINGER_UP || event->type == SDL_EVENT_FINGER_CANCELED)) {
		for (TouchState *item = touchStates; item; item = item->next) {
			if (item->device == event->tfinger.touchID && item->finger == event->tfinger.fingerID) captured = 0;
		}
	}
	if (!captured) emitEvent(event);
}
static void handleEvent(SDL_Event *event) {
	PendingOpenFile *owned = event->type == SDL_EVENT_DROP_FILE ? takeOpenFile(event->drop.data) : NULL;
	dispatchEvent(event);
	freeOpenFile(owned);
}
void bmx_SDL3_Poll(void) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) handleEvent(&event);
	finishFocus();
}
void bmx_SDL3_WaitEvent(void) {
    SDL_Event event;
    if (SDL_WaitEvent(&event)) handleEvent(&event);
	/* Drain transfers before deciding whether the application lost focus. */
	bmx_SDL3_Poll();
}

static bool SDLCALL lifecycleWatch(void *userdata, SDL_Event *event) {
    switch (event->type) {
    case SDL_EVENT_TERMINATING: case SDL_EVENT_LOW_MEMORY:
    case SDL_EVENT_WILL_ENTER_BACKGROUND: case SDL_EVENT_DID_ENTER_BACKGROUND:
    case SDL_EVENT_WILL_ENTER_FOREGROUND: case SDL_EVENT_DID_ENTER_FOREGROUND:
        if (SDL_GetCurrentThreadID() == mainThread) {
            sdl3_sdl3system_TSDLSystemDriver__eventFilter(userdata, event->type);
        } else if (lifecycleWakeEvent) {
            SDL_Event wake = {0};
            wake.type = lifecycleWakeEvent;
            wake.user.code = event->type;
            SDL_PushEvent(&wake);
        }
        return true;
    default: return true;
    }
}
int bmx_SDL3_SetLifecycleWatch(BBObject *driver) {
    mainThread = SDL_GetCurrentThreadID();
	if (lifecycleDriver) {
		SDL_SetError("Lifecycle watch already installed");
		return 0;
	}
	lifecycleWakeEvent = SDL_RegisterEvents(1);
	if (lifecycleWakeEvent == (Uint32)-1) {
		lifecycleWakeEvent = 0;
		return 0;
	}
	bbGCRetain(driver);
	lifecycleDriver = driver;
	if (!SDL_AddEventWatch(lifecycleWatch, driver)) {
		lifecycleDriver = NULL;
		lifecycleWakeEvent = 0;
		bbGCRelease(driver);
		return 0;
	}
	return 1;
}
void bmx_SDL3_SetMouseVisible(int visible) { if (visible) SDL_ShowCursor(); else SDL_HideCursor(); }

int bmx_SDL3_OpenURL(BBString *url) {
    unsigned char *utf8 = bbStringToUTF8String(url);
    int result = SDL_OpenURL((const char *)utf8) ? 1 : 0;
    bbMemFree(utf8);
    return result;
}

static const SDL_DisplayMode *displayMode(int display) {
    int count = 0;
    SDL_DisplayID *ids = SDL_GetDisplays(&count);
    const SDL_DisplayMode *mode = ids && display >= 0 && display < count ? SDL_GetCurrentDisplayMode(ids[display]) : NULL;
    SDL_free(ids);
    return mode;
}
int bmx_SDL3_GetDisplayWidth(int display) { const SDL_DisplayMode *mode = displayMode(display); return mode ? mode->w : 0; }
int bmx_SDL3_GetDisplayHeight(int display) { const SDL_DisplayMode *mode = displayMode(display); return mode ? mode->h : 0; }
int bmx_SDL3_GetDisplayDepth(int display) { const SDL_DisplayMode *mode = displayMode(display); return mode ? SDL_BITSPERPIXEL(mode->format) : 0; }
int bmx_SDL3_GetDisplayHertz(int display) { const SDL_DisplayMode *mode = displayMode(display); return mode ? (int)mode->refresh_rate : 0; }

int bmx_SDL3_ShowSimpleMessageBox(BBString *text, BBString *title, int serious) {
    unsigned char *t = bbStringToUTF8String(title), *s = bbStringToUTF8String(text);
    int result = SDL_ShowSimpleMessageBox(serious ? SDL_MESSAGEBOX_WARNING : SDL_MESSAGEBOX_INFORMATION, (const char *)t, (const char *)s, NULL) ? 0 : 1;
    bbMemFree(t); bbMemFree(s);
    return result;
}
static int messageBox(BBString *text, BBString *title, int serious, int proceed) {
    unsigned char *t = bbStringToUTF8String(title), *s = bbStringToUTF8String(text);
    const SDL_MessageBoxButtonData confirm[] = {
        {SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT, 0, "no"},
        {SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT, 1, "yes"}
    };
    const SDL_MessageBoxButtonData choices[] = {
        {0, 0, "no"}, {SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT, 1, "yes"},
        {SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT, 2, "cancel"}
    };
    SDL_MessageBoxData box = {0};
    box.flags = serious ? SDL_MESSAGEBOX_WARNING : SDL_MESSAGEBOX_INFORMATION;
    box.title = (const char *)t; box.message = (const char *)s;
    box.numbuttons = proceed ? 3 : 2;
    box.buttons = proceed ? choices : confirm;
    int button = -1;
    SDL_ShowMessageBox(&box, &button);
    bbMemFree(t); bbMemFree(s);
    return proceed ? (button == 2 ? -1 : button) : (button == 1);
}
int bmx_SDL3_ShowMessageBoxConfirm(BBString *text, BBString *title, int serious) { return messageBox(text, title, serious, 0); }
int bmx_SDL3_ShowMessageBoxProceed(BBString *text, BBString *title, int serious) { return messageBox(text, title, serious, 1); }
