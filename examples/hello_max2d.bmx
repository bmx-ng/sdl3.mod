SuperStrict

Framework Max2D.SDL3RenderMax2D
Import BRL.PolledInput

Graphics 800, 450
SetClsColor 24, 28, 38

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Cls

	SetColor 55, 170, 240
	DrawRect 40, 40, 160, 100

	SetColor 255, 255, 255
	DrawText "Hello from SDL3 and Max2D!", 40, 170
	DrawText "Press Escape or close the window to quit.", 40, 200

	Flip
Wend

EndGraphics
