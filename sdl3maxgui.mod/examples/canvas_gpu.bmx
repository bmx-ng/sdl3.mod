SuperStrict

Framework MaxGUI.Drivers
Import SDL3.SDL3MaxGUI
Import Max2D.SDL3GPUMax2D
Import BRL.TimerDefault
Import BRL.EventQueue
Import Pub.StdC

Local window:TGadget=CreateWindow("SDL3 GPU inside MaxGUI",80,80,800,540,Null,WINDOW_TITLEBAR|WINDOW_RESIZABLE|WINDOW_CLIENTCOORDS)
SetMinWindowSize(window,640,320)
Local field:TGadget=CreateTextField(12,12,420,28,window)
SetGadgetText(field,"Native controls and SDL3 drawing share this window")
Local button:TGadget=CreateButton("Change colour",448,12,150,28,window)
SetGadgetLayout(field,EDGE_ALIGNED,EDGE_CENTERED,EDGE_ALIGNED,EDGE_CENTERED)
SetGadgetLayout(button,EDGE_ALIGNED,EDGE_CENTERED,EDGE_ALIGNED,EDGE_CENTERED)
Local canvas:TGadget=CreateCanvas(12,52,776,476,window)
SetGadgetLayout(canvas,EDGE_ALIGNED,EDGE_ALIGNED,EDGE_ALIGNED,EDGE_ALIGNED)
Local graphics:TGraphics=CanvasGraphics(canvas)
If Not graphics Then Throw "Could not attach SDL3: "+SDL_GetError()
Local timer:TTimer=CreateTimer(30)
Local ticks:Int
Local clicks:Int
Local mouseX:Int,mouseY:Int
Local alternate:Int
Local limit:Int=Int(getenv_("SDL3_GUI_SMOKE_TICKS"))
While True
	Select WaitEvent()
		Case EVENT_WINDOWCLOSE,EVENT_APPTERMINATE
			Exit
		Case EVENT_GADGETACTION
			If EventSource()=button Then alternate=Not alternate
		Case EVENT_MOUSEDOWN
			If EventSource()=canvas Then
				clicks:+1
				mouseX=EventX()
				mouseY=EventY()
			End If
		Case EVENT_TIMERTICK
			ticks:+1
			RedrawGadget(canvas)
		Case EVENT_GADGETPAINT
			If EventSource()<>canvas Then Continue
			SetGraphics(graphics)
			SetClsColor(22,30,46)
			Cls
			SetColor(60+alternate*150,170,230)
			DrawRect(30,45,GraphicsWidth()-60,GraphicsHeight()-100)
			SetColor(255,255,255)
			DrawText("Native SDL3 GPU / Max2D",45,65)
			DrawText("Native canvas: "+GraphicsWidth()+" x "+GraphicsHeight(),45,90)
			DrawText("Timer ticks: "+ticks,45,115)
			DrawText("Canvas clicks: "+clicks+" at "+mouseX+", "+mouseY,45,140)
			Flip(0)
	End Select
	If limit And ticks>=limit Then Exit
Wend
StopTimer(timer)
CloseGraphics(graphics)
FreeGadget(window)
Print "SDL3 MaxGUI canvas closed cleanly"
