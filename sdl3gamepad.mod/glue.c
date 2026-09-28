#include <SDL3/SDL.h>
#include <brl.mod/blitz.mod/blitz.h>
#include <sdl3.mod/sdl3system.mod/event_observer.h>

void sdl3_sdl3gamepad__GamepadEvent(int type, Uint32 id, int control, int value);

int bmx_SDL3_CopyGamepadIDs(Uint32 *output, int capacity) {
    int count = 0;
    SDL_JoystickID *ids = SDL_GetGamepads(&count);
    if (!ids) return 0;
    if (output) {
        int copied = count < capacity ? count : capacity;
        SDL_memcpy(output, ids, (size_t)copied * sizeof(*ids));
        count = copied;
    }
    SDL_free(ids);
    return count;
}
int bmx_SDL3_IsGamepad(Uint32 id) { return SDL_IsGamepad(id) ? 1 : 0; }
int bmx_SDL3_GamepadConnected(SDL_Gamepad *gamepad) { return SDL_GamepadConnected(gamepad) ? 1 : 0; }
BBString *bmx_SDL3_GamepadName(SDL_Gamepad *gamepad) {
    const char *name = SDL_GetGamepadName(gamepad);
    return bbStringFromUTF8String((const unsigned char *)(name ? name : ""));
}
int bmx_SDL3_GetGamepadAxis(SDL_Gamepad *gamepad, int axis) {
    return SDL_GetGamepadAxis(gamepad, (SDL_GamepadAxis)axis);
}
int bmx_SDL3_GetGamepadButton(SDL_Gamepad *gamepad, int button) {
    return SDL_GetGamepadButton(gamepad, (SDL_GamepadButton)button) ? 1 : 0;
}
int bmx_SDL3_RumbleGamepad(SDL_Gamepad *gamepad, int low, int high, Uint32 duration) {
    return SDL_RumbleGamepad(gamepad, (Uint16)low, (Uint16)high, duration) ? 1 : 0;
}
BBString *bmx_SDL3_GetGamepadMapping(SDL_Gamepad *gamepad) {
    char *mapping = SDL_GetGamepadMapping(gamepad);
    if (!mapping) return &bbEmptyString;
    BBString *result = bbStringFromUTF8String((const unsigned char *)mapping);
    SDL_free(mapping);
    return result;
}
int bmx_SDL3_AddGamepadMapping(BBString *mapping) {
    unsigned char *utf8 = bbStringToUTF8String(mapping);
    int result = SDL_AddGamepadMapping((const char *)utf8);
    bbMemFree(utf8);
    return result;
}

static int gamepadObserver(void *userdata, SDL_Event *event) {
    switch (event->type) {
    case SDL_EVENT_GAMEPAD_ADDED:
    case SDL_EVENT_GAMEPAD_REMOVED:
    case SDL_EVENT_GAMEPAD_REMAPPED:
        sdl3_sdl3gamepad__GamepadEvent((int)event->type, event->gdevice.which, 0, 0); break;
    case SDL_EVENT_GAMEPAD_AXIS_MOTION:
        sdl3_sdl3gamepad__GamepadEvent((int)event->type, event->gaxis.which, event->gaxis.axis, event->gaxis.value); break;
    case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
    case SDL_EVENT_GAMEPAD_BUTTON_UP:
        sdl3_sdl3gamepad__GamepadEvent((int)event->type, event->gbutton.which, event->gbutton.button,
            event->type == SDL_EVENT_GAMEPAD_BUTTON_DOWN ? 1 : 0); break;
    default: break;
    }
    return 0;
}
void bmx_SDL3_RegisterGamepadObserver(void) { bmx_SDL3_AddEventObserver(gamepadObserver, NULL); }
