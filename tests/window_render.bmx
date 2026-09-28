SuperStrict

Framework SDL3.SDL3Render
Import "test_helpers.bmx"
Import BRL.System
Import BRL.StandardIO

Local window:TSDLWindow = TSDLWindow.Create("SDL3 test", 96, 64, SDL_WINDOW_HIDDEN)
Check window, SDL_GetError()
Check window.GetID() <> 0
Check window.GetTitle() = "SDL3 test"
Check window.SetTitle("SDL3 updated") = 1
Check window.GetTitle() = "SDL3 updated"
Check (window.GetFlags() & SDL_WINDOW_HIDDEN) <> 0
Local width:Int, height:Int
Check window.GetSize(width, height) = 1
Check width = 96 And height = 64
Check window.SetSize(128, 80) = 1
Check window.GetSize(width, height) = 1
Check width = 128 And height = 80
Check window.GetSizeInPixels(width, height) = 1
Check width = 128 And height = 80
Local x:Int, y:Int
Check window.GetPosition(x, y) = 1
Check window.SetPosition(10, 20) = 1
Check window.Show() = 1
Check window.Hide() = 1
Local renderer:TSDLRenderer = TSDLRenderer.Create(window, "software")
Check renderer, SDL_GetError()
Check renderer.SetDrawColor(12, 34, 56) = 1
Check renderer.Clear() = 1
Check renderer.Present() = 1
SystemDriver().MoveMouse(1, 2)
PollSystem()
renderer.Destroy()
window.Destroy()
Print "SDL3 window and renderer test passed"
