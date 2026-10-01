SuperStrict

Framework MaxGUI.Drivers
Import BRL.GLMax2D
Import BRL.EventQueue
?linux
Include "host_linux.bmx"
?

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Local window:TGadget=CreateWindow("Native GTK input baseline",100,100,500,360,Null,WINDOW_TITLEBAR|WINDOW_CLIENTCOORDS)
Local field:TGadget=CreateTextField(10,10,400,28,window)
Local canvas:TGadget=CreateCanvas(10,50,320,240,window)
?linux
CheckHostInput(canvas,field)
?
FreeGadget(window)
Print "Native GTK input baseline passed"
