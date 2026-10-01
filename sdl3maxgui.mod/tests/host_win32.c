#include <windows.h>

void test_host_input(HWND canvas, HWND field) {
	POINT point = {37, 49};
	ClientToScreen(canvas, &point);
	SetForegroundWindow(GetAncestor(canvas, GA_ROOT));
	SetCursorPos(point.x, point.y);
	INPUT input[2] = {0};
	input[0].type = input[1].type = INPUT_MOUSE;
	input[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
	input[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
	SendInput(2, input, sizeof(INPUT));
	SendMessageW(field, WM_CHAR, L'Z', 1);
	InvalidateRect(canvas, NULL, FALSE);
	UpdateWindow(canvas);
}

int test_host_detached(HWND canvas) {
	return IsWindow(canvas) && !GetPropW(canvas, L"BMX.SDL3.MaxGUI") && !GetPropW(canvas, L"SDL_WindowData");
}
