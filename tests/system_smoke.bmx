SuperStrict

Framework SDL3.SDL3System
Import "test_helpers.bmx"
Import BRL.System
Import BRL.StandardIO

Check SystemDriver().Name() = "SDL3SystemDriver"
PollSystem()
Check SDL_WasInit(SDL_INIT_EVENTS) <> 0
Print "SDL3 system smoke test passed"
