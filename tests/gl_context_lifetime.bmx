SuperStrict

Framework SDL3.SDL3Video
Import BRL.StandardIO
Import "test_helpers.bmx"

Local first:TSDLWindow = TSDLWindow.Create("GL ownership", 64, 64, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN)
Check first, SDL_GetError()
Local a:TSDLGLContext = first.GLCreateContext()
Local b:TSDLGLContext = first.GLCreateContext()
Check a And b, SDL_GetError()
Check a.IsValid() And b.IsValid()
Check Not a.SetSwapInterval(0), "Non-current context changed the current context's swap interval"
Check first.GLMakeCurrent(a)
Local second:TSDLWindow = TSDLWindow.Create("Other GL owner", 64, 64, SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN)
Check second
Check Not second.GLMakeCurrent(a), "Context accepted a different owner window"
a.Free()
a.Free()
Check Not a.IsValid() And b.IsValid()
Check Not first.GLMakeCurrent(a), "Freed context was made current"
Check first.GLMakeCurrent(b)
first.Destroy()
Check Not b.IsValid() And Not b.contextPtr, "Owner destruction left a live GL context"
b.Free()
first.Destroy()
Check Not first.GLCreateContext()
Check Not b.SetSwapInterval(0)
second.Destroy()
Print "SDL3 GL context lifetime test passed"
