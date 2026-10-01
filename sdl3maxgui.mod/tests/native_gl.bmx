SuperStrict

Framework MaxGUI.Drivers
Import BRL.GLMax2D
Import BRL.TimerDefault
Import BRL.EventQueue

Local window:TGadget=CreateWindow("Existing BRL canvas regression",100,100,400,280,Null,WINDOW_TITLEBAR|WINDOW_CLIENTCOORDS)
Local canvas:TGadget=CreateCanvas(10,10,380,260,window)
If Not CanvasGraphics(canvas) Then Throw "Existing GL canvas attachment failed"
Local timer:TTimer=CreateTimer(30)
Local ticks:Int
While ticks<3
	If WaitEvent()=EVENT_TIMERTICK Then
		SetGraphics(CanvasGraphics(canvas))
		Cls
		DrawText("Existing BRL GLMax2D",10,10)
		Flip(0)
		ticks:+1
	End If
Wend
StopTimer(timer)
FreeGadget(window)
Print "Existing MaxGUI / BRL.GLMax2D canvas passed"
