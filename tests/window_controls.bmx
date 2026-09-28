SuperStrict

Framework SDL3.SDL3Video
Import SDL3.SDL3Test
Import BRL.StandardIO
Import "test_helpers.bmx"

Local window:TSDLWindow = TSDLWindow.Create("SDL3 window controls", 160, 120, SDL_WINDOW_HIDDEN | SDL_WINDOW_RESIZABLE)
Check window, SDL_GetError()
Check probeIsDummyVideo(), "Run automated window controls with SDL_VIDEODRIVER=dummy"
Check window.SetResizable(7) = 1
Check window.SetResizable(False) = 1
Check window.SetBordered(False) = 1
Check window.SetBordered(7) = 1
Check window.SetMinimumSize(80, 60) = 1
Check window.SetMaximumSize(320, 240) = 1
Local width:Int, height:Int
Check window.GetMinimumSize(width, height) And width = 80 And height = 60
Check window.GetMaximumSize(width, height) And width = 320 And height = 240
Check Not window.SetMinimumSize(400, 300), "Conflicting minimum accepted"
Check Not window.SetMaximumSize(40, 30), "Conflicting maximum accepted"
Check window.GetMinimumSize(width, height) And width = 80 And height = 60
Check window.GetMaximumSize(width, height) And width = 320 And height = 240
Check window.SetMinimumSize(0, 0)
Check window.SetMaximumSize(0, 0)
Local rect:SSDLRect = New SSDLRect(10, 12, 60, 40)
Local copied:SSDLRect
Check Not window.GetMouseRect(copied)
SDL_ClearError()
Check Not window.SetMouseRect(rect), "Dummy driver unexpectedly supports confinement; update test"
Check SDL_GetError() <> ""
Check Not window.GetMouseRect(copied)
Check copied.x = 0 And copied.y = 0 And copied.w = 0 And copied.h = 0
Check window.SetMouseGrab(7)
Check window.SetMouseGrab(False)
Check Not window.GetMouseGrab()
Check Not window.SetIcon(Null)
Local icon:TSDLSurface = TSDLSurface.Create(16, 16)
Check icon
Check icon.Fill(0, 180, 255)
SDL_ClearError()
If Not window.SetIcon(icon) Then Check SDL_GetError() <> "", "Icon failure did not report an error"
icon.Destroy()
Check Not window.SetIcon(icon)
Check window.SetResizable(True)
Check window.Show()
SDL_ClearError()
Check Not window.Maximize(), "Dummy driver unexpectedly supports Maximize; update test"
Check SDL_GetError() <> ""
Check window.Sync()
SDL_ClearError()
Check Not window.Restore(), "Dummy driver unexpectedly supports Restore; update test"
Check SDL_GetError() <> ""
SDL_ClearError()
Check Not window.Minimize(), "Dummy driver unexpectedly supports Minimize; update test"
Check SDL_GetError() <> ""
SDL_ClearError()
Check Not window.Restore(), "Dummy driver unexpectedly supports Restore; update test"
Check SDL_GetError() <> ""
Check window.Raise()
Check window.Sync()
window.Destroy()
Check Not window.SetResizable(True)
Check Not window.SetBordered(True)
Check Not window.SetMinimumSize(1, 1)
Check Not window.GetMaximumSize(width, height)
Check width = 0 And height = 0
Check Not window.SetMouseGrab(True)
Check Not window.GetMouseRect(copied)
Check Not window.Raise() And Not window.Sync()

Local closed:TSDLWindow = New TSDLWindow
Local failedWidth:Int = 123
Local failedHeight:Int = 456
Check Not closed.GetSize(failedWidth, failedHeight)
Check failedWidth = 0 And failedHeight = 0
failedWidth = 123
failedHeight = 456
Check Not closed.GetSizeInPixels(failedWidth, failedHeight)
Check failedWidth = 0 And failedHeight = 0
failedWidth = 123
failedHeight = 456
Check Not closed.GetPosition(failedWidth, failedHeight)
Check failedWidth = 0 And failedHeight = 0
Print "SDL3 window controls passed (dummy driver; no window-manager policy claims)"
