SuperStrict

Framework SDL3.SDL3
Import BRL.StandardIO
Import "test_helpers.bmx"

Import SDL3.SDL3Rect

Check SDL_GetVersion() = 3004016, "Unexpected SDL3 version"
Check SDL_Init(SDL_INIT_EVENTS) = 1, SDL_GetError()
Check SDL_WasInit(SDL_INIT_EVENTS) <> 0, "Events did not initialize"
SDL_SetEventEnabled(SDL_EVENT_KEY_DOWN, 0)
Check SDL_EventEnabled(SDL_EVENT_KEY_DOWN) = 0, "Event disable bool conversion failed"
SDL_SetEventEnabled(SDL_EVENT_KEY_DOWN, 2)
Check SDL_EventEnabled(SDL_EVENT_KEY_DOWN) = 1, "Event enable bool conversion failed"

Local a:SSDLRect = New SSDLRect(0, 0, 10, 10)
Local same:SSDLRect = New SSDLRect(0, 0, 10, 10)
Local overlap:SSDLRect = New SSDLRect(5, 5, 10, 10)
Local apart:SSDLRect = New SSDLRect(20, 20, 2, 2)
Local empty:SSDLRect = New SSDLRect(0, 0, 0, 10)
Local result:SSDLRect

Check a.Empty() = 0, "Nonempty rectangle returned true"
Check empty.Empty() = 1, "Empty rectangle returned false"
Check a.Equals(same) = 1, "Equal rectangles returned false"
Check a.Equals(overlap) = 0, "Different rectangles returned true"
Check a.HasIntersection(overlap) = 1, "Overlapping rectangles returned false"
Check a.HasIntersection(apart) = 0, "Disjoint rectangles returned true"
Check a.IntersectRect(overlap, result) = 1, "Intersection failed"
Check result.x = 5 And result.y = 5 And result.w = 5 And result.h = 5, "Wrong intersection"
Local x1:Int = -5
Local y1:Int = 5
Local x2:Int = 15
Local y2:Int = 5
Check a.IntersectRectAndLine(x1, y1, x2, y2) = 1, "Line intersection failed"
Check x1 = 0 And y1 = 5 And x2 = 9 And y2 = 5, "Wrong clipped line"
Check a.UnionRect(overlap, result) = 1, "Union failed"
Check result.x = 0 And result.y = 0 And result.w = 15 And result.h = 15, "Wrong union"

Local fa:SSDLFRect = New SSDLFRect(0, 0, 10, 10)
Local fb:SSDLFRect = New SSDLFRect(5, 5, 10, 10)
Local fzero:SSDLFRect = New SSDLFRect(0, 0, 0, 10)
Local fempty:SSDLFRect = New SSDLFRect(0, 0, -1, 10)
Local fr:SSDLFRect

Check fa.Empty() = 0 And fempty.Empty() = 1, "Float rectangle empty result is wrong"
Check fzero.Empty() = 0, "SDL3 treats a zero-width float rectangle as nonempty"
Check fa.Equals(fa) = 1 And fa.Equals(fb) = 0, "Float rectangle equality is wrong"
Check fa.HasIntersection(fb) = 1, "Float rectangle intersection returned false"
Check fa.IntersectRect(fb, fr) = 1, "Float rectangle intersection failed"
Check fr.x = 5 And fr.y = 5 And fr.w = 5 And fr.h = 5, "Wrong float intersection"
Check fa.UnionRect(fb, fr) = 1, "Float rectangle union failed"
Check fr.x = 0 And fr.y = 0 And fr.w = 15 And fr.h = 15, "Wrong float union"

SDL_Quit()
Check SDL_WasInit(SDL_INIT_EVENTS) = 0, "Events remained initialized"
Print "SDL3 core and rectangle smoke test passed"
