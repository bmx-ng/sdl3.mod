SuperStrict

Framework SDL3.SDL3Graphics
Import BRL.Graphics
Import BRL.StandardIO
Import "test_helpers.bmx"

Local driver:TSDLGraphicsDriver = SDLGraphicsDriver()
Local graphics:TSDLGraphics = driver.CreateGraphics(96, 64, 0, 60, GRAPHICS_BACKBUFFER | SDL_GRAPHICS_GL, -1, -1)
Check graphics, SDL_GetError()
SetGraphics(graphics)
Check driver.GetSDLWindow()
Check (driver.GetSDLWindow().GetFlags() & SDL_WINDOW_OPENGL) <> 0
Check driver.GetSDLGLContext()
Check SDL_GL_GetCurrentContext() = driver.GetSDLGLContext().contextPtr
Check driver.GetSDLRenderer() = Null
Check driver.GetHandle() <> Null
Check TSDLGLContext.GetProcAddress("glClear") <> Null
Check driver.GetSDLWindow().GLMakeCurrent(driver.GetSDLGLContext()) = 1
Local other:TSDLGraphics = driver.CreateGraphics(80, 50, 0, 60, GRAPHICS_BACKBUFFER | SDL_GRAPHICS_GL, -1, -1)
Check other, SDL_GetError()
SetGraphics(other)
Check SDL_GL_GetCurrentContext() = driver.GetSDLGLContext().contextPtr
SetGraphics(graphics)
Check SDL_GL_GetCurrentContext() = driver.GetSDLGLContext().contextPtr
CloseGraphics(other)
Check driver.Flip(0) = 1
CloseGraphics(graphics)
Check driver.GetSDLGLContext() = Null
Print "SDL3 OpenGL graphics test passed"
