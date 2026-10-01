#ifndef BMX_SDL3_EVENT_OBSERVER_H
#define BMX_SDL3_EVENT_OBSERVER_H

#include <SDL3/SDL_events.h>

/* Observers see every event. These flags affect only its BlitzMax translation.
 * Terminal events for input already delivered to BRL still pass through, so
 * beginning capture during a press/contact cannot leave held input stuck. */
#define BMX_SDL3_CAPTURE_KEYBOARD 1
#define BMX_SDL3_CAPTURE_MOUSE 2

typedef int (*BMX_SDL3_EventObserver)(void *userdata, SDL_Event *event);

void bmx_SDL3_AddEventObserver(BMX_SDL3_EventObserver observer, void *userdata);
void bmx_SDL3_RemoveEventObserver(BMX_SDL3_EventObserver observer);

/* Main-thread application hook; copies the UTF-8 path until event delivery. */
int bmx_SDL3_QueueOpenFile(const char *path);

/* Optional host wakeup. Notify only after SDL_PushEvent has queued an event.
 * The callback must be native/thread-safe: timer producers can run off-thread. */
void bmx_SDL3_SetHostWakeup(void (*callback)(void));
void bmx_SDL3_NotifyEventQueued(void);

#endif
