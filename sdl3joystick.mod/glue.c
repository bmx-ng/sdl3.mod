#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>
#include <sdl3.mod/sdl3system.mod/event_observer.h>

void sdl3_sdl3joystick__JoystickEvent(int type, Uint32 id, int control, int value);

int bmx_SDL3_CopyJoystickIDs(Uint32 *output, int capacity) {
    int count = 0;
    SDL_JoystickID *ids = SDL_GetJoysticks(&count);
    if (!ids) return 0;
    if (output) {
        int copied = count < capacity ? count : capacity;
        SDL_memcpy(output, ids, (size_t)copied * sizeof(*ids));
        count = copied;
    }
    SDL_free(ids);
    return count;
}
BBString *bmx_SDL3_JoystickNameForID(Uint32 id) {
    const char *name = SDL_GetJoystickNameForID(id);
    return bbStringFromUTF8String((const unsigned char *)(name ? name : ""));
}
BBString *bmx_SDL3_JoystickName(SDL_Joystick *joystick) {
    const char *name = SDL_GetJoystickName(joystick);
    return bbStringFromUTF8String((const unsigned char *)(name ? name : ""));
}
int bmx_SDL3_JoystickConnected(SDL_Joystick *joystick) { return SDL_JoystickConnected(joystick) ? 1 : 0; }
int bmx_SDL3_GetJoystickAxis(SDL_Joystick *joystick, int axis) { return SDL_GetJoystickAxis(joystick, axis); }
int bmx_SDL3_GetJoystickButton(SDL_Joystick *joystick, int button) { return SDL_GetJoystickButton(joystick, button) ? 1 : 0; }
int bmx_SDL3_GetJoystickHat(SDL_Joystick *joystick, int hat) { return SDL_GetJoystickHat(joystick, hat); }

Uint32 bmx_SDL3_AttachVirtualJoystick(BBString *name, int type, int axes, int buttons, int hats) {
    SDL_VirtualJoystickDesc description;
    SDL_INIT_INTERFACE(&description);
    description.type = (Uint16)type;
    description.naxes = (Uint16)axes;
    description.nbuttons = (Uint16)buttons;
    description.nhats = (Uint16)hats;
    unsigned char *utf8 = bbStringToUTF8String(name);
    description.name = (const char *)utf8;
    Uint32 id = SDL_AttachVirtualJoystick(&description);
    bbMemFree(utf8);
    return id;
}
int bmx_SDL3_DetachVirtualJoystick(Uint32 id) { return SDL_DetachVirtualJoystick(id) ? 1 : 0; }
int bmx_SDL3_SetVirtualAxis(SDL_Joystick *joystick, int axis, int value) {
    return SDL_SetJoystickVirtualAxis(joystick, axis, (Sint16)value) ? 1 : 0;
}
int bmx_SDL3_SetVirtualButton(SDL_Joystick *joystick, int button, int down) {
    return SDL_SetJoystickVirtualButton(joystick, button, down != 0) ? 1 : 0;
}
int bmx_SDL3_SetVirtualHat(SDL_Joystick *joystick, int hat, int value) {
    return SDL_SetJoystickVirtualHat(joystick, hat, (Uint8)value) ? 1 : 0;
}

static int joystickObserver(void *userdata, SDL_Event *event) {
    switch (event->type) {
    case SDL_EVENT_JOYSTICK_ADDED:
    case SDL_EVENT_JOYSTICK_REMOVED:
        sdl3_sdl3joystick__JoystickEvent((int)event->type, event->jdevice.which, 0, 0); break;
    case SDL_EVENT_JOYSTICK_AXIS_MOTION:
        sdl3_sdl3joystick__JoystickEvent((int)event->type, event->jaxis.which, event->jaxis.axis, event->jaxis.value); break;
    case SDL_EVENT_JOYSTICK_HAT_MOTION:
        sdl3_sdl3joystick__JoystickEvent((int)event->type, event->jhat.which, event->jhat.hat, event->jhat.value); break;
    case SDL_EVENT_JOYSTICK_BUTTON_DOWN:
    case SDL_EVENT_JOYSTICK_BUTTON_UP:
        sdl3_sdl3joystick__JoystickEvent((int)event->type, event->jbutton.which, event->jbutton.button,
            event->type == SDL_EVENT_JOYSTICK_BUTTON_DOWN ? 1 : 0); break;
    default: break;
    }
    return 0;
}
void bmx_SDL3_RegisterJoystickObserver(void) { bmx_SDL3_AddEventObserver(joystickObserver, NULL); }
