#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>

int sdl3_sdl3thread__RunManagedThread(BBObject *thread);

#ifndef __SWITCH__
static bb_thread_t currentThreadID(void) {
#ifdef _WIN32
    return GetCurrentThreadId();
#else
    return pthread_self();
#endif
}

static int SDLCALL managedThreadEntry(void *userdata) {
    BBThread *registration = NULL;
    if (!bbThreadGetCurrent()) registration = bbThreadRegister(currentThreadID());

    int result = sdl3_sdl3thread__RunManagedThread((BBObject *)userdata);
    bbGCRelease((BBObject *)userdata);

    if (registration) bbThreadUnregister(registration);
    return result;
}
#endif

SDL_Thread *bmx_SDL3_CreateManagedThread(BBObject *thread, BBString *name) {
#ifdef __SWITCH__
    SDL_SetError("BlitzMax external-thread registration is unavailable on Switch");
    return NULL;
#else
    unsigned char *utf8 = bbStringToUTF8String(name);
    bbGCRetain(thread);
    SDL_Thread *handle = SDL_CreateThread(managedThreadEntry,
        utf8[0] ? (const char *)utf8 : NULL, thread);
    if (!handle) bbGCRelease(thread);
    bbMemFree(utf8);
    return handle;
#endif
}

void bmx_SDL3_WaitThread(SDL_Thread *handle) { SDL_WaitThread(handle, NULL); }
void bmx_SDL3_DetachThread(SDL_Thread *handle) { SDL_DetachThread(handle); }
