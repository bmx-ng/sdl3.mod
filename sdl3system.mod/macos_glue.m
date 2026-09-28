#include <SDL3/SDL.h>
#include "event_observer.h"
#include <brl.mod/blitz.mod/blitz.h>
#import <AppKit/AppKit.h>

typedef NSApplicationTerminateReply (*BBAppShouldTerminateHook)(NSApplication *app);
typedef int (*BBAppOpenFileHook)(NSApplication *app, BBString *path);
void bbRegisterAppShouldTerminateHook(BBAppShouldTerminateHook hook);
void bbRegisterAppOpenFileHook(BBAppOpenFileHook hook);

static NSApplicationTerminateReply applicationShouldTerminate(NSApplication *app) {
    if (SDL_EventEnabled(SDL_EVENT_QUIT)) {
        SDL_Event event = {0};
        event.type = SDL_EVENT_QUIT;
        SDL_PushEvent(&event);
    }
    return NSTerminateCancel;
}

static int applicationOpenFile(NSApplication *app, BBString *path) {
    if (!SDL_EventEnabled(SDL_EVENT_DROP_FILE)) return 0;
    unsigned char *utf8 = bbStringToUTF8String(path);
    int result = bmx_SDL3_QueueOpenFile((const char *)utf8);
    bbMemFree(utf8);
    return result;
}

void bmx_SDL3_RegisterCallbacks(void) {
    bbRegisterAppShouldTerminateHook(applicationShouldTerminate);
    bbRegisterAppOpenFileHook(applicationOpenFile);
}
