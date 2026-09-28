#include <SDL3/SDL.h>
#include <math.h>
#include <stdint.h>
#include <brl.mod/blitz.mod/blitz.h>
#include <sdl3.mod/sdl3system.mod/event_observer.h>

void sdl3_sdl3timer__TimerFired(Uint32 id);
static Uint32 timerEventType;

static int timerEventCallback(void *userdata, SDL_Event *event) {
    if (event->type == timerEventType) sdl3_sdl3timer__TimerFired((Uint32)event->user.code);
    return 0;
}

int bmx_SDL3_TimerInit(void) {
    timerEventType = SDL_RegisterEvents(1);
    if (timerEventType == (Uint32)-1) return 0;
    bmx_SDL3_AddEventObserver(timerEventCallback, NULL);
    return 1;
}

static Uint32 SDLCALL timerCallback(void *userdata, SDL_TimerID id, Uint32 interval) {
    SDL_Event event = {0};
    event.type = timerEventType;
    event.user.code = (int)id;
    SDL_PushEvent(&event);
    return interval;
}

Uint32 bmx_SDL3_TimerStart(float hertz) {
	if (!isfinite(hertz) || hertz <= 0.0f) {
		SDL_SetError("Timer frequency must be finite and positive");
		return 0;
	}
	double milliseconds = 1000.0 / (double)hertz;
	if (milliseconds > UINT32_MAX) {
		SDL_SetError("Timer interval exceeds SDL's millisecond range");
		return 0;
	}
	Uint32 interval = (Uint32)milliseconds;
    if (!interval) interval = 1;
    return SDL_AddTimer(interval, timerCallback, NULL);
}
int bmx_SDL3_TimerStop(Uint32 id) { return SDL_RemoveTimer(id) ? 1 : 0; }
